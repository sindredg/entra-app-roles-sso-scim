# 90 - Lab journal

Chronological record of what was actually done, in the order it happened, including detours and dead ends. The numbered phase documents (01–03) describe the clean path; this journal is the honest one. Symptom→cause→fix details for each incident live in [99-troubleshooting.md](99-troubleshooting.md).

## Phase 0 - Decisions

- **App:** Grafana OSS, self-hosted in Docker. **SSO protocol: OIDC** - SAML is Enterprise-only in Grafana, OIDC is fully supported in OSS and exposes inspectable JWTs.
- **SCIM plan:** native SCIM in self-hosted Grafana requires an Enterprise license (trial = sales contact), so Phase 3 will bridge Entra's real provisioning engine to Grafana's admin API via an open-source SCIM gateway. Entra-side configuration is identical to any SCIM app.
- **Hostname:** free Azure DNS label on the VM's static public IP + Caddy for automatic Let's Encrypt certificates. No domain purchase.

## Phase 1 - Infrastructure

1. **`SkuNotAvailable` for `Standard_B2s`** in Spain Central, West Europe, and North Europe. The legacy B-series is capacity-restricted for this subscription regardless of region. Switched to the current generation: **`Standard_B2als_v2`** (cheaper, too). Region ended up **Sweden Central**; the region is baked into the FQDN, so this had to be final before any identity configuration.
2. **VM created via portal**: Ubuntu Server 22.04 LTS x64 Gen2, SSH key auth, no inbound ports at creation. DNS label set on the public IP afterwards.
3. **NSG rules added manually - and SSH didn't work.** Silent TCP hang; key never in play. `az network nic list-effective-nsg` revealed all three rules had **source ports** set to the service port (22/443/80) instead of `*`. Clients connect from ephemeral ports, so the rules matched nothing. Fixed all three; connected immediately. Best lesson of the phase.
4. **SSH key passphrase surprise**: the abandoned PS script had created the key with a mangled passphrase (PowerShell quoting of `-N '""'`). Resolved and documented; key usable from WSL after copying with correct permissions (`/mnt/c` files look world-readable to Linux and ssh refuses them).
5. **Docker installed the production way** (GPG-verified apt repo, no `docker` group - `sudo docker` everywhere).
6. **Stack deployed**: `grafana/` copied via scp, CRLF stripped, `.env` filled (domain + local admin password), `chmod 600`, `docker compose config` preview, `up -d`. Certificate obtained on first start.
7. **Observed**: bot probes (`/.env`, `/wp-config.php`, Grafana API) began seconds after certificate issuance - Certificate Transparency logs make every new HTTPS hostname instantly discoverable. Also: early 502s while Grafana finished booting behind an already-live Caddy (transient).
8. **Verified**: positive tests (TLS, local login), negative tests (3000 closed, SSH source-restricted, HTTP→HTTPS 308), reboot survival (containers auto-start, cert persists).

## Phase 2 - SSO

