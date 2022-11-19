//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {IERC3525Metadata} from "@cryptonotes/core/contracts/extensions/IERC3525Metadata.sol";

interface ICryptonotes is IERC3525Metadata {

  struct SlotDetail {
    string name;
    string description;
    string image;
    address underlying;
  }

  function mint(address onBehalfOf, SlotDetail memory slotDetail, uint256 value) external payable returns (bool);

  function topUp(address onBehalfOf, uint256 tokenId, uint256 value) external payable returns (bool);

  function merge(uint256 tokenId, uint256 targetTokenId) external;

  /**
   * @notice Splits an amount of value from one tokenId to another.
   *  Only authorised owner or operator can execute.
   *
   * @param fromTokenId The tokenId split from.
   * @param splitUnits The amount to be split from `fromTokenId` to `newTokenId`.
   */
  function split(
    uint256 fromTokenId,
    uint256 splitUnits
  ) external;

  /**
   * @notice Splits an amount of value from one tokenId to another.
   *  Only authorised owner or operator can execute.
   *
   * @param fromTokenId The tokenId split from.
   * @param to The recipient.
   * @param splitUnits The amount to be split from `fromTokenId` to a `newTokenId`.
   */
  function split(
    uint256 fromTokenId,
    address to,
    uint256 splitUnits
  ) external;

  /**
   * @notice Withdraws the value from a specific tokenId.
   *
   * @param tokenId The tokenId to be withdrawn.
   */
  function withdraw(uint256 tokenId) external;

  function getSlotDetail(uint256 slot) external view returns (SlotDetail memory);

  /**
   * @notice Returns the latest USD price from Chainlink Oracle.
   *
   */
  function getUsdPrice() external view returns (uint256);
}
