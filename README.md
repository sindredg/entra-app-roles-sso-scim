# Workforce Web App - Microsoft Entra ID + Self-Hosted Grafana Web App on Azure IaaS

A hands-on lab that runs the workforce identity lifecycle against a real, self-hosted open-source application. Microsoft Entra ID is the identity provider; Grafana OSS (Docker, behind Caddy for automatic HTTPS, on an Azure VM) is the target application.

## How this repo is organized

Two kinds of documentation: [docs/](docs/)

- **Phase walkthroughs (`docs/01`-`03`)**: the clean path: how to set this up when everything goes as it should.
- **Lab journal + troubleshooting (`docs/90`, `docs/99`)**: what actually happened, in order, including detours, dead ends, and the fixes. The journal is chronological; the troubleshooting log is symptom, cause, fix, lesson.

The architecture reference (`docs/00`) underpins both.

For the reasoning behind the choices, see the [decision records](docs/adr/) for the ones that could have
gone the other way, and the [risk and limitations note](docs/risk-and-limitations.md) for what the lab
knowingly does not protect against and what the production version of each choice would look like.

## What was built

| Phase | Deliverable | relevance |
|---|---|---|
| 1. Infrastructure | Grafana OSS + Caddy (auto-HTTPS) on an Azure VM, public FQDN | Web application's supporting infrastructure |
| 2. SSO | App registration + enterprise application, OIDC login, Entra groups mapped to Grafana roles via **app roles**, admin consent handling | Identity and access management for applications |
| 3. Provisioning | Entra automatic provisioning (SCIM 2.0) through a custom bridge: accounts created, updated and deprovisioned from group membership and account state | Application provisioning and account lifecycle management |

All three phases are built and working, each ends with a test matrix covering positive and negative cases, and each is evidenced with screenshots. Two rows in Phase 2's matrix, the unassigned-user rejection and the role-change retest, were confirmed interactively but not captured; both are marked as such in [docs/02](docs/02-sso-oidc.md#7-test-matrix).

## The cast

| | Persona | Group | Grafana role |
|---|---|---|---|
| Amanda Admin | Platform engineer running the service | `grafana-admins` | Admin |
| Edvard Editor | SRE building dashboards | `grafana-editors` | Editor |
| Victoria Viewer | Read-only stakeholder | `grafana-viewers` | Viewer |
| Nils New / Worker | New hire: account provisioned before first login, disabled automatically on exit | `grafana-viewers` | Viewer |
| Adam Analyst | Second joiner, provisioned the same way | `grafana-viewers` | Viewer |

## Key design decisions

**OIDC over SAML.** SAML in Grafana is Enterprise-only; OIDC works fully in OSS and exposes inspectable JWTs, keeping the token and claims flow visible, which is the point of the lab.

**App roles over the groups claim.** Entra groups are assigned to app roles (`Viewer`/`Editor`/`Admin`) on the enterprise application; the token carries app-defined role semantics instead of group GUIDs. Avoids the 200-group overage limit and keeps directory structure decoupled from app authorization.

**SCIM via a custom bridge.** Native SCIM in self-hosted Grafana is Enterprise-licensed, so provisioning runs through a small, readable Python bridge (~200 lines) that translates Entra's SCIM 2.0 calls to Grafana admin API calls. The Entra side is identical to provisioning any SCIM-capable app. This is the clearest deviation from what production would do, which is to use the vendor's native endpoint and pay for it; the reasoning and the cost are in [ADR 0002](docs/adr/0002-custom-scim-bridge.md), and the walkthrough is [docs/03](docs/03-scim-provisioning.md).

**Portal-provisioned infrastructure, documented as steps.** The Azure resources are few and created once; the repo documents exact settings and reasoning rather than shipping deployment automation. Directory objects are scripted (az/Graph PowerShell) where repetition made it worthwhile - see `scripts/`.

**Azure DNS label + Caddy.** Free `<label>.<region>.cloudapp.azure.com` name on a static IP; Caddy obtains and renews Let's Encrypt certificates automatically. The FQDN is baked into the redirect URI, `root_url` and SCIM tenant URL - chosen once, treated as immutable.

## Repository layout

```
├── README.md
├── LICENSE
├── docs/
│   ├── 00-architecture.md        Reference: components, networking, identities,
│   │                             app registration vs. enterprise app, tokens, permissions
│   ├── 01-infrastructure.md      Phase 1: VM, Docker, Caddy, HTTPS
│   ├── 02-sso-oidc.md            Phase 2: app registration, app roles, consent, OIDC config
│   ├── 03-scim-provisioning.md   Phase 3: SCIM bridge + Entra provisioning
│   ├── 90-lab-journal.md         What actually happened, chronologically, caveats included
│   ├── 99-troubleshooting.md     Symptom, cause, fix, lesson
│   ├── risk-and-limitations.md   Residual risk, what production would do differently
│   ├── adr/                      Decision records for the choices that could have gone otherwise
│   └── img/                      Evidence screenshots, per phase
├── infra/
│   └── main.bicep                RG export, redacted and hand-adjusted. There for
│                                 overview only, not a tested deployment template
├── grafana/
│   ├── docker-compose.yml        Grafana OSS + Caddy + SCIM bridge
│   ├── Caddyfile                 Reverse proxy + automatic HTTPS
│   └── .env.example              All secrets/IDs as placeholders - copy to .env (gitignored)
├── scim-bridge/
│   ├── app.py                    SCIM 2.0 to Grafana admin API bridge (Flask)
│   ├── Dockerfile
│   └── requirements.txt
└── scripts/
    └── UserGroupRole-Relation.ps1   Graph PowerShell: effective user -> group -> app role mapping
```

## Conventions

- **No secrets in the repo.** Placeholders everywhere; runtime values live in `.env` on the VM (gitignored, `chmod 600`). Rendered configs and debug output are treated as secret-bearing too - see [the incident that taught this](docs/99-troubleshooting.md#live-client-secret-rendered-into-shared-output).
- Entra objects use consistent naming: groups `grafana-<role>`, app registration `app-grafana-lab`, provisioning app `app-grafana-scim`.
- Every phase ends with a test matrix containing both positive tests (it works) and negative tests (it's closed) - evidence over assertion.

> **Note:** the lab environment may be torn down between sessions; the documented FQDN will not necessarily be live.
