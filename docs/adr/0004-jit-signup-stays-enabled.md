# 0004 - JIT sign-up stays enabled after SCIM is live

Status: accepted. Applies to [`grafana/docker-compose.yml`](../../grafana/docker-compose.yml) and
[Phase 2](../02-sso-oidc.md#6-configure-grafana).

## Context

`allow_sign_up = true` lets Grafana create a user on first successful SSO login. Phase 2 needed it,
because before SCIM there was no other way for an account to come into existence.

Phase 3 then added SCIM pre-provisioning, which creates accounts from group membership before anyone
logs in. The Phase 2 doc says SCIM "replaces reliance on this with SCIM pre-provisioning", which a reader
could take to mean the setting was turned off. It was not, and the two paths coexist.

## Decision

`allow_sign_up` stays `true`.

## Consequences

**Safe structurally, not incidentally.** JIT creation cannot produce an account for someone not already
authorized: reaching Grafana requires a token, which requires assignment on the SSO app where assignment
is required, and `role_attribute_strict = true` then denies any token without a valid `roles` claim. The
setting can create an account earlier than SCIM would have, but not for anyone SCIM would have refused.

The two paths also converge, because the same three `grafana-*` groups gate the SSO app and define
provisioning scope. A user who gets a JIT account is by definition inside provisioning scope, so SCIM
picks them up and disables them when membership ends.

**The practical consequence is narrow:** an account can exist slightly before its first provisioning
cycle touches it, and "every Grafana account was created by SCIM" is not literally true. Neither costs
anything here. It would matter if the two apps were ever assigned different groups, the constraint
recorded in [ADR 0003](0003-separate-provisioning-service-principal.md).

## When we would revisit

If the SSO and provisioning apps ever carry different assignments, JIT stops being a harmless second path
and `allow_sign_up = false` becomes the tighter setting. It would pair naturally with
`disable_login_form = true`, which Phase 2 already flags as the next hardening step.
