//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

contract PriceFeed {
  function latestRoundData() external pure returns(uint80, int, uint, uint, uint80) {
    return (0, 162559000000, 0, 0, 0);
  }

  function getRoundData(uint80 roundId_) external pure returns(uint80, int, uint, uint, uint80) {
    roundId_;
    return (0, 122559000000, 0, 0, 0);
  }
}
