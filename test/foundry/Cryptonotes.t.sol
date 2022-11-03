// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import {NotesMetadataDescriptor} from "../../contracts/NotesMetadataDescriptor.sol";
import {Cryptonotes, SafeCastUpgradeable} from "../../contracts/Cryptonotes.sol";
import {MockV3Aggregator} from "../../contracts/mock/MockV3Aggregator.sol";

contract CryptonotesTest is Test {
  using SafeCastUpgradeable for int256;

  uint8 public constant DECIMALS = 18;
  int256 public constant INITIAL_ANSWER = 1 * 10**18;
  Cryptonotes public cryptonotes;
  MockV3Aggregator public mockV3Aggregator;
  NotesMetadataDescriptor public metadataDescriptor;

  function setUp() public {
    mockV3Aggregator = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
    cryptonotes = new Cryptonotes();
    cryptonotes.initialize("Foundry Commemorative Cryptonotes", "FCC", 18, address(mockV3Aggregator), address(metadataDescriptor));
  }

  function testEthUsdReturnsStartingValue() public {
    // (uint256 price,) = cryptonotes.getEthUsdPrice();
    // assertTrue(price == INITIAL_ANSWER.toUint256());
  }

}
