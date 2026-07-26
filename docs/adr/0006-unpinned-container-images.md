# 0006 - Container images are not pinned

Status: accepted. Applies to [`grafana/docker-compose.yml`](../../grafana/docker-compose.yml).

## Context

The stack runs `grafana/grafana-oss:latest` and `caddy:2`. Neither is pinned to a digest, and `latest`
is not pinned to anything at all.

Worth reading alongside [Phase 1](../01-infrastructure.md#2-install-docker-production-repository-method),
which argues for installing Docker from the GPG-verified apt repository because packages are then
verifiable and version-pinnable. The host install is pinned and verified; the workload images are not.

## Decision

Leave the tags floating.

## Consequences

The upside is real but small: the lab is torn down and rebuilt between sessions, and a floating tag
means each rebuild lands on a current Grafana with current fixes without anyone maintaining a version
number. For a lab that is redeployed more often than it is run, that is convenient.

The cost is that someone cloning this in a year gets a different Grafana than the one that was running
when it was built, and if a future release changes the `[auth.azuread]` settings or the admin API the
bridge calls, the failure will appear to come from nowhere. The Entra-side evidence is unaffected, since
the portal screenshots show Entra configuration rather than Grafana internals, but the Grafana-side
screenshots cannot be tied to a specific version.

There is a security argument in both directions and neither is worth overstating. Floating tags pick up
patches automatically, which is good, and pick up unreviewed changes automatically, which is not.
Pinning to a digest and updating deliberately is where most production guidance lands, paired with
automated update proposals rather than manual tracking.

## When we would revisit

If anything about this lab needed to be reproducible by someone else, or if a Grafana upgrade broke SSO
or the bridge, which is the most likely way this bites. The fix is small, a digest pin on both images
plus a note of the version each screenshot was taken against.
