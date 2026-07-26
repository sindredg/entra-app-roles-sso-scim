# 0002 - A custom SCIM bridge rather than a gateway framework

Status: accepted. Applies to [`scim-bridge/`](../../scim-bridge) and [Phase 3](../03-scim-provisioning.md).

## Context

Self-hosted Grafana only exposes a native SCIM endpoint under an Enterprise license. The lab needed a
real SCIM 2.0 server for Entra's provisioning engine to talk to, and the point of Phase 3 was the Entra
side of provisioning, not the application side.

The obvious alternative was an existing SCIM gateway framework, and the Phase 0 plan said we would use
one. That plan did not survive contact with the problem: the frameworks are plugin-based, and none of
them ships a Grafana plugin. Using one would still have meant writing the Grafana adapter ourselves,
inside someone else's plugin contract, with the framework's own configuration surface on top.

## Decision

We wrote the bridge directly: one Flask file implementing exactly the SCIM subset Entra actually uses
for user lifecycle, roughly 200 lines.

## Consequences

The version we got is readable end to end, which turned out to matter more than expected. Because the
file is short enough to read in one sitting, it doubles as documentation of the protocol, and the two
places where Entra deviates from a clean reading of RFC 7644 are visible as comments rather than buried
in framework configuration. The odd `PATCH` shapes Entra sends, both `{"path": "active", "value": false}`
and `{"value": {"active": false}}`, are handled in four lines you can point at.

What we accept is that this is code we own and nobody else reviews. A framework would have brought other
people's bug fixes, a wider slice of the RFC, and someone else's threat model. Ours implements only what
Entra exercises, so it would not survive being pointed at a different SCIM client. It also has no
automated tests, which for a component that can disable accounts is the weakest point in the repo. The
one piece of genuinely fragile code, the URL rewrite in the `active` handler, is exactly the kind of
thing a test would pin down.

The obvious criticism is that production would simply use the vendor's native endpoint, and that is
mostly right. It is worth noting that the swap is less direct than it sounds, though. Grafana's
documentation states that native SCIM provisioning is available in Enterprise and Cloud, and also that it
"only works with SAML authentication"
([Configure SCIM provisioning](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-scim-provisioning/),
checked July 2026). This lab authenticates over OIDC, chosen because SAML in Grafana is itself an
Enterprise feature. So adopting native SCIM would mean buying a licence *and* moving authentication from
OIDC to SAML, which changes the shape of the whole lab rather than replacing one component.

That does not make the bridge a production recommendation. It does mean the honest framing is narrower
than "we cheaped out": for an OSS, OIDC-authenticated Grafana, there is no native SCIM path at any price,
so a bridge is the only way to exercise the real Entra provisioning engine against it.

## When we would revisit

If the bridge needed to serve a second SCIM client, or if it grew past the point where one person can
hold it in their head. Either would be the signal to adopt a framework, or to stop and buy the licensed
endpoint. Before either of those, it should get a test suite.
