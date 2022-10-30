# ETH Commemorative Cryptonotes

WIP. Built on top of ERC-3525.

## Requirements:

- [x] Shows different background on the commemorative cryptonotes according to the different face values, with the denomination in the below 5 ranges: (0, 0.1), [0.1, 1.0), [1.0, 10.0), [10.0, 20.0), [20.0, inf).

  > NOTES: The backgrounds should be dynamically generated in SVG format based on the different denominations, and you can see the preview sample SVGs in `svgs` folder

- [x] You can mint, split, merge, and withdraw from a cryptonote.

- [x] Integrate the commemorative cryptonotes with Chainlink data feed to get ETH price in USD and present it on the note.

- [x] If the current price of the note is higher than a certain average price, such as the five-day average, the background is green, otherwise, the background turns red.

## Install Dependencies

`yarn` or `npm install`

## Run tests

`yarn test` or `npm run test`

or

`yarn test:reports` or `npm run test:reports` to run the tests with deployment gas and contracts size reports

## Deploy

`yarn hardhat run scripts/deploy-cryptonotes.ts --network goerli` or `npx hardhat run scripts/deploy-cryptonotes.ts --network goerli`

## More

This project is Foundry compatible, you can write more tests in Solidity under the folder of `test/foundry` and run tests with the command `forge test -vvv`.
