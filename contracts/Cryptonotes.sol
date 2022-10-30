//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {
  ERC3525Upgradeable,
  IERC3525Metadata
} from "@cryptonotes/core/contracts/ERC3525Upgradeable.sol";
import {StringConvertor} from "@cryptonotes/core/contracts/utils/StringConvertor.sol";
import {ICryptonotes} from "./ICryptonotes.sol";

/// @notice The implementation of the cryptonote demo.
contract Cryptonotes is ICryptonotes, OwnableUpgradeable, ERC3525Upgradeable, ReentrancyGuardUpgradeable {
  /* ========== error definitions ========== */

  error InsufficientFund();
  error InsufficientBalance();
  error ZeroValue();
  error NotAllowed();
  error NotAuthorised();
  error NotSameSlot();
  error NotSameOwnerOfBothTokenId();
  error TokenAlreadyExisted(uint256 tokenId);
  error ZeroAddress();

  using SafeCastUpgradeable for int256;
  using StringConvertor for uint256;

  /* ========== STATE VARIABLES ========== */

  AggregatorV3Interface internal priceFeed;
  uint80 private roundsBack;

  mapping(uint256 => SlotDetail) private _slotDetails;

  /* ========== EVENTS ========== */

  event Mint(
    address indexed owner,
    uint256 indexed tokenId,
    uint256 units
  );

  event Split(
    address indexed owner,
    uint256 indexed tokenId,
    uint256 newTokenId,
    uint256 splitUnits
  );

  event Merge(
    address indexed owner,
    uint256 indexed tokenId,
    uint256 indexed targetTokenId,
    uint256 mergeUnits
  );

  event TopUp(
    address indexed onBehalfOf,
    uint256 indexed tokenId,
    uint256 units
  );

  /* ========== MODIFIERS ========== */

  modifier onlyAuthorised(uint256 tokenId_) {
    if (!_isApprovedOrOwner(_msgSender(), tokenId_)) {
      revert NotAuthorised();
    }

    _;
  }

  /* ========== CONSTRUCTOR / INITIALIZER ========== */

  function initialize(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address priceFeedAddr,
    address metadataDescriptor
  ) public initializer {
    __ERC3525_init(name_, symbol_, decimals_);
    __ReentrancyGuard_init();
    priceFeed = AggregatorV3Interface(priceFeedAddr);
    _setMetadataDescriptor(metadataDescriptor);
  }

  /* ========== VIEWS ========== */

  function getEthUsdPrice() public view returns (uint256, uint256) {
    (uint80 roundId, int latestPrice,,,) = priceFeed.latestRoundData();
    
    uint256 totalPrice;
    for (uint i = 0; i < 6; i++) {
      uint80 historyRoundId = roundId - roundsBack;
      (uint80 id, int price,,,) = priceFeed.getRoundData(historyRoundId);
      totalPrice += price.toUint256();
      roundId = id;
    }

    return (latestPrice.toUint256(), totalPrice);
  }

  function getSlotDetail(uint256 slot_) public view returns (SlotDetail memory) {
    return _slotDetails[slot_];
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  /**
   * @notice Mints a new token with a certain amount of X tokens.
   *  NOTE: if the underlying asset in the slot detail is zero address, then see it as ETH if it's on Ethereum/Goerli
   *
   * @param slotDetail_ The slot detail.
   * @param value_ The amount of X token to be kept in the (tokenId - slot).
   */
  function mint(
    address onBehalfOf_,
    SlotDetail memory slotDetail_,
    uint256 value_
  ) external payable returns (bool) {
    _validating(slotDetail_.underlying, value_);
    
    uint256 slot = _getSlot(slotDetail_.underlying, slotDetail_.vestingType, slotDetail_.maturity, slotDetail_.term);

    _slotDetails[slot] = SlotDetail({
      name: slotDetail_.name,
      description: slotDetail_.description,
      image: slotDetail_.image,
      underlying: slotDetail_.underlying,
      vestingType: slotDetail_.vestingType,
      maturity: slotDetail_.maturity,
      term: slotDetail_.term
    });
    
    uint256 tokenId_ = _mintValue(onBehalfOf_, slot, value_);

    emit Mint(onBehalfOf_, tokenId_, value_);
    return true;
  }

  function topUp(address onBehalfOf_, uint256 tokenId_, uint256 value_) external payable returns (bool) {
    uint256 slot = slotOf(tokenId_);

    SlotDetail memory slotDetail_ = getSlotDetail(slot);
    _validating(slotDetail_.underlying, value_);
    
    _topupValue(onBehalfOf_, slot, tokenId_, value_);

    emit TopUp(onBehalfOf_, tokenId_, value_);
    return true;
  }

  /* ========== RESTRICTED FUNCTIONS ========== */

  /**
   * @notice Merges the value of two tokenIds.
   *  Only authorised owner or operator can execute.
   *
   * @param tokenId_ The tokenId to be merged from.
   * @param targetTokenId_ The tokenId to be used to receive the value.
   */
  function merge(
    uint256 tokenId_,
    uint256 targetTokenId_
  )
    external
    onlyAuthorised(tokenId_)
  {
    if (tokenId_ == targetTokenId_) {
      revert NotAllowed();
    }

    if (slotOf(tokenId_) != slotOf(targetTokenId_)) {
      revert NotSameSlot();
    }

    address owner = ownerOf(tokenId_);
    if (owner != ownerOf(targetTokenId_)) {
      revert NotSameOwnerOfBothTokenId();
    }

    uint256 mergeUnits = balanceOf(tokenId_);
    transferFrom(tokenId_, targetTokenId_, mergeUnits);
    _burn(tokenId_);

    emit Merge(owner, tokenId_, targetTokenId_, mergeUnits);
  }

  /**
   * @notice Splits an amount of value from one tokenId to another.
   *  Only authorised owner or operator can execute.
   *
   * @param fromTokenId_ The tokenId split from.
   * @param newTokenId_ The tokenId to be used as to receive the value, must be a non-used one.
   * @param splitUnits_ The amount to be split from `fromTokenId_` to `newTokenId_`.
   */
  function split(
    uint256 fromTokenId_,
    uint256 newTokenId_,
    uint256 splitUnits_
  )
    external
    onlyAuthorised(fromTokenId_)
  {
    if (_exists(newTokenId_)) {
      revert TokenAlreadyExisted(newTokenId_);
    }

    address owner = ownerOf(fromTokenId_);
    _mintValue(owner, slotOf(fromTokenId_), newTokenId_, 0);
    _transferValue(fromTokenId_, newTokenId_, splitUnits_);

    emit Split(owner, fromTokenId_, newTokenId_, splitUnits_);
  }

  /**
   * @notice Splits an amount of value from one tokenId to another.
   *  Only authorised owner or operator can execute.
   *
   * @param fromTokenId_ The tokenId split from.
   * @param splitUnits_ The amount to be split from `fromTokenId_` to `newTokenId_`.
   */
  function split(
    uint256 fromTokenId_,
    address to_,
    uint256 splitUnits_
  )
    external
    onlyAuthorised(fromTokenId_)
  {
    if (to_ == address(0)) {
      revert ZeroAddress();
    }

    if (splitUnits_ == 0) {
      revert ZeroValue();
    }

    uint256 newTokenId_ = transferFrom(fromTokenId_, to_, splitUnits_);

    emit Split(_msgSender(), fromTokenId_, newTokenId_, splitUnits_);
  }

  /**
   * @notice Withdraws the value from a specific tokenId.
   *
   * @param tokenId_ The tokenId to be withdrawn.
   */
  function withdraw(uint256 tokenId_) external nonReentrant onlyAuthorised(tokenId_) {
    uint256 slot = slotOf(tokenId_);
    SlotDetail memory sd = _slotDetails[slot];
    address asset = sd.underlying;
    
    if (asset == address(0)) {
      (
        bool sent,
        /** bytes memory data */
      ) = payable(_msgSender()).call{value: balanceOf(tokenId_)}("");
      require(sent, "Failed to send Ether");
    } else {
      IERC20Upgradeable(asset).transfer(_msgSender(), balanceOf(tokenId_));
    }

    _burn(tokenId_);
  }

  function setRoundsBack(uint80 roundsBack_) external onlyOwner {
    roundsBack = roundsBack_;
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  /**
  * @dev Generate the value of slot by utilizing keccak256 algorithm to calculate the hash 
  * value of multi properties.
  */
  function _getSlot(
    address underlying_,
    uint8 vestingType_,
    uint32 maturity_,
    uint32 term_
  ) internal pure virtual returns (uint256) {
    return 
      uint256(
        keccak256(
          abi.encodePacked(
            underlying_,
            vestingType_,
            maturity_,
            term_
          )
        )
      );
  }

  /**
   * @notice Validates the underlying asset and the value.
   *
   * @param underlying_ The underlying asset
   * @param value_ Value
   */
  function _validating(address underlying_, uint256 value_) internal {
    if (value_ == 0) {
      revert ZeroValue();
    }

    // if underlying is zero address then see the slot receives ETH (only if it's on Ethereum/Goerli)
    if (underlying_ == address(0)) {
      if (msg.value < value_) {
        revert InsufficientFund();
      }
    }

    if (underlying_ != address(0)) {
      if (msg.value > 0) { // just in case the user send ETH accidently
        revert NotAllowed();
      }

      if (IERC20Upgradeable(underlying_).balanceOf(_msgSender()) < value_) {
        revert InsufficientBalance();
      }
      if (IERC20Upgradeable(underlying_).allowance(_msgSender(), address(this)) < value_) {
        revert InsufficientFund();
      }
      
      IERC20Upgradeable(underlying_).transferFrom(_msgSender(), address(this), value_);
    }
  }

}
