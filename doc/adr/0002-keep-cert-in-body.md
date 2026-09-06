# 2. On-chain structures

Date: 2026-09-04

## Status

Draft

## Context


1. 

In order to keep the information about the last succesful vote we need to keep a proof of that.

Alternatives:
1. Keep a raw number of the successful Peras round.
2. Keep a certificate that contains last successful round.

For the blockchain it is important that everything that is required for the verification is contained in the chain itself.
Solution that keeps just a number, despite being efficient lacks the information what is needed to build a proof of the number,
because all Peras votes are off-chain data.


2.

Size of the header is limited with Leios using headers for keeping information it's quite hard to predict and
build restrict size of the header in such a way that will fit both Peras and Leios, especially given the timeframe that we have.


## Decision

Keep certificate on-chain instead of just a number.

Keep certificate in block body.


## Consequences

Keeping certificate in the body creates a potential architecture problem, ledger is responsible for the validation of the 
block body. But the peras protocol is a consensus level protocol and ledger should be unaware of those. With this decision
we break an abstraction between the components. Either ledger becomes aware of Peras by any mean, that will require ledger
to contain consensus logic or use callbacks, or ledger do not validate all the logic. If in the future we will consider
keeping Peras certificates in the header it will lead to a very substantial refactoring.
