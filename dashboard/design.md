# Peras dashboard design notes

## Peras parameters

Here are the parameters that can be configured in the dashboard:

* `B`: Boost, in block weight
    The extra chain weight that a certificate gives to a block.
* `U`: Round length, in slots
    The duration of each voting round.
* `A`: Certificate expiration, in slots
    The maximum age for a certificate to be included in a block.
* `R`: Chain ignorance, in rounds',
    The number of rounds for which to ignore certificates after entering a cool-down period.
* `K`: Cooldown period, in rounds
    The minimum number of rounds to wait before voting again after a cool-down period starts.
* `L`: Block selection offset, in slots
    The minimum age of a candidate block for being voted upon.
* `n`: Mean committee size, in nodes
    The number of members on the voting committee.
* `quorum`: Quorum threshold
    The percentage of votes, relative to the mean committee size, required to create a certificate.
* `f`: Active slot coefficient, in blocks/slot
    The probability that a party will be the slot leader for a particular slot.
* `k`: security parameter, in blocks
    The limit on the number of blocks to reach a common prefix.

## Derived parameters formulas

The value for some parameters can be derived from other ones.

Those formulas are inspired this [previous dashboard](http://peras.cardano-scaling.org/dashboard/index.html)
The source code is [here](https://github.com/input-output-hk/peras-design/blob/main/peras-dashboard/src/controller.js)

* `A = 90 * B / f`
* `R = A / U`
* `K = (2160 + 90 * B) / f / U`
* `k = 2160 + 90 * B`

## Stats formulas

TODO
