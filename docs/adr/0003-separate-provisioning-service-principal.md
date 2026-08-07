# 0003 - SSO and provisioning live on separate service principals

Status: accepted. Applies to [Phase 3](../03-scim-provisioning.md).

## Context

The plan was one application: `app-grafana-lab`, carrying the OIDC configuration, the app roles, the
group assignments and the SCIM provisioning configuration. One object, one assignment list, one place to
look.

The portal does not allow it. Enterprise applications that Entra auto-creates from an app registration
do not offer custom SCIM provisioning; the blade is present but disabled. Only gallery and non-gallery
applications get it, and there is no setting to flip.

## Decision

A second, provisioning-only non-gallery enterprise application, `app-grafana-scim`, hosts the
provisioning engine. The same three `grafana-*` groups are assigned to it, where assignment defines
provisioning scope rather than any role.

## Consequences

**The model still holds.** Assignment is required on the SSO app and both apps carry the same three
groups, so a user who can obtain a token is by definition inside provisioning scope. Access and account
lifecycle remain coupled, and group membership is still the single control point.

**The coupling is now maintained rather than structural.** It holds because two lists happen to match,
not because anything checks that they do. Adding a fourth group to the SSO app without adding it to the
provisioning app would decouple the two, and the result would look correct: those users sign in, Grafana
JIT-creates them, and nothing indicates they sit outside the deprovisioning path. That is a consequence
of a change nobody has made rather than a live gap, but it is what to remember before extending the
model.

We accepted the split because the alternative was not building Phase 3 at all. It is also a real-world
pattern rather than a lab artefact, since plenty of production tenants end up with provisioning on a
separate non-gallery app for the same reason. The mitigation is to treat the two assignment lists as one
object stored twice and change them together.

## When we would revisit

If Grafana became a gallery application in Entra, the split disappears and this decision goes with it.
Short of that, the available improvement is a Graph query comparing the two assignment lists and
reporting any difference, worth writing before a fourth group ever exists. It is not written.
