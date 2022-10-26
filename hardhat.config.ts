import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import 'hardhat-contract-sizer';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  gasReporter: {
    enabled: process.env.ENABLE_GAS_REPORT !== undefined,
    currency: 'USD',
    // outputFile: 'gas-report.txt',
    // noColors: true,
    // coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },
};

export default config;

// Warning: Contract code size is 31600 bytes and exceeds 24576 bytes (a limit introduced in Spurious Dragon). This contract may not be deployable on Mainnet. Consider enabling the optimizer (with a low "runs" value!), turning off revert strings, or using libraries.
//   --> contracts/Cryptonotes.sol:11:1:
//    |
// 11 | contract Cryptonotes is ERC3525Upgradeable {
//    | ^ (Relevant source part starts here and spans across multiple lines).