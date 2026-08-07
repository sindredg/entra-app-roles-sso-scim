# 0002 - A custom SCIM bridge rather than a gateway framework

Status: accepted. Applies to [`scim-bridge/`](../../scim-bridge) and [Phase 3](../03-scim-provisioning.md).

## Context

Self-hosted Grafana only exposes a native SCIM endpoint under an Enterprise licence. The lab needed a
real SCIM 2.0 server for Entra's provisioning engine to talk to, and the point of Phase 3 was the Entra
side of provisioning, not the application side.

The Phase 0 plan said we would use an existing SCIM gateway framework. That did not survive contact with
the problem: the frameworks are plugin-based and none ships a Grafana plugin, so using one would still
have meant writing the Grafana adapter ourselves, inside someone else's plugin contract, with the
framework's configuration surface on top.

## Decision

We wrote the bridge directly: one Flask file implementing exactly the SCIM subset Entra uses for user
lifecycle, roughly 200 lines.

## Consequences

**Gained:** the file is short enough to read in one sitting, so it doubles as documentation of the
protocol. The two places where Entra deviates from a clean reading of RFC 7644 are visible as comments
rather than buried in framework config. The odd `PATCH` shapes Entra sends, both
`{"path": "active", "value": false}` and `{"value": {"active": false}}`, are handled in four lines you
can point at.

**Accepted:** this is code we own and nobody else reviews. A framework would have brought other people's
bug fixes, a wider slice of the RFC, and someone else's threat model. Ours implements only what Entra
exercises, so it would not survive being pointed at a different SCIM client. It has no automated tests,
which for a component that can disable accounts is the weakest point in the repo, and the one genuinely
fragile piece, the URL rewrite in the `active` handler, is exactly what a test would pin down.

**On the obvious criticism** that production would use the vendor's native endpoint: mostly right, but
the swap is less direct than it sounds. Grafana's documentation states native SCIM is Enterprise and
Cloud only, and that it "only works with SAML authentication"
([Configure SCIM provisioning](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-scim-provisioning/),
checked July 2026). This lab authenticates over OIDC, chosen because SAML in Grafana is itself an
Enterprise feature. Adopting native SCIM would mean buying a licence *and* moving authentication from
OIDC to SAML, which changes the shape of the whole lab rather than replacing one component. For an OSS,
OIDC-authenticated Grafana there is no native SCIM path at any price.

## When we would revisit

If the bridge needed to serve a second SCIM client, or if it grew past what one person can hold in their
head. Either would be the signal to adopt a framework or to buy the licensed endpoint. Before either, it
should get a test suite.
