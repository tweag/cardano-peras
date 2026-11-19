# 5. peras-kill-switch

Date: 2026-11-19

## Status

Accepted

Supersedes [4. Peras kill switch](0004-peras-kill-switch.md)

## Context

A `KillSwitch` is a machanism that node operators can use to restrict or
fully disable Peras protocol. Kill-switch is expected to be used only
during disaster scenarios, related to Peras.

Fully disabling Peras carries a risk on a network where Peras is active:

1. Peras-aware and Peras-unaware nodes use different chain selection rules.
 Peras-aware node with Peras disabled will use the same chain selection rules,
 but it will miss latest certificates, that are used for a selection.
 Their selection results can diverge, increasing the risk of a hard fork. A
 Peras-aware node must treat a non-Peras-conformant node as malicious.
2. During synchronization, a node must remain aware of the Peras state,
 including certificates that affect chain weight and selection.

The lowest-risk boundary is therefore to disable active components, including vote
forging, VoteDB, the synchronization database, and aggregation, while retaining
the network protocols. The node must still diffuse and return the votes
and certificates it knows about, and retain access to the Peras state needed
for chain selection and synchronization.

Peras is already gated by the `PerasFlag` feature flag (cardano-base #547,
read by consensus #1780 and network #5202). Without the flag, the Peras
mini-protocols are not initialized and the vote-forging thread is not started.
That behavior does not meet the passive-mode requirements above on a
Peras-enabled network.

There is an additional option for the network `ExperimentalProtocols` that
enables Peras. This option interferes with the `PerasEnabled` flag.

During early stages, other development teams want to have a way to completely
disable Peras, to remove any effects of the network.

Alternative implementations considered:

1. Stop everything (the "nuclear option"): disable all Peras functionalities,
   including the network protocols. This option can be considered as a way
   to disable Peras on the network in case major rework is needed.
2. Passive mode: additional mode for Peras that allows to disable only active
   (voting) thread, but keep all passive: network protocols and certificate
   inclusion active.

Previous decision favoured a passive option as the main one, but additional
integration requirements showed that this option is valuable only during the
late integration step and should be aligned with the node developer teams.
Due to a timing constraints the nuclear option provides a better guarantees
and will be sooner be useful.

## Decision

We will provide the kill switch as a startup setting. An operator enables or
disables active Peras participation in the node's startup configuration.

When disabled, a nuclear option applies: that includes disabling of the
vote forging, and the peras network protocols are no longer announced
in the node to node communication.
The node must continue to use Peras-aware chain selection and have access to
the state required for synchronization.

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
2. Verification must establish that, with Peras disabled, voting and aggregation
 stop and the Peras network protocols are not announced.
3. The operator-facing `PerasEnabled` setting must implement this nuclear
 option behavior.
4. The divergence risk described in Context remains when Peras is disabled on
 a Peras-active network. This is accepted: the setting is intended for a
 severe Peras failure, after which Peras should not be re-enabled without a
 code change, and a node with Peras disabled behaves much like a node running
 an earlier version without Peras.
