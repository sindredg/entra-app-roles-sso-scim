# Workforce Identity Lifecycle: Microsoft Entra ID + self-hosted Grafana on Azure IaaS

> Archived lab record. The environment has been torn down; the implementation and evidence below
> document historical results.

The workforce identity lifecycle was tested against a real, self-hosted application. Entra ID was the
identity provider; Grafana OSS (Docker, behind Caddy for automatic HTTPS, on an Azure VM) was the target.

**All three phases were built and tested**, each ending in a test matrix with positive and negative
cases and screenshot evidence.

| Phase | Built | Doc |
|---|---|---|
| 1. Infrastructure | Grafana OSS + Caddy auto-HTTPS on an Azure VM, public FQDN, deny-by-default NSG | [01](docs/01-infrastructure.md) |
| 2. SSO | App registration + enterprise app, OIDC login, Entra groups mapped to Grafana roles via **app roles**, admin consent | [02](docs/02-sso-oidc.md) |
| 3. Provisioning | Entra automatic provisioning (SCIM 2.0) through a custom bridge: accounts created, updated and disabled from group membership | [03](docs/03-scim-provisioning.md) |

Two rows in Phase 2's matrix, the unassigned-user rejection and the role-change retest, were confirmed
interactively but not captured; both are marked as such in
[docs/02](docs/02-sso-oidc.md#7-test-matrix).

**Documentation:** [docs/00](docs/00-architecture.md) is the architecture reference.
[docs/90](docs/90-lab-journal.md) is the chronological journal including detours and dead ends;
[docs/99](docs/99-troubleshooting.md) is symptom, cause, fix, lesson. The
[decision records](docs/adr/) cover the choices that could have gone the other way, and the
[risk note](docs/risk-and-limitations.md) covers what the lab does not protect against.

## The cast

| Persona | Group | Grafana role | Used for |
|---|---|---|---|
| Amanda Admin | `grafana-admins` | Admin | Platform engineer running the service |
| Edvard Editor | `grafana-editors` | Editor | SRE building dashboards |
| Victoria Viewer | `grafana-viewers` | Viewer | Read-only stakeholder; deprovisioning test subject |
| Nils New / Worker | `grafana-viewers` | Viewer | New hire: provisioned before first login, disabled automatically on exit |
| Adam Analyst | `grafana-viewers` | Viewer | Second joiner, provisioned the same way |

## Key design decisions

**OIDC over SAML.** SAML in Grafana is Enterprise-only; OIDC works fully in OSS and exposes
inspectable JWTs.

**App roles over the groups claim.** Entra groups are assigned to app roles (`Viewer`/`Editor`/
`Admin`) on the enterprise application, so the token carries app-defined role semantics instead of
group GUIDs. Avoids the 200-group overage limit and keeps directory structure decoupled from app
authorization.

**SCIM via a custom bridge.** Native SCIM in self-hosted Grafana is Enterprise-licensed *and*
SAML-only, so there is no native path for this configuration at any licence tier. Provisioning runs
through a small readable Python bridge (~200 lines) translating Entra's SCIM 2.0 calls into Grafana
admin API calls. The Entra side is identical to provisioning any SCIM-capable app. Reasoning and cost
in [ADR 0002](docs/adr/0002-custom-scim-bridge.md).

**Portal-provisioned infrastructure, documented as steps.** The Azure resources are few and created
once, so the repo documents exact settings and reasoning rather than shipping deployment automation.
Directory objects are scripted where repetition made it worthwhile, see `scripts/`.

**Azure DNS label + Caddy.** Free `<label>.<region>.cloudapp.azure.com` on a static IP; Caddy obtains
and renews Let's Encrypt certificates automatically. The FQDN is baked into the redirect URI,
`root_url` and SCIM tenant URL, so it is chosen once and treated as immutable.

## Repository layout

```
├── docs/
│   ├── 00-architecture.md        Components, networking, identities, app registration vs.
│   │                             enterprise app, token flow, permissions
│   ├── 01-infrastructure.md      Phase 1: VM, Docker, Caddy, HTTPS
│   ├── 02-sso-oidc.md            Phase 2: app registration, app roles, consent, OIDC config
│   ├── 03-scim-provisioning.md   Phase 3: SCIM bridge + Entra provisioning
│   ├── 90-lab-journal.md         What actually happened, chronologically
│   ├── 99-troubleshooting.md     Symptom, cause, fix, lesson
│   ├── risk-and-limitations.md   Residual risk, what production would do differently
│   ├── adr/                      Decision records
│   └── img/                      Evidence screenshots, per phase
├── infra/
│   └── main.bicep                RG export, redacted and hand-adjusted. Overview only,
│                                 not a tested deployment template
├── grafana/
│   ├── docker-compose.yml        Grafana OSS + Caddy + SCIM bridge
│   ├── Caddyfile                 Reverse proxy + automatic HTTPS
│   └── .env.example              All secrets/IDs as placeholders, copy to .env (gitignored)
├── scim-bridge/
│   ├── app.py                    SCIM 2.0 to Grafana admin API bridge (Flask)
│   ├── Dockerfile
│   └── requirements.txt
└── scripts/
    └── UserGroupRole-Relation.ps1   Graph PowerShell: effective user → group → app role mapping
```

## Conventions

- **Use placeholders for secrets.** Runtime values belong in `.env` on the VM
  (gitignored, `chmod 600`). Keep credential values out of rendered configs, debug output, and screenshots; see
  [the incident that taught this](docs/99-troubleshooting.md#live-client-secret-rendered-into-shared-output).
- Entra objects use consistent naming: groups `grafana-<role>`, app registration `app-grafana-lab`,
  provisioning app `app-grafana-scim`.
- Every phase ends with a test matrix carrying both positive tests (it works) and negative tests
  (it's closed).
