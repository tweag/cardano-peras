# 4. Peras kill switch

Date: 2026-11-11

## Status

Draft

## Context

A kill switch lets node operators stop Peras from operating if it misbehaves,
without halting the node or the network.

The original design was signal-based. On SIGHUP the node would re-read its
credential files and enable or disable vote forging without a restart
(consensus #2461 and a work-in-progress node change). We are not delivering
this in the MVP:

- Leios passes private keys to consensus, so handling the shared key needs
agreement with Leios.
- It is an additional usability feature, not required for the MVP.

Peras is already gated by the `PerasFlag` feature flag (cardano-base #547,
read by consensus #1780 and network #5202). Without the flag, the Peras
mini-protocols are not initialized and the vote-forging thread is not started.

Alternatives considered:

1. Signal-based reload (original design): deferred, not part of the MVP.
2. Stop everything (the "nuclear option"): disable all Peras functionality,
not only voting. Not implemented for now (see Decision).
3. Startup setting: chosen.

## Decision

We will provide the kill switch as a startup setting. An operator enables or
disables Peras in the node's startup configuration. The setting is read when
the node starts, so the node must be restarted for a change to take effect.

Disabling Peras stops voting and the Peras network protocols only. The node
continues to operate as a Praos node.

We will not implement stop-everything logic unless a need arises or further
research shows it is required. The signal-based reload will be implemented at
a later stage.

## Consequences

1. A node restart is required to change the setting. It cannot be toggled
while the node is running.
2. A node started with Peras disabled cannot, in principle, sync Peras
certificates. Once Peras exists on a network, such a node may be unable to
sync (Genesis integration is out of scope for the MVP).
3. Verification is indirect: no Object Diffusion tracing, no votes or
certificates added to ChainDB, VoteDB or CertDB, and the NodeKernel log
showing Peras disabled.
4. The signal-based reload remains possible future work (#2461).
5. Terminology: the operator sets `PerasEnabled` in the node configuration,
which turns the internal `PerasFlag` on or off. A different `PerasEnabled`
in the consensus parameters is unrelated.
