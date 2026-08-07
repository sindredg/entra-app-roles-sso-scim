# Decision records

The identity design choices that could reasonably have gone the other way: why, what it cost, and what
would change our minds.

| # | Decision | Short version |
|---|---|---|
| [0001](0001-soft-delete-over-hard-delete.md) | Soft delete over hard delete | Deprovisioning disables the Grafana account, never removes it, including for SCIM `DELETE` |
| [0002](0002-custom-scim-bridge.md) | A custom SCIM bridge over a gateway framework | No native SCIM path exists for an OSS, OIDC-authenticated Grafana at any licence tier |
| [0003](0003-separate-provisioning-service-principal.md) | Provisioning on a second service principal | Forced by the portal, and it splits the assignment list in two |
| [0004](0004-jit-signup-stays-enabled.md) | JIT sign-up stays enabled after SCIM | `allow_sign_up` stays `true`; the two paths coexist rather than replace each other |
| [0005](0005-allow-assign-grafana-admin.md) | `allow_assign_grafana_admin` enabled with no role assigned | Setting is on, the `GrafanaAdmin` app role was never created, so nothing is grantable |
| [0006](0006-unpinned-container-images.md) | Container images are not pinned | `grafana/grafana-oss:latest` and `caddy:2` run on floating tags |

Choices that were forced rather than made, or already argued inline like OIDC over SAML and app roles
over the groups claim in the [README](../../README.md#key-design-decisions), are not repeated here.
Infrastructure and container tooling choices are out of scope except where they touch identity.

These were written after the lab was complete rather than at the moment of each decision. The
**context** and **consequences** sections describe what is observably true of the repo and the
platform, checkable against the files and the cited vendor documentation. The **decision** sections
describe intent, which is reconstructed. Where a choice was forced by a constraint, we say so.

Cross-cutting residual risk lives in the [risk and limitations note](../risk-and-limitations.md).
