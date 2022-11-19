//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "hardhat/console.sol";

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {Base64Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import {IERC3525MetadataDescriptor} from "@cryptonotes/core/contracts/periphery/interface/IERC3525MetadataDescriptor.sol";
import {StringConvertor} from "@cryptonotes/core/contracts/utils/StringConvertor.sol";
import {ICryptonotes} from "./ICryptonotes.sol";

interface IERC20 {
  function decimals() external view returns (uint8);
}

contract NotesMetadataDescriptor is IERC3525MetadataDescriptor {
  using StringConvertor for uint256;
  using StringConvertor for bytes;

  function constructContractURI() external view override returns (string memory) {
    ICryptonotes note = ICryptonotes(msg.sender);
    return 
      string(
        abi.encodePacked(
          /* solhint-disable */
          'data:application/json;base64,',
          Base64Upgradeable.encode(
            abi.encodePacked(
              '{"name":"', 
              note.name(),
              '","description":"',
              _contractDescription(),
              '","image":"',
              _contractImage(),
              '","valueDecimals":"', 
              uint256(note.valueDecimals()).toString(),
              '"}'
            )
          )
          /* solhint-enable */
        )
      );
  }

  function constructSlotURI(uint256 slot_) external view override returns (string memory) {
    return
      string(
        abi.encodePacked(
          /* solhint-disable */
          'data:application/json;base64,',
          Base64Upgradeable.encode(
            abi.encodePacked(
              '{"name":"', 
              _slotName(slot_),
              '","description":"',
              _slotDescription(slot_),
              '","image":"',
              _slotImage(slot_),
              '","properties":',
              _slotProperties(slot_),
              '}'
            )
          )
          /* solhint-enable */
        )
      );
  }

  function constructTokenURI(uint256 tokenId_) external view override returns (string memory) {
    ICryptonotes note = ICryptonotes(msg.sender);
    return 
      string(
        abi.encodePacked(
          "data:application/json;base64,",
          Base64Upgradeable.encode(
            abi.encodePacked(
              /* solhint-disable */
              '{"name":"',
              _tokenName(tokenId_),
              '","description":"',
              _tokenDescription(tokenId_),
              '","image":"data:image/svg+xml;base64,',
              _tokenImage(tokenId_),
              '","balance":"',
              note.balanceOf(tokenId_).toString(),
              '","slot":"',
              note.slotOf(tokenId_).toString(),
              '","properties":',
              _tokenProperties(tokenId_),
              "}"
              /* solhint-enable */
            )
          )
        )
      );
  }

  function _slotDetail(uint256 slot_) private view returns (ICryptonotes.SlotDetail memory) {
    ICryptonotes note = ICryptonotes(msg.sender);
    return note.getSlotDetail(slot_);
  }

  function _slotName(uint256 slot_) internal view returns (string memory) {
    return _slotDetail(slot_).name;
  }

  function _slotDescription(uint256 slot_) internal view returns (string memory) {
    return _slotDetail(slot_).description;
  }

  function _slotImage(uint256 slot_) internal view returns (bytes memory) {
    return abi.encodePacked(_slotDetail(slot_).image);
  }

  function _slotProperties(uint256 slot_) internal view returns (string memory) {
    return 
      string(
        /* solhint-disable */
        abi.encodePacked(
          "[",
            abi.encodePacked(
              '{"name":"underlying",',
              '"description":"Address of the underlying token locked in this contract.",',
              '"value":"',
                  StringsUpgradeable.toHexString(_slotDetail(slot_).underlying),
              '",',
              '"order":1,',
              '"display_type":"string"},'
            ),
          "]"
        )
        /* solhint-enable */
      );
  }

  function _slotOf(uint256 tokenId_) private view returns (uint256) {
    ICryptonotes note = ICryptonotes(msg.sender);
    return note.slotOf(tokenId_);
  }

  function _tokenName(uint256 tokenId_) internal view returns (string memory) {
    // solhint-disable-next-line
    return 
      string(
        abi.encodePacked(
          _slotName(_slotOf(tokenId_)), 
          " #", tokenId_.toString()
        )
      );
  }

  function _tokenDescription(uint256 tokenId_) internal view returns (string memory) {
    uint256 slot = _slotOf(tokenId_);
    return _slotDetail(slot).description;
  }

  function _tokenImage(uint256 tokenId_) internal view returns (bytes memory) {
    return abi.encodePacked(_makeupSVG(tokenId_));
  }

  function _tokenProperties(uint256 tokenId_) internal view returns (string memory) {
    uint256 slot = _slotOf(tokenId_);
    
    return 
      string(
        abi.encodePacked(
          /* solhint-disable */
          '{"underlying":"',
            StringsUpgradeable.toHexString(_slotDetail(slot).underlying),
          '"}'
          /* solhint-enable */
        )
      );
  }

  function _contractDescription() internal pure returns (string memory) {
    return "";
  }

  function _contractImage() internal pure returns (bytes memory) {
    return "";
  }

  function _makeupSVG(uint256 tokenId_) private view returns (string memory) {
    ICryptonotes note = ICryptonotes(msg.sender);
    uint256 balance = note.balanceOf(tokenId_);
    uint256 usdPrice = note.getUsdPrice();
    uint8 decimals = _getDecimals(note, tokenId_);
    console.log("decimals:", decimals);
    uint256 balanceInUsd = balance * usdPrice;
    uint256 slot = _slotOf(tokenId_);

    return Base64Upgradeable.encode(
      abi.encodePacked(
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
          _makeupBackgroundImg(slot),
          _makeupCurrencyLogo(),
          _makeupBalance(balance, decimals),
          _makeupBalanceInUsd(balanceInUsd, decimals),
        '</svg>'
      )
    );
  }

  function _makeupBackgroundImg(uint256 slot_) private view returns (string memory) {
    return string(
      abi.encodePacked(
        '<image width="310" height="150" xlink:href="',
          _slotDetail(slot_).image,
        '"/>'
      )
    );
  }

  function _makeupCurrencyLogo() private pure returns (string memory) {
    return string(
      abi.encodePacked(
        '<g transform="matrix(1, 0, 0, 1, 80, 35)">',
          '<path class="st0" d="M29,10.2c-0.7-0.4-1.6-0.4-2.4,0L21,13.5l-3.8,2.1l-5.5,3.3c-0.7,0.4-1.6,0.4-2.4,0L5,16.3 c-0.7-0.4-1.2-1.2-1.2-2.1v-5c0-0.8,0.4-1.6,1.2-2.1l4.3-2.5c0.7-0.4,1.6-0.4,2.4,0L16,7.2c0.7,0.4,1.2,1.2,1.2,2.1v3.3l3.8-2.2V7 c0-0.8-0.4-1.6-1.2-2.1l-8-4.7c-0.7-0.4-1.6-0.4-2.4,0L1.2,5C0.4,5.4,0,6.2,0,7v9.4c0,0.8,0.4,1.6,1.2,2.1l8.1,4.7 c0.7,0.4,1.6,0.4,2.4,0l5.5-3.2l3.8-2.2l5.5-3.2c0.7-0.4,1.6-0.4,2.4,0l4.3,2.5c0.7,0.4,1.2,1.2,1.2,2.1v5c0,0.8-0.4,1.6-1.2,2.1 L29,28.8c-0.7,0.4-1.6,0.4-2.4,0l-4.3-2.5c-0.7-0.4-1.2-1.2-1.2-2.1V21l-3.8,2.2v3.3c0,0.8,0.4,1.6,1.2,2.1l8.1,4.7 c0.7,0.4,1.6,0.4,2.4,0l8.1-4.7c0.7-0.4,1.2-1.2,1.2-2.1V17c0-0.8-0.4-1.6-1.2-2.1L29,10.2z" style="fill: rgb(130, 71, 229);"/>',
        '</g>'
      )
    );
  }

  function _makeupBalance(uint256 balance_, uint8 decimals_) private pure returns (string memory) {
    return string(
      abi.encodePacked(
        '<g transform="translate(202,58)">',
          '<rect width="100" height="40" fill="none"/>',
          '<text x="50" y="21" alignment-baseline="middle" font-size="12" text-anchor="middle">',
            _formatValue(balance_, decimals_),
          '</text>',
        '</g>'
      )
    );
  }

  function _makeupBalanceInUsd(uint256 balanceInUsd_, uint8 decimals_) private pure returns (string memory) {
    return string(
      abi.encodePacked(
        '<g transform="translate(23,80)">',
          '<rect width="150" height="20" fill="none"/>',
          '<text x="75" y="10" alignment-baseline="middle" font-size="12" text-anchor="middle">$',
            _formatValue(balanceInUsd_, decimals_ + 8),
          '</text>',
        '</g>'
      )
    );
  }

  function _getDecimals(ICryptonotes note, uint256 tokenId_) private view returns (uint8 decimals) {
    decimals = 18;
    uint256 slot = note.slotOf(tokenId_);
    ICryptonotes.SlotDetail memory sd = note.getSlotDetail(slot);
    if (sd.underlying != address(0)) {
      decimals = IERC20(sd.underlying).decimals();
    }
  }

  function _formatValue(uint256 value, uint8 decimals) private pure returns (bytes memory) {
    return value.uint2decimal(decimals).trim(decimals - 2).addThousandsSeparator();
  }

}
