"""
Minimal SCIM 2.0 bridge: Microsoft Entra provisioning -> Grafana admin API.

Implements the subset of RFC 7644 that the Entra provisioning service uses
for user lifecycle: lookup by userName filter, create, get, patch (incl.
active true/false), put, delete. Groups are intentionally not implemented -
authorization comes from app roles at SSO time, not from SCIM groups.

Security model:
  - Listens only on the Docker network; Caddy routes /scim/* here over HTTPS.
  - Every request must carry: Authorization: Bearer <SCIM_SECRET_TOKEN>.
  - Deprovisioning = disable (soft delete), preserving the audit trail.
"""

import hmac
import os
import re
import secrets

import requests
from flask import Flask, jsonify, request

app = Flask(__name__)

SCIM_TOKEN = os.environ["SCIM_SECRET_TOKEN"]
GRAFANA_URL = os.environ.get("GRAFANA_URL", "http://grafana:3000").rstrip("/")
GRAFANA_AUTH = (
    os.environ.get("GRAFANA_ADMIN_USER", "admin"),
    os.environ["GRAFANA_ADMIN_PASSWORD"],
)

SCIM_USER_SCHEMA = "urn:ietf:params:scim:schemas:core:2.0:User"
SCIM_LIST_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:ListResponse"
SCIM_ERROR_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:Error"
SCIM_PATCH_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:PatchOp"


# --------------------------------------------------------------------------- helpers
def scim_error(status: int, detail: str):
    return jsonify({"schemas": [SCIM_ERROR_SCHEMA], "status": str(status), "detail": detail}), status


def grafana(method: str, path: str, **kwargs):
    """Call the Grafana HTTP API with the local admin credential."""
    return requests.request(method, f"{GRAFANA_URL}{path}", auth=GRAFANA_AUTH, timeout=10, **kwargs)


def to_scim(gf_user: dict) -> dict:
    """Map a Grafana user object to a SCIM User resource."""
    uid = str(gf_user["id"])
    return {
        "schemas": [SCIM_USER_SCHEMA],
        "id": uid,
        "userName": gf_user.get("login", ""),
        "displayName": gf_user.get("name") or gf_user.get("login", ""),
        "emails": [{"value": gf_user.get("email", ""), "type": "work", "primary": True}],
        "active": not gf_user.get("isDisabled", False),
        "meta": {"resourceType": "User", "location": f"/scim/Users/{uid}"},
    }


def get_grafana_user(user_id: str):
    r = grafana("GET", f"/api/users/{user_id}")
    return r.json() if r.status_code == 200 else None


@app.before_request
def check_bearer_token():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer ") or not hmac.compare_digest(auth[7:], SCIM_TOKEN):
        return scim_error(401, "Invalid or missing bearer token")


# --------------------------------------------------------------------------- discovery
@app.get("/ServiceProviderConfig")
def service_provider_config():
    return jsonify({
        "schemas": ["urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig"],
        "patch": {"supported": True},
        "bulk": {"supported": False, "maxOperations": 0, "maxPayloadSize": 0},
        "filter": {"supported": True, "maxResults": 200},
        "changePassword": {"supported": False},
        "sort": {"supported": False},
        "etag": {"supported": False},
        "authenticationSchemes": [{"type": "oauthbearertoken", "name": "Bearer token",
                                   "description": "Authorization: Bearer <token>"}],
    })


# --------------------------------------------------------------------------- /Users
@app.get("/Users")
def list_users():
    """Entra always filters by userName (also used by Test Connection)."""
    flt = request.args.get("filter", "")
    m = re.match(r'userName\s+eq\s+"(.+)"', flt, re.IGNORECASE)
    if m:
        r = grafana("GET", "/api/users/lookup", params={"loginOrEmail": m.group(1)})
        resources = [to_scim(r.json())] if r.status_code == 200 else []
    else:
        r = grafana("GET", "/api/users", params={"perpage": 200, "page": 1})
        r.raise_for_status()
        resources = [to_scim(u) for u in r.json()]
    return jsonify({
        "schemas": [SCIM_LIST_SCHEMA],
        "totalResults": len(resources),
        "startIndex": 1,
        "itemsPerPage": len(resources),
        "Resources": resources,
    })


