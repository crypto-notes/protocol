# ETH Commemorative Cryptonotes

WIP. Built on top of ERC-3525.

## Requirements:

- [ ] Shows different background on the commemorative cryptonotes according to the different face values, with the denomination in the below 5 ranges: (0, 0.1), [0.1, 1.0), [1.0, 10.0), [10.0, 20.0), [20.0, inf).

- [ ] The cryptonotes can be merged or split, and the backgrounds can be dynamically generated in SVG format based on the different denominations.

- [ ] The commemorative cryptonotes can be integrated with the Chainlink data feed to get the ETH price in USD and present the denomination of the note.

- [ ] If the current price of the note is higher than a certain average price, such as the five-day average, the background is green, otherwise, the background turns red.

## Install Dependencies

`yarn` or `npm install`

## Run tests

`yarn test` or `npm run test`


## Deploy

`yarn hardhat run scripts/deploy-cryptonotes.ts` or `npx hardhat run scripts/deploy-cryptonotes.ts`

## More

This project is Foundry compatible, you can write more tests in Solidity under the folder of `test/foundry` and run tests with the command `forge test -vvv`.
