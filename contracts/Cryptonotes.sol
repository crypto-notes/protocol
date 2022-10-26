//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import {
  ERC3525Upgradeable,
  IERC3525Metadata,
  Base64Upgradeable
} from "@cryptonotes/core/contracts/ERC3525Upgradeable.sol";
import {StringConvertor} from "@cryptonotes/core/contracts/utils/StringConvertor.sol";

/// @notice The implementation of the cryptonotes demo.
contract Cryptonotes is ERC3525Upgradeable, AutomationCompatible, ReentrancyGuardUpgradeable {
  /* ========== error definitions ========== */

  error InsufficientFund();
  error InsufficientBalance();
  error ZeroValue();
  error NotAllowed();
  error NotAuthorised();
  error NotSameSlot();
  error NotSameOwnerOfBothTokenId();
  error TokenAlreadyExisted(uint256 tokenId);

  using StringConvertor for uint256;

  struct SlotDetail {
    string name;
    string description;
    string image;
    address underlying;
    uint8 vestingType;
    uint32 maturity;
    uint32 term;
  }

  /* ========== STATE VARIABLES ========== */

  AggregatorV3Interface internal priceFeed;

  mapping(uint256 => SlotDetail) private _slotDetails;

  /* ========== EVENTS ========== */

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
    address priceFeedAddr
  ) public initializer {
    __ERC3525_init(name_, symbol_, decimals_);
    __ReentrancyGuard_init();
    priceFeed = AggregatorV3Interface(priceFeedAddr);
  }

  /* ========== VIEWS ========== */

  /**
   * Returns the latest price
   */
  function getLatestPrice() public view returns (int) {
    (
      /*uint80 roundID*/,
      int price,
      /*uint startedAt*/,
      /*uint timeStamp*/,
      /*uint80 answeredInRound*/
    ) = priceFeed.latestRoundData();
    return price;
  }

  function getSlotDetail(uint256 slot_) public view returns (SlotDetail memory) {
    return _slotDetails[slot_];
  }

  function contractURI() public view override returns (string memory) {
    return 
      string(
        abi.encodePacked(
          /* solhint-disable */
          'data:application/json;base64,',
          Base64Upgradeable.encode(
            abi.encodePacked(
              '{"name":"', 
              name(),
              '","description":"',
              _contractDescription(),
              '","image":"',
              _contractImage(),
              '","valueDecimals":"', 
              uint256(valueDecimals()).toString(),
              '"}'
            )
          )
          /* solhint-enable */
        )
      );
  }

  function slotURI(uint256 slot_) public view override returns (string memory) {
    return
      string(
        abi.encodePacked(
          /* solhint-disable */
          'data:application/json;base64,',
          Base64Upgradeable.encode(
            abi.encodePacked(
              '{"name":"', 
              _slotDetails[slot_].name,
              '","description":"',
              _slotDetails[slot_].description,
              '","image":"',
              _slotDetails[slot_].image,
              '","properties":',
              _slotProperties(slot_),
              '}'
            )
          )
          /* solhint-enable */
        )
      );
  }

  function tokenURI(uint256 tokenId_) public view override returns (string memory) {
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
              '","image":"',
              _tokenImage(tokenId_),
              '","balance":"',
              balanceOf(tokenId_).toString(),
              '","slot":"',
              slotOf(tokenId_).toString(),
              '","properties":',
              _tokenProperties(tokenId_),
              "}"
              /* solhint-enable */
            )
          )
        )
      );
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
    SlotDetail memory slotDetail_,
    uint256 value_
  ) external payable {
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
    
    _mintValue(_msgSender(), slot, value_);
  }

  /**
   * @notice Withdraws the value from a specific tokenId.
   *
   * @param tokenId_ The tokenId to be withdrawn.
   */
  function withdraw(uint256 tokenId_) external nonReentrant {
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

  function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
    // TODO To be implemented
  }

  function performUpkeep(bytes calldata /* performData */) external override {
    // TODO To be implemented
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
   * @param newTokenId_ The tokenId to be used as to receive the value.
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
    _mintValue(owner, newTokenId_, slotOf(fromTokenId_), splitUnits_);

    emit Split(owner, fromTokenId_, newTokenId_, splitUnits_);
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

      if (IERC20Upgradeable(underlying_).balanceOf(msg.sender) < value_) {
        revert InsufficientBalance();
      }
      if (IERC20Upgradeable(underlying_).allowance(_msgSender(), address(this)) < value_) {
        revert InsufficientFund();
      }
      
      IERC20Upgradeable(underlying_).transferFrom(_msgSender(), address(this), value_);
    }
  }

  function _contractDescription() internal view virtual returns (string memory) {
    return "";
  }

  function _contractImage() internal view virtual returns (bytes memory) {
    return "";
  }

  function _slotProperties(uint256 slot_) internal view returns (string memory) {
    SlotDetail memory slotDetail = _slotDetails[slot_];
    return 
      string(
        /* solhint-disable */
        abi.encodePacked(
          "[",
          abi.encodePacked(
            '{"name":"underlying",',
            '"description":"Address of the underlying token locked in this contract.",',
            '"value":"',
                StringsUpgradeable.toHexString(uint256(uint160(slotDetail.underlying))),
            '",',
            '"order":1,',
            '"display_type":"string"},'
          ),
          abi.encodePacked(
            '{"name":"vesting_type",',
            '"description":"Vesting type that represents the releasing mode of underlying assets.",',
            '"value":',
                uint256(slotDetail.vestingType).toString(),
            ",",
            '"order":2,',
            '"display_type":"number"},'
          ),
          abi.encodePacked(
            '{"name":"maturity",',
            '"description":"Maturity that all underlying assets would be completely released.",',
            '"value":',
                uint256(slotDetail.maturity).toString(),
            ",",
            '"order":3,',
            '"display_type":"date"},'
          ),
          abi.encodePacked(
            '{"name":"term",',
            '"description":"The length of the locking period (in seconds)",',
            '"value":',
                uint256(slotDetail.term).toString(),
            ",",
            '"order":4,',
            '"display_type":"number"}'
          ),
          "]"
        )
        /* solhint-enable */
      );
  }

  function _tokenName(uint256 tokenId_) internal view virtual returns (string memory) {
    // solhint-disable-next-line
    return 
      string(
        abi.encodePacked(
          IERC3525Metadata(msg.sender).name(), 
          " #", tokenId_.toString()
        )
      );
  }

  function _tokenDescription(uint256 tokenId_) internal view virtual returns (string memory) {
    tokenId_;
    return "";
  }


  function _tokenImage(uint256 tokenId_) internal view virtual returns (bytes memory) {
    tokenId_;
    return "";
  }

  function _tokenProperties(uint256 tokenId_) internal view returns (string memory) {
    uint256 slot = slotOf(tokenId_);
    SlotDetail storage slotDetail = _slotDetails[slot];
    
    return 
      string(
        abi.encodePacked(
          /* solhint-disable */
          '{"underlying":"',
          StringsUpgradeable.toHexString(uint256(uint160(slotDetail.underlying))),
          '","vesting_type":"',
          uint256(slotDetail.vestingType).toString(),
          '","maturity":',
          uint256(slotDetail.maturity).toString(),
          ',"term":',
          uint256(slotDetail.term).toString(),
          '}'
          /* solhint-enable */
        )
      );
  }

}
