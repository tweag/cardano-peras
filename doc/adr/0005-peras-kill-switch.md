# 5. peras-kill-switch

Date: 2026-11-19

## Status

Accepted

Supersedes [4. Peras kill switch](0004-peras-kill-switch.md)

## Context

A `KillSwitch` is a mechanism that node operators can use to restrict or
fully disable Peras protocol. A Kill-switch is expected to be used only
during disaster scenarios, related to Peras.

Peras is a protocol that impacts chain selection directly, so disabling it
requires careful consideration of the consequences.
Notably, Peras-aware and Peras-unaware nodes use different chain selection rules.
A Peras-aware node with Peras disabled will use the same chain selection rules
as other Peras-aware nodes, but it will miss the latest certificates, that are
used for chain selection. Thus its selection results can diverge as well,
increasing the risk of a (hard) fork. For that reason, a Peras-aware node should
treat a non-Peras-conformant node as adversarial.

The lowest-risk boundary is therefore to only disable active components
[Option 1], i.e. vote forging and the voting thread, while retaining the Peras
network protocols. This way, the node will still diffuse and return the votes
and certificates it knows about, and retain access to the Peras state needed for
getting the same chain selection results as other Peras-aware nodes. If enough
nodes stop participating actively, then Peras will be effectively disabled on
the network, while preserving a consistent chain selection among all nodes.

On the other hand, fully disabling Peras (both voting and network protocols)
[Option 2] carries a risk if it is done by a node on its own, on a network where
Peras is active: this node risks diverging from the rest of the network, and
missing historical data that are important for future syncing nodes. Those risks
are nevertheless negligible in the case of the disaster, where network
substantially misbehaves or observes an unintended fork.

**Considered Options:**


1. Passive mode: disable only the active components (voting thread),
   but keep all passive ones (network protocols and certificate inclusion)
   enabled.
2. Disable everything: disable all Peras functionalities,
   including the network protocols and certificate inclusion. This option can be
   considered as a way to disable Peras on the network in case major rework is
   needed.

In its current state of development, Peras is already gated by the `PerasFlag`
feature flag (cardano-base #547, read by consensus #1780 and network #5202).
Without the flag, the Peras mini-protocols are not initialized and the
vote-forging thread is not started. Certificate inclusion is also disabled.
That behavior meets the _disable everything_ requirements but does not meet the
passive mode requirements.

There is also an existing Cardano option, `ExperimentalProtocols`, that also
allows/prevents the initialization of certain network protocols, including Peras
ones. However, unlike `PerasFlag`, this one doesn't have any impact on the
voting thread.

These two flags/options are justified by the need of other development teams to
have a way to completely disable Peras and remove any effects on the network.

Previous ADR (0004) favoured the passive mode as the main kill-switch to be
delivered. However, recent integration requirements showed that the _disable 
everything_ fit the immediate needs of the development teams, while the passive
mode wouldn't be enough for their use cases. Due to timing constraints, it thus
seems reasonable to deliver the _disable everything_ kill-switch first.

## Decision

We will first implement the kill-switch applicable in a case of a major disaster
related to Peras misbehaving or having unintended interactions with other
network protocols, where the only reasonable solution is to disable all Peras
functionalities and wait for a protocol fix [Option 2]. In this particular case,
the possibly different behavior between Peras-enabled and Peras-disabled nodes
is of lesser concern.

This kill switch will be provided as a node startup setting. An operator enables
or disables Peras in the node's startup configuration.

When disabled, vote forging, cert inclusion are turned off. Peras network
protocols are no longer announced in the node-to-node communication, and hence
not initialized either.
The node continues to use Peras chain selection, but will not obtain the newest
certificates, so it will effectively behave from that point like a Praos node
w.r.t chain selection.

### UX Improvements

The original signal-based design for passive mode would re-read credential files
on SIGHUP, in order to enable or disable vote forging without a node restart
(consensus #2461 and a work-in-progress node change). Supporting signal-based
restart requires careful resource lifecycle management: no references should
retain access to resources such as BLS keys after the affected components are
stopped. This requires deeper investigation and integration with Leios and
consensus code.

## Consequences

With Option 2 being adopted:

1. A node restart is required to change the
   setting. It cannot be toggled while the node is running.
1. Verification must establish that, with Peras disabled, voting and cert
   inclusion stop and the Peras network protocols are not announced.
1. The operator-facing `PerasEnabled` setting must implement this _disable
   everything_ option behavior.
1. The divergence risk described in Context remains when Peras is disabled on
 a Peras-active network. This is acceptable: the setting is intended for a
 severe Peras failure, after which Peras should not be re-enabled without a
 code change. In this situation, a node with Peras disabled behaves much like a
 node running an earlier version without Peras.
