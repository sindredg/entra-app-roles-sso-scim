# Risk and limitations

Where the identity model deliberately stops, and what production would add. Statements about how Entra
or Grafana behave cite vendor documentation, listed at the end.

Scope note: this project is about identity and access management on Entra ID. The Grafana VM, the
containers and the bridge code exist to give the identity work something real to govern, so limitations
of that supporting infrastructure are noted briefly rather than treated as findings.

## What the identity model establishes

Authentication is centralised in Entra, so tenant password policy, MFA capability and sign-in logs cover
Grafana.

Authorization is denied by default at two independent points. Assignment required on the service
principal stops unassigned users at the identity provider with `AADSTS50105` [1]. Then
`role_attribute_strict` in Grafana denies a login whose token carries no valid `roles` claim. Grafana's
default for that setting is `false` [6], so this is a deliberate departure in the safer direction: a
broken role mapping fails loudly instead of silently landing everyone on Viewer.

Account lifecycle is driven from the same group membership that drives authorization, and converges
without the user ever logging in. Removing someone from a group stops future logins, but only
provisioning removes the account.

Group membership is therefore the single control point: one membership change drives the app role, the
provisioning scope, and the account state.

Two supporting choices. App roles rather than the `groups` claim avoids the overage limit, 200 groups
for JWT and 150 for SAML, past which the claim is replaced by a Graph lookup the app must handle [2].
And direct membership is a platform constraint rather than a preference, since nested groups are
unsupported for app role assignment "for both access and provisioning" [3].

## Where the identity model stops

Scope decisions, not oversights.

**No Conditional Access, MFA enforcement, PIM, access reviews or lifecycle workflows.** This project
governs who can sign in and what role they get. Those controls are the subject of the follow-on
project, Access Control and Identity Governance on Entra ID.

**No recertification.** Group membership grants access indefinitely until someone removes it, and
nothing periodically asks whether it is still warranted.

**Authentication strength is inherited rather than enforced.** The tenant's MFA capability covers
Grafana, but this project sets no policy requiring it, so the assurance level of a Grafana login is
whatever the tenant happens to demand.

## What production would do differently

**Native SCIM is not available for this configuration at any price.** Grafana's native SCIM
provisioning is Enterprise and Cloud only, and the same documentation states it "only works with SAML
authentication" [4]. This lab authenticates over OIDC, chosen because SAML in Grafana is itself an
Enterprise feature. Adopting native SCIM would therefore mean an Enterprise licence *and* moving
authentication from OIDC to SAML. The bridge is not a way of avoiding a licence fee; there is no native
path to compare it against. See [ADR 0002](adr/0002-custom-scim-bridge.md).

**The SCIM endpoint uses a long-lived static bearer token.** That is how the protocol and Entra's
provisioning configuration work, so it is not a deviation. Production would restrict the endpoint to
Entra's published provisioning IP ranges, which Microsoft documents for this purpose [5], rotate the
token on a schedule, and alert on failed authentication. The design compensates in one respect: the
bridge implements no destructive operation ([ADR 0001](adr/0001-soft-delete-over-hard-delete.md)), so the
worst outcome under a compromised token is mass account disablement, which is loud and reversible.

