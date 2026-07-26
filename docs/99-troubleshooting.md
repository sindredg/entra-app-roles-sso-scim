# 99 - Troubleshooting log

What broke, why, and the fixes in symptom→cause→fix→lesson form. Chronological narrative lives in the [lab journal](90-lab-journal.md).

## Incidents

### `SkuNotAvailable`: VM sku rejected in 3 regions
**Symptom:** VM create preflight failed with capacity restrictions in Spain Central, West Europe and North Europe.
**Cause:** the legacy B-series is capacity-restricted for this subscription, independent of region. `Standard_B2als_v2` (current generation, and cheaper) was available.
**Fix:** switched size and settled on Sweden Central. Checkable in advance with `az vm list-skus -l <region> --size <sku> -o table` (Restrictions column).
**Lesson:** the FQDN embeds the region - finalize region before wiring identity config to the URL. Read the innermost `Code:`/`Message:` pair; ignore trailing tracebacks.

### SSH silently hung despite a "correct-looking" NSG rule
**Symptom:** `ssh` and `nc` to port 22 timed out; `ssh -v` stopped at `Connecting to <IP> port 22`. Rule looked right in the portal; source IP verified.
**Cause:** all three inbound rules had **source ports** set to the service port (22/443/80). Clients connect *from* ephemeral high ports, so no packet ever matched; traffic fell through to `DenyAllInBound`. NSGs filter in the Azure fabric, so nothing appears in-VM.
**Fix:** source port ranges `*` on all rules; destination port carries the meaning.
**Lesson:** `az network nic list-effective-nsg` is the ground truth when the portal looks right and reality disagrees. Filter on source *address* and destination *port*; source port is almost always `*`.
 
### SSH key demanded an unknown passphrase
**Symptom:** `Enter passphrase for key ...` for a key created "without" one.
**Cause:** an earlier script ran `ssh-keygen -N '""'` - PowerShell quoting made the passphrase literally two quote characters.
**Fix:** the literal `""` worked; passphrase then removed with `ssh-keygen -p`. Related: keys used from WSL must live in the WSL filesystem with `chmod 600`, files under `/mnt/c` appear world-readable and ssh refuses them ("UNPROTECTED PRIVATE KEY").
**Lesson:** quoting across shells is a real attack on your time; verify key usability right after creation.

### 502s from Caddy right after first start
**Symptom:** `dial tcp <container>:3000: connection refused` in Caddy logs; site returned 502 briefly.
**Cause:** boot order - Caddy is up (and the certificate issued) ~30 s before Grafana finishes initializing.
**Fix:** none needed; transient.
**Lesson:** check `docker compose ps` before diagnosing.

### Bot probes seconds after certificate issuance
**Symptom:** requests for `/.env`, `/wp-config.php`, `/backup.sql`, `/.git/HEAD`, `/api/status` from unknown IPs within seconds of the cert being obtained.
**Cause:** not a targeted attack - Let's Encrypt publishes new certificates to public Certificate Transparency logs; scanners watch the feed and probe every new hostname for leaked files and known CVEs.
**Fix:** nothing to fix. Every probe got 302/401; secrets live outside any webroot.
**Lesson:** a public HTTPS endpoint is discovered the moment it exists. Deny-by-default and secret hygiene are not paranoia.

### First SSO login: "Approval required"
**Symptom:** Amanda's sign-in stopped at an admin-approval prompt instead of a consent screen.
**Cause:** the app requests delegated scopes (`openid profile email`) at runtime; the tenant restricts user consent, so a standard user cannot approve anything.
**Fix:** admin consent: Entra ID admin center "Grant admin consent" under API permissions on the enterprise application.
**Lesson:** restricted user consent is working as designed when it stops you. The prompt is the control doing its job, not a misconfiguration, and the fix is an admin decision rather than a setting to relax.

