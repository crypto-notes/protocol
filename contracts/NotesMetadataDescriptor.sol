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

  function _slotName(uint256 slot_) internal view returns (string memory) {
    ICryptonotes note = ICryptonotes(msg.sender);
    ICryptonotes.SlotDetail memory slotDetail = note.getSlotDetail(slot_);
    return slotDetail.name;
  }

  function _slotDescription(uint256 slot_) internal view returns (string memory) {
    ICryptonotes note = ICryptonotes(msg.sender);
    ICryptonotes.SlotDetail memory slotDetail = note.getSlotDetail(slot_);
    return slotDetail.description;
  }

  function _slotImage(uint256 slot_) internal view returns (bytes memory) {
    ICryptonotes note = ICryptonotes(msg.sender);
    ICryptonotes.SlotDetail memory slotDetail = note.getSlotDetail(slot_);

    return abi.encodePacked(slotDetail.image);
  }

  function _slotProperties(uint256 slot_) internal view returns (string memory) {
    ICryptonotes note = ICryptonotes(msg.sender);
    ICryptonotes.SlotDetail memory slotDetail = note.getSlotDetail(slot_);

    return 
      string(
        /* solhint-disable */
        abi.encodePacked(
          "[",
          abi.encodePacked(
            '{"name":"underlying",',
            '"description":"Address of the underlying token locked in this contract.",',
            '"value":"',
                StringsUpgradeable.toHexString(slotDetail.underlying),
            '",',
            '"order":1,',
            '"display_type":"string"},'
          ),
          "]"
        )
        /* solhint-enable */
      );
  }

  function _tokenName(uint256 tokenId_) internal view returns (string memory) {
    ICryptonotes note = ICryptonotes(msg.sender);
    uint256 slot = note.slotOf(tokenId_);
    // solhint-disable-next-line
    return 
      string(
        abi.encodePacked(
          _slotName(slot), 
          " #", tokenId_.toString()
        )
      );
  }

  function _tokenDescription(uint256 tokenId_) internal view returns (string memory) {
    ICryptonotes note = ICryptonotes(msg.sender);
    uint256 slot = note.slotOf(tokenId_);
    ICryptonotes.SlotDetail memory sd = note.getSlotDetail(slot);
    return sd.description;
  }

  function _tokenImage(uint256 tokenId_) internal view returns (bytes memory) {
    return abi.encodePacked(_makeupSVG(tokenId_));
  }

  function _tokenProperties(uint256 tokenId_) internal view returns (string memory) {
    ICryptonotes notes = ICryptonotes(msg.sender);
    uint256 slot = notes.slotOf(tokenId_);
    ICryptonotes.SlotDetail memory slotDetail = notes.getSlotDetail(slot);
    
    return 
      string(
        abi.encodePacked(
          /* solhint-disable */
          '{"underlying":"',
          StringsUpgradeable.toHexString(slotDetail.underlying),
          '}'
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
    (uint256 latestPrice, uint256 totalPrice) = note.getEthUsdPrice();

    uint8 decimals = _getDecimals(note, tokenId_);
    console.log("decimals:", decimals);

    uint256 twap = (totalPrice * (10 ** decimals)) / 5;

    uint256 balanceInUsd = balance * latestPrice;
    uint256 twapInUsd = balance * twap;

    return Base64Upgradeable.encode(
      abi.encodePacked(
        _makeupHeaderAndDefs(balanceInUsd, twapInUsd),
        _makeupCircles(balance, decimals),
        _makeupPaths(_getCircleColor(balance, decimals)),
        _makeupTexts(balance, balanceInUsd, decimals),
        '</svg>'
      )
    );
  }

  function _makeupHeaderAndDefs(uint256 balanceInUsd_, uint256 twapInUsd_) private pure returns (string memory) {
    return string(
      abi.encodePacked(
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="500" height="230" viewBox="1.017 -19.491 500 230">',
          '<defs>',
            '<pattern id="pattern-0-0" patternTransform="matrix(1, 0, 0, 1, 217.516244, 83.242008)" xlink:href="#pattern-0"/>',
            '<pattern x="0" y="0" width="25" height="25" patternUnits="userSpaceOnUse" viewBox="0 0 100 100" id="pattern-0">',
              '<rect x="0" y="0" width="50" height="100" style="fill: ',
                balanceInUsd_ == twapInUsd_ ? "blue"
                  : balanceInUsd_ > twapInUsd_ ? "green" : "red",
              ';"/>',
            '</pattern>',
          '</defs>'
      )
    );
  }

  /// (0, 0.1), [0.1, 1.0), [1.0, 10.0), [10.0, 20.0), [20.0, inf)
  function _makeupCircles(uint256 balance_, uint8 decimals_) public pure returns (string memory) {
    return string(
      abi.encodePacked(
        '<circle cx="400" cy="170" r="11.691" style="fill: red;"/>',
        '<circle cx="400" cy="137" r="11.691" style="',
            balance_ >= 1 * (10 ** decimals_ / 10) ? "fill: orange" : "fill-opacity: 0; stroke: #b7bba9;",
        '"/>',
        '<circle cx="400" cy="104" r="11.691" style="',
            balance_ >= 1 * (10 ** decimals_) ? "fill: yellow" : "fill-opacity: 0; stroke: #b7bba9;",
        '"/>',
        '<circle cx="400" cy="71" r="11.691" style="',
            balance_ >= 10 * (10 ** decimals_) ? "fill: green" : "fill-opacity: 0; stroke: #b7bba9;",
        '"/>',
        '<circle cx="400" cy="38" r="11.691" style="',
            balance_ >= 20 * (10 ** decimals_) ? "fill: blue" : "fill-opacity: 0; stroke: #b7bba9;",
        '"/>'
      )
    );
  }

  function _makeupPaths(string memory color_) private pure returns (string memory) {
    return string(
      abi.encodePacked(
        '<path d="M 23.917 210.975 L 436.117 210.975 C 448.743 210.975 459.017 200.702 459.017 188.075 L 459.017 3.409 C 459.017 -9.217 448.743 -19.491 436.117 -19.491 L 23.917 -19.491 C 11.291 -19.491 1.017 -9.217 1.017 3.409 L 1.017 188.075 C 1.017 200.702 11.291 210.975 23.917 210.975 Z M 19.337 3.409 C 19.337 0.881 21.389 -1.171 23.917 -1.171 L 436.117 -1.171 C 438.645 -1.171 440.697 0.881 440.697 3.409 L 440.697 188.075 C 440.697 190.603 438.645 192.655 436.117 192.655 L 23.917 192.655 C 21.389 192.655 19.337 190.603 19.337 188.075 L 19.337 3.409 Z" style="stroke-miterlimit: 3; fill-rule: nonzero; fill-opacity: 0.84; fill: url(#pattern-0-0); paint-order: fill;"/>',
        '<path d="M 229.986 49.323 C 229.255 49.335 228.592 49.76 228.275 50.419 L 201.349 92.734 C 201.305 92.8 201.264 92.867 201.228 92.939 C 201.228 92.939 201.226 92.941 201.224 92.943 C 201.197 92.999 201.172 93.057 201.148 93.117 C 201.102 93.237 201.069 93.362 201.046 93.49 C 201.025 93.617 201.017 93.745 201.021 93.875 C 201.021 93.876 201.021 93.876 201.021 93.878 C 201.023 93.942 201.027 94.004 201.036 94.068 C 201.038 94.079 201.04 94.093 201.044 94.105 C 201.06 94.201 201.081 94.296 201.112 94.389 C 201.116 94.406 201.121 94.424 201.125 94.441 C 201.125 94.443 201.125 94.443 201.125 94.445 C 201.146 94.505 201.172 94.565 201.199 94.623 C 201.199 94.625 201.199 94.625 201.199 94.626 C 201.226 94.683 201.255 94.739 201.288 94.793 C 201.288 94.793 201.288 94.795 201.288 94.797 C 201.32 94.851 201.357 94.903 201.394 94.955 C 201.413 94.978 201.431 95 201.45 95.023 C 201.473 95.052 201.494 95.079 201.52 95.106 C 201.56 95.152 201.605 95.199 201.651 95.241 C 201.653 95.243 201.653 95.243 201.655 95.245 C 201.75 95.33 201.852 95.407 201.96 95.471 C 201.962 95.473 201.962 95.475 201.964 95.475 C 201.974 95.481 201.984 95.487 201.995 95.491 C 201.995 95.493 201.997 95.493 201.999 95.494 L 228.816 110.82 C 229.514 111.371 230.5 111.375 231.202 110.828 L 257.996 95.514 C 258.012 95.506 258.025 95.498 258.039 95.491 C 258.081 95.465 258.122 95.44 258.162 95.411 C 258.176 95.404 258.187 95.394 258.201 95.384 C 258.209 95.378 258.218 95.371 258.228 95.363 C 258.267 95.334 258.305 95.305 258.344 95.276 C 258.346 95.272 258.35 95.27 258.352 95.268 C 258.36 95.262 258.367 95.255 258.375 95.249 C 258.416 95.212 258.454 95.174 258.491 95.133 C 258.535 95.085 258.576 95.036 258.617 94.984 C 258.653 94.936 258.688 94.884 258.721 94.829 C 258.723 94.829 258.725 94.828 258.725 94.826 C 258.727 94.822 258.729 94.818 258.729 94.814 C 258.762 94.766 258.793 94.713 258.82 94.659 C 258.82 94.659 258.82 94.657 258.82 94.655 C 258.841 94.611 258.862 94.567 258.879 94.52 C 258.885 94.507 258.891 94.493 258.895 94.48 C 258.901 94.464 258.907 94.449 258.91 94.433 C 258.924 94.391 258.937 94.346 258.949 94.302 C 258.949 94.3 258.951 94.296 258.953 94.294 C 258.953 94.29 258.955 94.286 258.955 94.282 C 258.97 94.224 258.982 94.164 258.99 94.105 C 258.997 94.056 259.005 94.008 259.009 93.958 C 259.009 93.954 259.009 93.948 259.009 93.942 C 259.013 93.884 259.015 93.824 259.013 93.766 C 259.011 93.728 259.009 93.689 259.005 93.652 C 259.003 93.612 258.999 93.571 258.994 93.53 C 258.994 93.53 258.994 93.529 258.994 93.527 C 258.992 93.521 258.992 93.515 258.99 93.509 C 258.98 93.453 258.97 93.399 258.955 93.347 C 258.955 93.343 258.955 93.341 258.955 93.339 C 258.943 93.291 258.93 93.242 258.914 93.196 C 258.908 93.181 258.905 93.167 258.899 93.154 C 258.893 93.138 258.887 93.123 258.879 93.109 C 258.864 93.065 258.847 93.022 258.827 92.98 C 258.825 92.98 258.825 92.978 258.823 92.976 C 258.822 92.972 258.822 92.968 258.82 92.964 C 258.793 92.91 258.762 92.858 258.729 92.806 C 258.725 92.8 258.721 92.794 258.717 92.788 C 258.715 92.782 258.713 92.777 258.711 92.773 L 258.649 92.682 L 231.749 50.408 C 231.42 49.735 230.734 49.313 229.986 49.323 Z M 228.084 57.923 L 228.084 80.937 L 207.949 89.564 L 228.084 57.923 Z M 231.95 57.923 L 252.085 89.564 L 231.95 80.937 L 231.95 57.923 Z M 228.084 85.143 L 228.084 105.941 L 207.288 94.06 L 228.084 85.143 Z M 231.95 85.143 L 252.746 94.06 L 231.95 105.941 L 231.95 85.143 Z M 257.095 101.539 C 256.753 101.537 256.417 101.626 256.121 101.796 L 230.017 116.714 L 203.913 101.796 C 203.63 101.636 203.315 101.549 202.991 101.543 C 201.504 101.514 200.541 103.107 201.261 104.41 C 201.301 104.483 201.348 104.555 201.398 104.624 L 228.333 141.179 C 229.064 142.474 230.925 142.491 231.681 141.21 C 231.687 141.2 231.691 141.19 231.697 141.183 L 258.634 104.624 C 259.521 103.428 258.781 101.721 257.302 101.551 C 257.233 101.543 257.165 101.539 257.095 101.539 Z M 209.938 109.695 L 228.084 120.066 L 228.084 134.322 L 209.938 109.695 Z M 250.096 109.695 L 231.95 134.322 L 231.95 120.066 L 250.096 109.695 Z" style="fill: ', color_ ,';"/>'
      )
    );
  }

  function _makeupTexts(uint256 balance_, uint256 balanceInUsd_, uint8 decimals_) private view returns (string memory) {
    console.log("balanceInUsd_:", balanceInUsd_);

    return string(
      abi.encodePacked(
        '<text style="fill: #FFFFFF; font-family: &quot;Chalkboard SE&quot;; font-size: 18px; white-space: pre;" x="78.947" y="103.353">',
          _formatValue(balance_, decimals_),
        '</text>',
        '<text style="fill: #FFFFFF; font-family: &quot;Chalkboard SE&quot;; font-size: 12.9px; white-space: pre;" x="211.405" y="170.351"> $',
          _formatValue(balanceInUsd_, decimals_ + 8), // decimal: 18 (Ether) + 8 (USD in Chainlink Oracle)
        '</text>',
        '<text style="fill: #FFFFFF; font-family: &quot;Chalkboard SE&quot;; font-size: 18px; white-space: pre;" x="320.601" y="103.353">',
          _formatValue(balance_, decimals_),
        '</text>'
      )
    );
  }

  /// (0, 0.1), [0.1, 1.0), [1.0, 10.0), [10.0, 20.0), [20.0, inf)
  function _getCircleColor(uint256 balance_, uint8 decimals_) private pure returns (string memory) {
    return (
      balance_ >= 20 * (10 ** decimals_) ? "blue" // [20.0, inf)
      : balance_ >= 10 * (10 ** decimals_) ? "green" // [10.0, 20.0)
      : balance_ >= 1 * (10 ** decimals_) ? "yellow" // [1.0, 10.0)
      : balance_ >= 1 * (10 ** decimals_ / 10) ? "orange" // [0.1, 1.0)
      : "red" // (0, 0.1)
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
