# 0001 - Deprovisioning disables the account, it never deletes it

Status: accepted. Applies to [`scim-bridge/app.py`](../../scim-bridge/app.py) and
[Phase 3](../03-scim-provisioning.md).

## Context

Entra signals the end of someone's access in two ways that are not interchangeable. The documented
default is a soft delete: a user unassigned from the app, out of scope, or blocked in the directory
arrives as `PATCH` with `active=false`. A genuine `DELETE /Users/{id}` is sent in a narrower set of
cases, principally when the user is *permanently* deleted from Entra, which happens automatically 30
days after a soft delete or immediately on a manual permanent delete, and also when the target
application does not support soft deletes at all
([How Application Provisioning works, Deprovisioning](https://learn.microsoft.com/entra/identity/app-provisioning/how-provisioning-works#deprovisioning),
checked July 2026).

So `DELETE` does not mean "access revoked", which `active=false` already covered. It means "this
identity no longer exists in the directory". A naive bridge would mirror that onto Grafana's
`DELETE /api/admin/users/{id}`, which is what an earlier draft of the Phase 3 doc said we would do.

## Decision

Both paths disable the Grafana account. `DELETE /Users/{id}` is implemented as
`POST /api/admin/users/{id}/disable`, exactly the same call as `active=false`. Nothing this endpoint
receives can destroy a Grafana account.

## Consequences

**Gained:** the endpoint has no destructive operation at all. The bridge holds a Grafana admin
credential and is reachable from the internet, so under a stolen bearer token the worst an attacker can
do to existing accounts is disable them, which is noisy, reversible and leaves the audit trail intact.
Disabled accounts also keep dashboard ownership and authorship attribution.

**Accepted:** because Entra sends `DELETE` when the directory identity is permanently gone, a Grafana
account can outlive the Entra user it came from. The person is erased upstream and a disabled shell
remains here indefinitely with nothing to reconcile it against. Audit trail over cleanup, deliberately,
but it is a real consequence.

**Not strictly conformant.** We answer `204` to a request we did not literally carry out, and a client
that issues `DELETE` and reads the resource back will still find it. Latent against a stricter client
rather than observed here, and untested.

Disabled accounts accumulate and nothing prunes them, so a long-lived tenant would need a retention
decision we have not made. Production usually lands on the same disable-first choice for the same audit
reason, but pairs it with a documented retention period and a separate deletion process outside the
provisioning path.

## When we would revisit

A compliance requirement demanding true erasure on request, or a disabled-account population large
enough to matter. The change would be to honour `DELETE` literally while keeping `active=false` as a
disable, with the destructive path behind something stronger than the shared bearer token.
