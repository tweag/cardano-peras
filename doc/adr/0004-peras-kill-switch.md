# 4. Peras kill switch

Date: 2026-11-11

## Status

Draft

## Context

A kill switch lets node operators stop active Peras participation if it
misbehaves, without halting the node or the network.

Fully disabling Peras is unsafe on a network where Peras is active:

1. Peras-aware and Peras-unaware nodes use different chain selection rules.
 Their selections can diverge, increasing the risk of a hard fork. A
 Peras-aware node must treat a non-Peras-conformant node as malicious.
2. During synchronization, a node must remain aware of the Peras state,
 including certificates that affect chain weight and selection.

The safe boundary is therefore to disable active components, including vote
forging, VoteDB, the synchronization database, and aggregation, while retaining
the network protocols. The node must still diffuse and return the object keys
and certificates it knows about, and retain access to the Peras state needed
for chain selection and synchronization.

Peras is already gated by the `PerasFlag` feature flag (cardano-base #547,
read by consensus #1780 and network #5202). Without the flag, the Peras
mini-protocols are not initialized and the vote-forging thread is not started.
That behavior does not meet the passive-mode requirements above on a
Peras-enabled network.

Alternatives considered:

1. Stop everything (the "nuclear option"): disable all Peras functionality,
   including the network protocols. Rejected because it is unsafe on a
   Peras-enabled network.
2. Startup setting: chosen for the MVP.

## Decision

We will provide the kill switch as a startup setting. An operator enables or
disables active Peras participation in the node's startup configuration. The
setting is read when the node starts, so the node must be restarted for a change
to take effect.

When disabled, vote forging, VoteDB, the synchronization database, and
aggregation must be stopped. Peras network protocols remain available to
diffuse and serve known object keys and certificates. The node must continue
to use Peras-aware chain selection and have access to the state required for
synchronization. Implementing this behavior requires more than switching off
the current `PerasFlag`.

SIGHUP support will be implemented at a later stage during node integration,
not in the MVP.

### UX Improvements

The original signal-based design would re-read credential files on SIGHUP and
enable or disable vote forging without a node restart (consensus #2461 and a
work-in-progress node change). Supporting signal-based restart requires careful
resource lifecycle management: no references that retain access to resources
such as BLS keys may remain after the affected components are stopped. This
requires more precise implementation and integration with Leios and consensus
code.

## Consequences

1. A node restart is required to change the setting. It cannot be toggled
while the node is running.
2. Passive operation must preserve the state and protocol functionality needed
 for Peras-aware chain selection and synchronization. Genesis integration
 is out of scope for the MVP, so synchronization remains an integration
 requirement rather than a capability established by this decision.
3. Verification must establish that voting and aggregation stop while the
 network protocols continue to serve known objects and Peras-aware chain
 selection remains active.
4. The operator-facing `PerasEnabled` setting must implement this passive-mode
 behavior; simply turning the internal `PerasFlag` off is insufficient. A
 different `PerasEnabled` in the consensus parameters is unrelated.
