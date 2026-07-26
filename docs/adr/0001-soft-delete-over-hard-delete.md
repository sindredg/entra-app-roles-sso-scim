# 0001 - Deprovisioning disables the account, it never deletes it

Status: accepted. Applies to [`scim-bridge/app.py`](../../scim-bridge/app.py) and
[Phase 3](../03-scim-provisioning.md).

## Context

Entra's provisioning service signals the end of someone's access in more than one way, and the two are
not interchangeable. Microsoft documents the default as soft delete: a user who is unassigned from the
app, goes out of scope, or is blocked in the directory arrives as `PATCH` with `active=false`. A genuine
`DELETE /Users/{id}` is sent in a narrower set of cases, principally when the user is *permanently*
deleted from Entra, which happens automatically 30 days after a soft delete or immediately on a manual
permanent delete, and also when the target application does not support soft deletes at all
([How Application Provisioning works, Deprovisioning](https://learn.microsoft.com/entra/identity/app-provisioning/how-provisioning-works#deprovisioning),
checked July 2026).

So `DELETE` here does not mean "access revoked", which `active=false` already covered. It means "this
identity no longer exists in the directory". A naive bridge would mirror that by mapping it to Grafana's
`DELETE /api/admin/users/{id}`, which is what an earlier draft of the Phase 3 doc said we would do.

## Decision

Both paths disable the Grafana account. `DELETE /Users/{id}` is implemented as
`POST /api/admin/users/{id}/disable`, exactly the same call as `active=false`. Nothing this endpoint
receives can destroy a Grafana account.

## Consequences

What we get is that the endpoint has no destructive operation at all. The bridge holds a Grafana admin
credential and is reachable from the internet, so its blast radius under a stolen bearer token is worth
minimising. With no delete path, the worst an attacker with the token can do to existing accounts is
disable them, which is noisy, reversible, and leaves the audit trail intact. Disabled accounts also keep
dashboard ownership and authorship attribution, which a delete would orphan.

What we accept follows from what `DELETE` actually means. Because Entra sends it when the directory
identity is permanently gone, mapping it to a disable means a Grafana account can outlive the Entra user
it was created from: the person is erased upstream, and a disabled shell remains here indefinitely with
nothing to reconcile it against. That is the deliberate trade, audit trail over cleanup, but it is a real
consequence and it is the one a reviewer should push on.

We are also not strictly conformant. We answer `204` to a request we did not literally carry out, and a
client that issues `DELETE` and reads the resource back will still find it. That is a latent problem
against a stricter client rather than an observed one here, and we have not tested it.

Disabled accounts accumulate, and nothing in this lab prunes them, so a long-lived tenant would need a
retention decision we have not made. Production usually lands on the same disable-first choice for the
same audit reason, but pairs it with a documented retention period and a separate, deliberate deletion
process outside the provisioning path.

## When we would revisit

If a compliance requirement demanded true erasure on request, or if the disabled-account population grew
enough to matter. The change would be to honour `DELETE` literally while keeping `active=false` as a
disable, and to put the destructive path behind something stronger than the shared bearer token.
