# *Pre-alpha* Peras

## The trade-off in pre-alpha Peras

*Pre-alpha* Peras is characterized by a trade-off between the following two desiderata:

 - **Small latency until blocks can be boosted and hence benefit from faster settlement.**

   Peras only enables improved settlement guarantees for a block if that block (or a descendant) is boosted due to a Peras certificate. One important Peras protocol parameter is the *block selection offset* `L`, aka `perasBlockMinSlots`. Honest nodes will only ever vote for blocks at the beginning of a Peras round that are least `perasBlockMinSlots` old. Therefore, for this purpose, a small value is desirable.

   For example, if `perasBlockMinSlots = 300`, then a block only even has a chance to benefit from a boost after `300 slots = 5 minutes`, whereas for `perasBlockMinSlots = 60`, the block can already be boosted after a minute.

 - **Resilience against weak attackers trying to force Peras into a cooldown.**

   When a Peras round is unsuccessful, i.e. did not result in a certificate, Peras enters a lengthy cooldown period (likely >1 day[^long-cooldown]) during which honest nodes do not vote and therefore Peras is effectively disabled, returning to Praos temporarily.

   [^long-cooldown]: See [appendix A.2.1 in the Peras report](https://tweag.github.io/cardano-peras/peras-design.pdf#section.A.2) for an explanation why cooldown periods are this long.

   Strong attackers with at least 25% stake can trivially disable Peras for as long as they control this stake, which is by design: Peras is about improving settlement guarantees *optimistically*.

   However, in pre-alpha Peras, weaker adversaries (think <25% stake) can *also* disable Peras with a given probability, depending on their stake. This probability can be decreased by increasing the `perasBlockMinSlots` parameter.

Briefly: In pre-alpha Peras, small values for `perasBlockMinSlots` are desirable when there is no (or only an extremely weak) adversary, but they lead to higher probabilities that weak adversaries can force Peras into cooldown period, decreasing the benefits of Peras.

For a deployment of pre-alpha Peras, it is crucial to make an informed decision on the value of `perasBlockMinSlots`. This parameter can be subject to on-chain governance, so it is possible to change it after the fact. For example, it could be set to a relatively small value in the beginning (say `60` slots), but still be increased later given certain adversarial activity.

For preliminary calculations of concrete probabilities in this trade-off, see [appendix A.1.2 in the Peras report](https://tweag.github.io/cardano-peras/peras-design.pdf#section.A.1), in particular figure A.1.

## Pre-agreement

*Pre-agreement* is an enrichment to Peras enabling us to resolve the trade-off in the following way. In pre-alpha Peras, rounds can only either result in a boost for a block, or fail, in which case a cooldown is triggered. Pre-agreement enables a third possibility: A round does not boost a block, but it also does not trigger a cooldown. More specifically, weak adversaries (<25%) can not cause cooldowns anymore, except for a very small probability independent of `perasBlockMinSlots`.

Under the hood, pre-agreement consists of running an (iterated) binary Byzantine Agreement protocol, see https://www.youtube.com/watch?v=HRJzwoArqg4&t=1055s for an explanation.

The downside of pre-agreement is that it makes the protocol more complex, albeit in a confined way because it only affects what to vote for, and increases the bandwidth consumed by Peras even when there isn't any attacker, potentially even requiring an extension of the round length (the details have not yet been analyzed, so no concrete numbers).

There is not yet any schedule for implementing pre-agreement.