### az CLI mangled directory queries from PowerShell
**Symptom:** `az ad` queries run from PowerShell returned empty or malformed results, and one group membership add reported success while the member was not there (Victoria). Caught only because every write was followed by a read.
**Cause:** on Windows `az` is a `.cmd` wrapper, so JMESPath expressions and quoted filters are re-parsed by `cmd` on the way through. Quoting that is correct for PowerShell is not necessarily what az receives.
**Fix:** moved verification to Microsoft Graph PowerShell (`Connect-MgGraph`), which is a native module with no shell wrapper in the path, and which is also closer to production tooling.
**Lesson:** verify every directory write with a read. A silent no-op is worse than an error, and cross-shell quoting produces silent no-ops. This is the same class of bug as the `ssh-keygen -N '""'` passphrase above.

### Live client secret rendered into shared output
**Symptom:** not a failure. `sudo docker compose config`, used to preview the rendered Grafana configuration, printed the live OIDC client secret in plaintext, and that output was pasted into a shared context during the lab.
**Cause:** `compose config` resolves `.env` and interpolates every variable. It is a rendering tool, not a redacting one. The habit of previewing config before applying it is good; the habit of sharing the preview is not.
**Fix:** treated the secret as burned and rotated it: new secret in the app registration → `.env` → `docker compose up -d` → old secret deleted. Same thing happened again in Phase 3 with a freshly generated SCIM bearer token pasted from terminal output; regenerated the same way.
**Lesson:** rendered config and terminal output are secret-bearing artifacts and deserve the same handling as `.env` itself. Generated secrets go from the terminal into `.env` and nowhere else. Rotation is cheap here and expensive later, so rotate on suspicion rather than on proof.

### SCIM smoke test returned 302 instead of 401
**Symptom:** `curl /scim/Users` without a token returned `HTTP/2 302` with `redirectTo=%2Fscim%2FUsers`. Grafana's login redirect, not the bridge's 401.
**Cause:** the `/scim/*` request fell through to `reverse_proxy grafana:3000` because Caddy was still running its old configuration. The Caddyfile is bind-mounted: changing the file changes nothing about the *service definition*, so `docker compose up -d` didn't recreate the container, and Caddy only reads config at startup.
**Fix:** `sudo docker compose restart caddy`; the retest then returned 401 without a token and a `ListResponse` with one, as expected.
**Lesson:** bind-mounted config edits need a restart/reload. The mirror image of "env changes need `up -d`, not `restart`".

### SCIM provisioning blade grayed out: Automatic provisioning not supported
**Symptom:** `app-grafana-lab` → Provisioning showed "Out of the box automatic provisioning ... not supported" with Get started disabled.
**Cause:** the enterprise app was auto-created from an **app registration**; the portal only enables custom SCIM provisioning on apps created as gallery or **non-gallery** applications.
**Fix:** created a scim dedicated enterprise app (`app-grafana-scim`): Create your own application → non-gallery → assign the same groups (assignment defines provisioning *scope*; no roles) → Provisioning now available.
**Lesson:** SSO and provisioning can live on separate service principals. The two assignment lists must be kept aligned.

### Groups appeared in SCIM provisioning logs despite group provisioning being disabled
**Symptom:** the three `grafana-*` groups showed up with action "Create" toward the SCIM target.
**Cause:** scope "assigned users and groups" requires Entra to import assigned groups to expand their members. Detail pane: `EntryImportAdd: Success` → `EntrySynchronizationSkip: EntityTypeNotSupported`.
**Fix:** none needed - nothing was sent to the endpoint.
**Lesson:** groups drive *scope*, not payload; the list-view Action column shows the incoming change type, not the outcome. Always open the detail pane before diagnosing.

## Known traps
| Area | Trap |
|---|---|
| SSO | `AADSTS50011`, redirect URI mismatch. Usually a wrong `GF_SERVER_ROOT_URL`; must byte-match `.../login/azuread` |
| SSO | Role changes apply at next login, not mid-session (`skip_org_role_sync=false`) |
| SSO | `AADSTS50105`, assignment required + user not assigned |
| Docker | `docker compose restart` keeps old env. config changes need `up -d` (recreate) |
| SCIM | Entra incremental cycle is 40 min. Use Provision on demand when testing |
