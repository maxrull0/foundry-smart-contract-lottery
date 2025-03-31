## Raffle Contract

## Description

This is my self-written Raffle contract written under guidance of PatrickAlphaC in the Foundry Fundamentals course (https://updraft.cyfrin.io/courses/foundry/smart-contract-lottery/introduction).

It is a raffle where players can enter the raffle with a minimum fee to be paid.

Once the interval time has passed, a Chainlink Automation node will check if the winner can be picked and if true, the upkeep is performed.

During that, a Chainlink VRF request for random words is sent and fulfilled with a callback to the function that uses the provided randomness to randomly pick a winner of the entered players array.

Then the raffle is reset and starts again.

Used tech:
- Chainlink VRF v2.5
- Chainlink Automation (Keepers)
- cyfrin DevOps to use last deployed contract during deployment and upgrades (not implemented)
- VRF mocks

## Setup

Use the makefile to build, test, and deploy on sepolia.
Also contains install command to install dependencies.

### Coverage

To create a coverage report, run the following after you installed lcov and foundry.
```shell
forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage -ignore-errors inconsistent --ignore-errors corrupt
```
