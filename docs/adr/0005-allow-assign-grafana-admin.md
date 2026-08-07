# 0005 - `allow_assign_grafana_admin` is enabled with no role assigned to it

Status: accepted, with a caveat. Applies to [`grafana/docker-compose.yml`](../../grafana/docker-compose.yml).

## Context

Grafana distinguishes two kinds of admin. Org Admin, which the `Admin` app role maps to, administers a
Grafana organisation. Grafana server admin is a level above it: user management across the instance,
including the local `admin` account. Server admin can only be granted from a token when
`allow_assign_grafana_admin = true`, and then only to users whose `roles` claim contains `GrafanaAdmin`.

The compose file sets it to `true`. The app registration defines three app roles, `Viewer`, `Editor` and
`Admin`. `GrafanaAdmin` is described in the docs as an optional fourth role and was never created.

## Decision

Leave the setting enabled and do not create the `GrafanaAdmin` app role.

## Consequences

**Today this grants nothing.** No token can contain `GrafanaAdmin`, because no such app role exists, so
the setting has no effect on any current sign-in.

**The caveat:** it makes the app registration the only thing standing between a token and server admin.
Creating one app role is a routine change an Application Administrator can make in a couple of clicks,
and that alone would be sufficient to grant server admin over SSO. A short path for the highest
privilege in the application, with nothing in the repo flagging that the second half of the control is
already in place.

The tighter configuration is `false`, turned on only alongside creating the role, so both halves of the
decision are made together rather than months apart. Not changed, on the grounds that altering a working
configuration to make a point is how labs break, and this record achieves most of the same thing.

## When we would revisit

Immediately, if anyone creates a `GrafanaAdmin` app role, at which point this stops being theoretical.
Otherwise the setting should be flipped to `false` the next time the compose file is touched for another
reason.