1. **Personas created**: Amanda Admin / Edvard Editor / Victoria Viewer (short az CLI script, not kept in the repo), groups `grafana-admins/-editors/-viewers`, one member each. One membership add silently failed (Victoria); caught by verification, re-added. az's `.cmd` wrapper mangled some JMESPath queries in PowerShell → switched validation to **Microsoft Graph PowerShell** (`Connect-MgGraph`), which also matches production tooling.
2. **App registration `app-grafana-lab`** (portal): single tenant, Web redirect `https://<GRAFANA_FQDN>/login/azuread`, 6-month client secret.
3. **App roles** defined with values `Admin`/`Editor`/`Viewer` - values are a contract with Grafana (matched case-sensitively against the token's `roles` claim), not a naming choice.
4. **Enterprise app**: Assignment required = Yes (deny-by-default), Visible = Yes, three group→role assignments. Verified assignments and effective user→role mapping via Graph.
5. **Grafana side**: `.env` extended with tenant ID / client ID / secret, `AZUREAD_SSO_ENABLED=true`; previewed with `docker compose config` (also verified beforehand that Amanda's Entra credentials fail on the local login form - no local account exists); `up -d` (noted: `restart` would keep old env - recreate is required). Entra ID button appeared on the login page.
6. **Consent stop**: first sign-in hit "Approval required" - tenant restricts user consent, so even `openid profile email` needs an admin. Demonstrated a **per-user grant** via Graph (`ConsentType Principal`) first, then granted **tenant-wide admin consent** (`AllPrincipals`).
7. **Secret hygiene incident**: `docker compose config` output containing the live client secret was pasted into a shared context during the lab. Action: secret rotated after SSO validation (new secret → `.env` → `up -d` → old deleted). Lesson: `compose config` renders secrets in plaintext; treat its output like the `.env` itself.
8. **Login test matrix run**: Amanda/Edvard/Victoria each signed in and landed on the expected org role, captured; Entra sign-in logs confirmed Grafana logins now flow into tenant audit, captured. Unassigned-user rejection and role-change propagation were confirmed interactively but not screenshotted, and token inspection via jwt.ms was done without capturing it. Those three are the outstanding evidence, noted in [02-sso-oidc.md](02-sso-oidc.md#7-test-matrix).

## Phase 3 - SCIM

1. **Bridge built and deployed**: `scim-bridge/` (Python/Flask, ~200 lines) instead of a gateway framework - no ready-made Grafana plugin exists anywhere, and a single readable file implementing exactly the SCIM subset Entra uses documents the protocol better. Deployed via compose (`--build`), routed by Caddy at `/scim/*`, bearer-token protected, no published ports.
2. **First smoke test returned 302 instead of 401** - Grafana's login redirect, not the bridge: Caddy was still running its old in-memory config. Bind-mounted config changes don't trigger recreation; `docker compose restart caddy` fixed it. (Mirror lesson of "env changes need `up -d`".)
3. **Second SCIM token burned immediately** - pasted terminal output containing the fresh token into a shared context. Regenerated; rule reinforced: generated secrets go from terminal to `.env`, nowhere else.
4. **Before-state proven**: created `nils.new`, added to `grafana-viewers`, showed Entra grants access while Grafana has no account (`totalResults: 0` via the bridge) - the gap SCIM closes.
5. **Provisioning blade grayed out** on `app-grafana-lab`: enterprise apps auto-created from app registrations don't support custom SCIM provisioning in the portal. Workaround (a real-world pattern): second, provisioning-only **non-gallery** enterprise app `app-grafana-scim`, same three groups assigned (assignment = scope here, no roles). SSO and provisioning now live on separate service principals that must be kept aligned.
6. **Configured**: tenant URL `/scim` + token, Test Connection passed, user mappings trimmed to `userName`/`displayName`/`emails`/`active(IsSoftDeleted switch)`, group provisioning disabled, scope = assigned users and groups, started.
7. **Initial cycle**: Amanda/Edvard/Victoria *matched* to their JIT-created accounts (action "Other", linked by userName); **Nils created in Grafana having never logged in** - last login "never". 
8. **Groups appeared in the logs** with action "Create" despite group provisioning being disabled - detail pane showed import-for-scope-expansion then `EntrySynchronizationSkip / EntityTypeNotSupported`. Groups drive scope, not payload; the list-view Action column shows the incoming change, not the outcome.
9. **Lifecycle tests, all via Provision on demand**: rename (Nils New → Nils Worker) synced; group removal → account **disabled** in Grafana; re-add → re-enabled (same target ID, no duplicate); new hire Adam Analyst provisioned; tenant-level `AccountEnabled:$false` → evaluated as soft-delete, and because the target was already disabled, Entra **skipped the duplicate operation** - deprovisioning is idempotent across triggers.


The project concludes with phases 1 to 3: infrastructure, SSO, and SCIM provisioning. That is the full account lifecycle for a self-hosted application, working, with the Phase 1 and Phase 3 evidence captured and the Phase 2 evidence still outstanding (see item 8 above).