**The OIDC client uses a shared secret with a six-month expiry.** A certificate or federated credential
is the production upgrade, already flagged in [docs/02](02-sso-oidc.md#2-register-the-application).

## Identity loose ends

**The two assignment lists are aligned by hand.** Because provisioning lives on a second enterprise
application ([ADR 0003](adr/0003-separate-provisioning-service-principal.md)), the same three groups are
assigned in two places. As built this is not a gap: assignment is required on the SSO app and both apps
carry the same three groups, so anyone who can obtain a token is inside provisioning scope. Nothing
enforces it, though. Adding a fourth group, or assigning a user directly to one app, would quietly
decouple access from lifecycle. A Graph query comparing the two lists would turn the convention into a
check, and should be written before any fourth group exists.

**A disabled Grafana account can outlive the Entra identity that created it.** Entra sends `DELETE`
when a user is permanently removed from the directory, and the bridge maps that to a disable [8]. The
audit trail is preserved, which is the intent, but nothing reconciles those accounts against a directory
that no longer contains the person. A long-lived tenant would need a retention decision.

**Two Phase 2 test rows are reported rather than shown.** The unassigned-user rejection (`AADSTS50105`)
and the role-change propagation retest were confirmed interactively but not screenshotted, as was the
jwt.ms token inspection. The rest of the phase is evidenced. Marked inline in
[docs/02](02-sso-oidc.md#7-test-matrix).

## Platform behaviour worth knowing, not defects

**Role changes land at next sign-in**, because `skip_org_role_sync = false` re-evaluates from the token
at each login and an active session keeps its role until it ends. Immediate revocation needs session
invalidation, which Grafana OSS does not expose to the identity provider.

**Provisioning and authorization are separate moments.** SCIM creates the account from group
membership; the org role arrives in the `roles` claim at sign-in. So an audit of "who has what in
Grafana" is answered from the app role assignments in Entra rather than from Grafana's user list.

**Deprovisioning converges rather than fires.** Entra's incremental cycles run at approximately 40
minute intervals and the interval is not configurable [7]. Provision on demand exists for testing and
single users, but the steady-state interval is what to plan against.

## Supporting infrastructure

Noted for completeness, outside the identity scope of the project. The environment is portal-provisioned
and documented as steps rather than expressed as code; `infra/main.bicep` is a redacted, hand-adjusted
export kept for overview. Container images run on floating tags. The SCIM bridge has no automated tests.
Egress is unrestricted, there is a single Caddy instance, and there is no monitoring or alerting. All
appropriate for a lab that is deleted between sessions.

## Indicative control mapping

Orientation rather than a compliance claim. The lab was not built against a framework; this table was
written afterwards by reading controls back onto what exists.

| Control area | What this lab does | Where it stops |
|---|---|---|
| Centralised authentication | Entra ID as sole IdP for the app; local admin retained as break-glass | No MFA enforcement, no Conditional Access |
| Access based on role | Entra groups to app roles to Grafana org roles, one control point | No periodic recertification of group membership |
| Deny by default | Assignment required on the SP, plus `role_attribute_strict` in Grafana | |
| Account lifecycle | SCIM create, update and disable driven from group membership | Alignment of the two apps is manual; convergence takes up to a cycle |
| Privileged access | No standing Grafana server admin granted over SSO | |
| Audit | Entra sign-in and provisioning logs; accounts disabled rather than deleted | No log retention, aggregation or alerting |

## Sources

1. [Error AADSTS50105 - The signed in user isn't assigned to a role for the application](https://learn.microsoft.com/troubleshoot/entra/entra-id/app-integration/error-code-aadsts50105-user-not-assigned-role) - Microsoft Learn
2. [Configure group claims and app roles in tokens, group overages](https://learn.microsoft.com/security/zero-trust/develop/configure-tokens-group-claims-app-roles#group-overages) - Microsoft Learn
3. [Microsoft Entra service limits and restrictions](https://learn.microsoft.com/entra/identity/users/directory-service-limits-restrictions) - Microsoft Learn, on nested groups being unsupported for app role assignment
4. [Configure SCIM provisioning](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-scim-provisioning/) - Grafana documentation, on Enterprise/Cloud availability and the SAML requirement
5. [Tutorial: Develop and plan provisioning for a SCIM endpoint, IP ranges](https://learn.microsoft.com/entra/identity/app-provisioning/use-scim-to-provision-users-and-groups#ip-ranges) - Microsoft Learn
6. [Configure Microsoft Entra ID OAuth authentication](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/entraid/) - Grafana documentation, for `role_attribute_strict` and `allow_assign_grafana_admin` defaults
7. [Known issues for provisioning in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/app-provisioning/known-issues) - Microsoft Learn, on the provisioning interval being fixed
8. [How Application Provisioning works, Deprovisioning](https://learn.microsoft.com/entra/identity/app-provisioning/how-provisioning-works#deprovisioning) - Microsoft Learn, on when `DELETE` is sent versus `active=false`

Checked July 2026. Vendor behaviour changes, so treat the citations as accurate as of then rather than
permanently.
