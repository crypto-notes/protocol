// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "../../contracts/Cryptonotes.sol";

contract CryptonotesTest is Test {
  Cryptonotes public cryptonotes;

  function setUp() public {
    cryptonotes = new Cryptonotes();
    cryptonotes.initialize("Foundry Commemorative Cryptonotes", "FCC", 18, address(0), address(0));
  }

}