@app.get("/Users/<user_id>")
def get_user(user_id):
    gf = get_grafana_user(user_id)
    if not gf:
        return scim_error(404, f"User {user_id} not found")
    return jsonify(to_scim(gf))


@app.post("/Users")
def create_user():
    data = request.get_json(force=True)
    user_name = data.get("userName")
    if not user_name:
        return scim_error(400, "userName is required")

    # Conflict check (Entra retries create if it missed the filter round-trip)
    r = grafana("GET", "/api/users/lookup", params={"loginOrEmail": user_name})
    if r.status_code == 200:
        return scim_error(409, f"User {user_name} already exists")

    emails = data.get("emails") or []
    email = next((e.get("value") for e in emails if e.get("primary")), None) \
        or (emails[0].get("value") if emails else user_name)

    r = grafana("POST", "/api/admin/users", json={
        "name": data.get("displayName", user_name),
        "email": email,
        "login": user_name,
        # Random throwaway password: authentication happens via SSO, never locally.
        "password": secrets.token_urlsafe(24),
    })
    if r.status_code != 200:
        return scim_error(502, f"Grafana create failed: {r.text}")
    uid = str(r.json()["id"])

    if data.get("active") is False:
        grafana("POST", f"/api/admin/users/{uid}/disable")

    return jsonify(to_scim(get_grafana_user(uid))), 201


@app.patch("/Users/<user_id>")
def patch_user(user_id):
    gf = get_grafana_user(user_id)
    if not gf:
        return scim_error(404, f"User {user_id} not found")

    updates = {}
    for op in request.get_json(force=True).get("Operations", []):
        op_name = op.get("op", "").lower()
        path = (op.get("path") or "").lower()
        value = op.get("value")

        # Entra sends both {"path": "active", "value": false} and
        # {"value": {"active": false}} shapes; handle both.
        if isinstance(value, dict) and not path:
            for k, v in value.items():
                updates[k.lower()] = v
        elif op_name in ("replace", "add"):
            updates[path] = value

    if "active" in updates:
        active = str(updates["active"]).lower() == "true" if not isinstance(updates["active"], bool) else updates["active"]
        grafana("POST", f"/api/users/{user_id}/{'enable' if active else 'disable'}".replace("/api/users/", "/api/admin/users/"))

    profile = {
        "login": gf["login"],
        "email": updates.get("emails[type eq \"work\"].value", gf.get("email")),
        "name": updates.get("displayname", gf.get("name")),
    }
    if profile["name"] != gf.get("name") or profile["email"] != gf.get("email"):
        grafana("PUT", f"/api/users/{user_id}", json=profile)

    return jsonify(to_scim(get_grafana_user(user_id)))


@app.put("/Users/<user_id>")
def replace_user(user_id):
    gf = get_grafana_user(user_id)
    if not gf:
        return scim_error(404, f"User {user_id} not found")
    data = request.get_json(force=True)

    emails = data.get("emails") or []
    email = next((e.get("value") for e in emails if e.get("primary")), None) \
        or (emails[0].get("value") if emails else gf.get("email"))
    grafana("PUT", f"/api/users/{user_id}", json={
        "login": data.get("userName", gf["login"]),
        "email": email,
        "name": data.get("displayName", gf.get("name")),
    })
    if "active" in data:
        grafana("POST", f"/api/admin/users/{user_id}/{'enable' if data['active'] else 'disable'}")
    return jsonify(to_scim(get_grafana_user(user_id)))


@app.delete("/Users/<user_id>")
def delete_user(user_id):
    """Soft delete: disable the account, keep the audit trail."""
    if not get_grafana_user(user_id):
        return scim_error(404, f"User {user_id} not found")
    grafana("POST", f"/api/admin/users/{user_id}/disable")
    return "", 204
