# Decision records

Short records for the identity design choices in this lab that could reasonably have gone the other way.
The phase walkthroughs describe what we built; these describe why, what it cost, and what would make us
change our minds.

The scope is deliberately narrow. These cover decisions about identity and access, since that is what
the project is about. Choices about the surrounding infrastructure and container tooling are not
recorded here, and choices that were forced rather than made, or already argued inline like OIDC over
SAML and app roles over the groups claim in the [README](../../README.md#key-design-decisions), are not
repeated.

These were written after the lab was complete rather than at the moment of each decision, and they
separate two things deliberately. The **context** and **consequences** sections describe what is
observably true of the repo and of the platform, and are checkable against the files and the vendor
documentation cited. The **decision** sections describe intent, which is reconstructed. Where a choice
was forced by a constraint rather than chosen, we say so, and where the reasoning is a rationalisation
offered after the fact we would rather it read that way than pretend to a deliberation that did not
happen.

| # | Decision | Short version |
|---|---|---|
| [0001](0001-soft-delete-over-hard-delete.md) | Soft delete over hard delete | Deprovisioning disables the Grafana account, never removes it, including for SCIM `DELETE` |
| [0002](0002-custom-scim-bridge.md) | A custom SCIM bridge over a gateway framework | No native SCIM path exists for an OSS, OIDC-authenticated Grafana at any licence tier |
| [0003](0003-separate-provisioning-service-principal.md) | Provisioning on a second service principal | Forced by the portal, and it splits the assignment list in two |

Cross-cutting residual risk lives in the [risk and limitations note](../risk-and-limitations.md).
