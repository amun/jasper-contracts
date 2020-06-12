
// File: @openzeppelin/upgrades/contracts/Initializable.sol

pragma solidity >=0.4.24 <0.6.0;


/**
 * @title Initializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
contract Initializable {

  /**
   * @dev Indicates that the contract has been initialized.
   */
  bool private initialized;

  /**
   * @dev Indicates that the contract is in the process of being initialized.
   */
  bool private initializing;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");

    bool isTopLevelCall = !initializing;
    if (isTopLevelCall) {
      initializing = true;
      initialized = true;
    }

    _;

    if (isTopLevelCall) {
      initializing = false;
    }
  }

  /// @dev Returns true if and only if the function is running in the constructor
  function isConstructor() private view returns (bool) {
    // extcodesize checks the size of the code stored in an address, and
    // address returns the current address. Since the code is still not
    // deployed when running a constructor, any checks on its code size will
    // yield zero, making it an effective way to detect if a contract is
    // under construction or not.
    uint256 cs;
    assembly { cs := extcodesize(address) }
    return cs == 0;
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}

// File: solidity-util/lib/Strings.sol

pragma solidity ^0.5.0;

/**
 * Strings Library
 * 
 * In summary this is a simple library of string functions which make simple 
 * string operations less tedious in solidity.
 * 
 * Please be aware these functions can be quite gas heavy so use them only when
 * necessary not to clog the blockchain with expensive transactions.
 * 
 * @author James Lockhart <james@n3tw0rk.co.uk>
 */
library Strings {

    /**
     * Concat (High gas cost)
     * 
     * Appends two strings together and returns a new value
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string which will be the concatenated
     *              prefix
     * @param _value The value to be the concatenated suffix
     * @return string The resulting string from combinging the base and value
     */
    function concat(string memory _base, string memory _value)
        internal
        pure
        returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        assert(_valueBytes.length > 0);

        string memory _tmpValue = new string(_baseBytes.length +
            _valueBytes.length);
        bytes memory _newValue = bytes(_tmpValue);

        uint i;
        uint j;

        for (i = 0; i < _baseBytes.length; i++) {
            _newValue[j++] = _baseBytes[i];
        }

        for (i = 0; i < _valueBytes.length; i++) {
            _newValue[j++] = _valueBytes[i];
        }

        return string(_newValue);
    }

    /**
     * Index Of
     *
     * Locates and returns the position of a character within a string
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string acting as the haystack to be
     *              searched
     * @param _value The needle to search for, at present this is currently
     *               limited to one character
     * @return int The position of the needle starting from 0 and returning -1
     *             in the case of no matches found
     */
    function indexOf(string memory _base, string memory _value)
        internal
        pure
        returns (int) {
        return _indexOf(_base, _value, 0);
    }

    /**
     * Index Of
     *
     * Locates and returns the position of a character within a string starting
     * from a defined offset
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string acting as the haystack to be
     *              searched
     * @param _value The needle to search for, at present this is currently
     *               limited to one character
     * @param _offset The starting point to start searching from which can start
     *                from 0, but must not exceed the length of the string
     * @return int The position of the needle starting from 0 and returning -1
     *             in the case of no matches found
     */
    function _indexOf(string memory _base, string memory _value, uint _offset)
        internal
        pure
        returns (int) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        assert(_valueBytes.length == 1);

        for (uint i = _offset; i < _baseBytes.length; i++) {
            if (_baseBytes[i] == _valueBytes[0]) {
                return int(i);
            }
        }

        return -1;
    }

    /**
     * Length
     * 
     * Returns the length of the specified string
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string to be measured
     * @return uint The length of the passed string
     */
    function length(string memory _base)
        internal
        pure
        returns (uint) {
        bytes memory _baseBytes = bytes(_base);
        return _baseBytes.length;
    }

    /**
     * Sub String
     * 
     * Extracts the beginning part of a string based on the desired length
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string that will be used for 
     *              extracting the sub string from
     * @param _length The length of the sub string to be extracted from the base
     * @return string The extracted sub string
     */
    function substring(string memory _base, int _length)
        internal
        pure
        returns (string memory) {
        return _substring(_base, _length, 0);
    }

    /**
     * Sub String
     * 
     * Extracts the part of a string based on the desired length and offset. The
     * offset and length must not exceed the lenth of the base string.
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string that will be used for 
     *              extracting the sub string from
     * @param _length The length of the sub string to be extracted from the base
     * @param _offset The starting point to extract the sub string from
     * @return string The extracted sub string
     */
    function _substring(string memory _base, int _length, int _offset)
        internal
        pure
        returns (string memory) {
        bytes memory _baseBytes = bytes(_base);

        assert(uint(_offset + _length) <= _baseBytes.length);

        string memory _tmp = new string(uint(_length));
        bytes memory _tmpBytes = bytes(_tmp);

        uint j = 0;
        for (uint i = uint(_offset); i < uint(_offset + _length); i++) {
            _tmpBytes[j++] = _baseBytes[i];
        }

        return string(_tmpBytes);
    }

    /**
     * String Split (Very high gas cost)
     *
     * Splits a string into an array of strings based off the delimiter value.
     * Please note this can be quite a gas expensive function due to the use of
     * storage so only use if really required.
     *
     * @param _base When being used for a data type this is the extended object
     *               otherwise this is the string value to be split.
     * @param _value The delimiter to split the string on which must be a single
     *               character
     * @return string[] An array of values split based off the delimiter, but
     *                  do not container the delimiter.
     */
    function split(string memory _base, string memory _value)
        internal
        pure
        returns (string[] memory splitArr) {
        bytes memory _baseBytes = bytes(_base);

        uint _offset = 0;
        uint _splitsCount = 1;
        while (_offset < _baseBytes.length - 1) {
            int _limit = _indexOf(_base, _value, _offset);
            if (_limit == -1)
                break;
            else {
                _splitsCount++;
                _offset = uint(_limit) + 1;
            }
        }

        splitArr = new string[](_splitsCount);

        _offset = 0;
        _splitsCount = 0;
        while (_offset < _baseBytes.length - 1) {

            int _limit = _indexOf(_base, _value, _offset);
            if (_limit == - 1) {
                _limit = int(_baseBytes.length);
            }

            string memory _tmp = new string(uint(_limit) - _offset);
            bytes memory _tmpBytes = bytes(_tmp);

            uint j = 0;
            for (uint i = _offset; i < uint(_limit); i++) {
                _tmpBytes[j++] = _baseBytes[i];
            }
            _offset = uint(_limit) + 1;
            splitArr[_splitsCount++] = string(_tmpBytes);
        }
        return splitArr;
    }

    /**
     * Compare To
     * 
     * Compares the characters of two strings, to ensure that they have an 
     * identical footprint
     * 
     * @param _base When being used for a data type this is the extended object
     *               otherwise this is the string base to compare against
     * @param _value The string the base is being compared to
     * @return bool Simply notates if the two string have an equivalent
     */
    function compareTo(string memory _base, string memory _value)
        internal
        pure
        returns (bool) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        if (_baseBytes.length != _valueBytes.length) {
            return false;
        }

        for (uint i = 0; i < _baseBytes.length; i++) {
            if (_baseBytes[i] != _valueBytes[i]) {
                return false;
            }
        }

        return true;
    }

    /**
     * Compare To Ignore Case (High gas cost)
     * 
     * Compares the characters of two strings, converting them to the same case
     * where applicable to alphabetic characters to distinguish if the values
     * match.
     * 
     * @param _base When being used for a data type this is the extended object
     *               otherwise this is the string base to compare against
     * @param _value The string the base is being compared to
     * @return bool Simply notates if the two string have an equivalent value
     *              discarding case
     */
    function compareToIgnoreCase(string memory _base, string memory _value)
        internal
        pure
        returns (bool) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        if (_baseBytes.length != _valueBytes.length) {
            return false;
        }

        for (uint i = 0; i < _baseBytes.length; i++) {
            if (_baseBytes[i] != _valueBytes[i] &&
            _upper(_baseBytes[i]) != _upper(_valueBytes[i])) {
                return false;
            }
        }

        return true;
    }

    /**
     * Upper
     * 
     * Converts all the values of a string to their corresponding upper case
     * value.
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string base to convert to upper case
     * @return string 
     */
    function upper(string memory _base)
        internal
        pure
        returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        for (uint i = 0; i < _baseBytes.length; i++) {
            _baseBytes[i] = _upper(_baseBytes[i]);
        }
        return string(_baseBytes);
    }

    /**
     * Lower
     * 
     * Converts all the values of a string to their corresponding lower case
     * value.
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string base to convert to lower case
     * @return string 
     */
    function lower(string memory _base)
        internal
        pure
        returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        for (uint i = 0; i < _baseBytes.length; i++) {
            _baseBytes[i] = _lower(_baseBytes[i]);
        }
        return string(_baseBytes);
    }

    /**
     * Upper
     * 
     * Convert an alphabetic character to upper case and return the original
     * value when not alphabetic
     * 
     * @param _b1 The byte to be converted to upper case
     * @return bytes1 The converted value if the passed value was alphabetic
     *                and in a lower case otherwise returns the original value
     */
    function _upper(bytes1 _b1)
        private
        pure
        returns (bytes1) {

        if (_b1 >= 0x61 && _b1 <= 0x7A) {
            return bytes1(uint8(_b1) - 32);
        }

        return _b1;
    }

    /**
     * Lower
     * 
     * Convert an alphabetic character to lower case and return the original
     * value when not alphabetic
     * 
     * @param _b1 The byte to be converted to lower case
     * @return bytes1 The converted value if the passed value was alphabetic
     *                and in a upper case otherwise returns the original value
     */
    function _lower(bytes1 _b1)
        private
        pure
        returns (bytes1) {

        if (_b1 >= 0x41 && _b1 <= 0x5A) {
            return bytes1(uint8(_b1) + 32);
        }

        return _b1;
    }
}

// File: @openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol

pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: @openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol

pragma solidity ^0.5.0;


/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context is Initializable {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: @openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol

pragma solidity ^0.5.0;



/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be aplied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Initializable, Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function initialize(address sender) public initializer {
        _owner = sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * > Note: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    uint256[50] private ______gap;
}

// File: contracts/short-tokens/Abstract/InterfaceCashPool.sol

pragma solidity ^0.5.0;


interface InterfaceCashPool {
    function kycVerifier() external view returns (address);

    function moveTokenToPool(
        address _token,
        address whiteListedAddress,
        uint256 orderAmount
    ) external returns (bool);

    function moveTokenfromPool(
        address _token,
        address destinationAddress,
        uint256 orderAmount
    ) external returns (bool);
}

// File: contracts/short-tokens/Abstract/InterfaceKYCVerifier.sol

pragma solidity ^0.5.0;


interface InterfaceKYCVerifier {
    function isAddressWhitelisted(address) external view returns (bool);
}

// File: contracts/leverage-tokens/Abstract/InterfaceCalculator.sol

pragma solidity ^0.5.0;


interface InterfaceCalculator {

  function getTokensCreatedByCash(
    uint256 mintingPrice,
    uint256 cash,
    uint256 gasFee
  ) external view returns (uint256 tokensCreated) ;

  function getCashCreatedByTokens(
    uint256 burningPrice,
    uint256 elapsedTime,
    uint256 tokens,
    uint256 gasFee
  ) external view returns (uint256 stablecoinRedeemed);


  function calculateRebalanceValues(
    uint256 _tokenValueNetFees,
    uint256 _bestExecutionPrice,
    uint256 _markPrice,
    uint256 _notionalPreRebalance,
    uint256 _targetLeverage
  ) external view
      returns (
          uint256 notional,
          int256 changeInNotional,
          uint256 tokenValue
      );


  function removeCurrentMintingFeeFromCash(uint256 _cash)
    external view returns (uint256 cashAfterFee);

  function removeMintingFeeFromCash(
    uint256 _cash,
    uint256 _mintingFee,
    uint256 _minimumMintingFee
  ) external pure returns (uint256 cashAfterFee);

}

// File: contracts/short-tokens/Abstract/InterfaceERC20.sol

pragma solidity ^0.5.0;


interface InterfaceERC20 {
    function decimals() external view returns (uint8);
}

// File: contracts/short-tokens/Abstract/InterfaceInverseToken.sol

pragma solidity ^0.5.0;


interface InterfaceInverseToken {
    function mintTokens(address, uint256) external returns (bool);

    function burnTokens(address, uint256) external returns (bool);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// File: contracts/leverage-tokens/Abstract/InterfaceStorageLeverage.sol

pragma solidity ^0.5.0;


interface InterfaceStorageLeverage {
    function whitelistedAddresses(address) external view returns (bool);

    function isPaused() external view returns (bool);

    function isShutdown() external view returns (bool);

    function tokenSwapManager() external view returns (address);

    function bridge() external view returns (address);

    function managementFee() external view returns (uint256);

    function getExecutionPrice() external view returns (uint256);

    function getMarkPrice() external view returns (uint256);

    function getTokenValueAfterFees() external view returns (uint256);

    function getNotional() external view returns (uint256);

    function getTokenValue() external view returns (uint256);

    function getChangeInNotional() external view returns (int256);

    function getMintingFee(uint256 cash) external view returns (uint256);

    function minimumMintingFee() external view returns (uint256);

    function minRebalanceAmount() external view returns (uint8);

    function delayedRedemptionsByUser(address) external view returns (uint256);

    function setDelayedRedemptionsByUser(
        uint256 amountToRedeem,
        address whitelistedAddress
    ) external;

    function setOrderByUser(
        address whitelistedAddress,
        string calldata orderType,
        uint256 tokensGiven,
        uint256 tokensRecieved,
        uint256 mintingPrice,
        uint256 orderIndex,
        bool overwrite
    ) external;

    function setAccounting(
        uint256 _tokenValueNetFees,
        uint256 _bestExecutionPrice,
        uint256 _markPrice,
        uint256 _notional,
        int256 _changeInNotional,
        uint256 _tokenValue,
        uint256 _effectiveFundingRate
    ) external;

    function setAccountingForLastActivityDay(
        uint256 _tokenValueNetFees,
        uint256 _bestExecutionPrice,
        uint256 _markPrice,
        uint256 _notional,
        int256 _changeInNotional,
        uint256 _tokenValue,
        uint256 _effectiveFundingRate
    ) external;
}

// File: contracts/short-tokens/utils/Math.sol

/// Math.sol -- mixin for inline numerical wizardry

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.5.0;


library DSMath {

    // --- Unsigned Math ----
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }


    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }
    function imin(int x, int y) internal pure returns (int z) {
        return x <= y ? x : y;
    }
    function imax(int x, int y) internal pure returns (int z) {
        return x >= y ? x : y;
    }

    // --- Precise Math ---

    uint public constant WAD = 10 ** 18;
    uint public constant RAY = 10 ** 27;

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }
    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    function ray(uint _wad) internal pure returns (uint) {
        return mul(_wad, uint(10 ** 9));
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function rpow(uint x, uint n) internal pure returns (uint z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}

// File: contracts/leverage-tokens/TokenSwapLeverage.sol

pragma solidity ^0.5.0;













contract TokenSwapLeverage is Initializable, Ownable {
    using Strings for string;
    using SafeMath for uint256;

    address public inverseToken;

    InterfaceERC20 public erc20;
    InterfaceKYCVerifier public kycVerifier;
    InterfaceCashPool public cashPool;
    InterfaceStorageLeverage public persistentStorage;
    InterfaceCalculator public compositionCalculator;

    event SuccessfulOrder(
        string orderType,
        address whitelistedAddress,
        uint256 tokensGiven,
        uint256 tokensRecieved,
        address stablecoin,
        uint256 price
    );

    event RebalanceEvent(
        uint256 tokenValueNetFees,
        uint256 bestExecutionPrice,
        uint256 markPrice,
        uint256 notional,
        int256 changeInNotional,
        uint256 tokenValue,
        uint256 effectiveFundingRate
    );

    function initialize(
        address _owner,
        address _inverseToken,
        address _cashPool,
        address _storage,
        address _compositionCalculator
    ) public initializer {
        initialize(_owner);

        require(
            _owner != address(0) &&
                _inverseToken != address(0) &&
                _cashPool != address(0) &&
                _storage != address(0) &&
                _compositionCalculator != address(0),
            "addresses cannot be zero"
        );

        inverseToken = _inverseToken;

        cashPool = InterfaceCashPool(_cashPool);
        persistentStorage = InterfaceStorageLeverage(_storage);
        kycVerifier = InterfaceKYCVerifier(address(cashPool.kycVerifier()));
        compositionCalculator = InterfaceCalculator(_compositionCalculator);
    }

    //////////////// Create + Redeem Order Request ////////////////
    //////////////// Create: Recieve Inverse Token   ////////////////
    //////////////// Redeem: Recieve Stable Coin ////////////////

    function createOrder(
        bool success,
        uint256 tokensGiven,
        uint256 tokensRecieved,
        uint256 mintingPrice,
        address whitelistedAddress,
        address stablecoin,
        uint256 gasFee
    ) public onlyOwnerOrBridge() notPausedOrShutdown() returns (bool retVal) {
        // Require is Whitelisted
        require(
            kycVerifier.isAddressWhitelisted(whitelistedAddress),
            "only whitelisted address may place orders"
        );

        // Return Funds if Bridge Pass an Error
        if (!success) {
            transferTokenFromPool(
                stablecoin,
                whitelistedAddress,
                normalizeStablecoin(tokensGiven, stablecoin)
            );
            return false;
        }

        // Check Tokens Recieved with Composition Calculator
        uint256 _tokensRecieved = compositionCalculator.getTokensCreatedByCash(
            mintingPrice,
            tokensGiven,
            gasFee
        );
        require(
            _tokensRecieved == tokensRecieved,
            "tokens created must equal tokens recieved"
        );

        // Save Order to Storage and Lock Funds for 1 Hour
        persistentStorage.setOrderByUser(
            whitelistedAddress,
            "CREATE",
            tokensGiven,
            tokensRecieved,
            mintingPrice,
            0,
            false
        );

        // Write Successful Order to Log
        writeOrderResponse(
            "CREATE",
            whitelistedAddress,
            tokensGiven,
            tokensRecieved,
            stablecoin,
            mintingPrice
        );

        // Mint Tokens to Address
        InterfaceInverseToken token = InterfaceInverseToken(inverseToken);
        token.mintTokens(whitelistedAddress, tokensRecieved);

        return true;
    }

    function redeemOrder(
        bool success,
        uint256 tokensGiven,
        uint256 tokensRecieved,
        uint256 burningPrice,
        address whitelistedAddress,
        address stablecoin,
        uint256 gasFee,
        uint256 elapsedTime
    ) public onlyOwnerOrBridge() notPausedOrShutdown() returns (bool retVal) {
        // Require Whitelisted
        require(
            kycVerifier.isAddressWhitelisted(whitelistedAddress),
            "only whitelisted address may place orders"
        );

        // Return Funds if Bridge Pass an Error
        if (!success) {
            transferTokenFromPool(
                inverseToken,
                whitelistedAddress,
                tokensGiven
            );
            return false;
        }

        // Check Cash Recieved with Composition Calculator
        uint256 _tokensRecieved = compositionCalculator.getCashCreatedByTokens(
            burningPrice,
            elapsedTime,
            tokensGiven,
            gasFee
        );
        require(
            _tokensRecieved == tokensRecieved,
            "cash redeemed must equal tokens recieved"
        );

        // Save To Storage
        persistentStorage.setOrderByUser(
            whitelistedAddress,
            "REDEEM",
            tokensGiven,
            tokensRecieved,
            burningPrice,
            0,
            false
        );

        // Redeem Stablecoin or Perform Delayed Settlement
        redeemFunds(
            tokensGiven,
            tokensRecieved,
            whitelistedAddress,
            stablecoin,
            burningPrice
        );

        // Burn Tokens to Address
        InterfaceInverseToken token = InterfaceInverseToken(inverseToken);
        token.burnTokens(address(cashPool), tokensGiven);

        return true;
    }

    function writeOrderResponse(
        string memory orderType,
        address whiteListedAddress,
        uint256 tokensGiven,
        uint256 tokensRecieved,
        address stablecoin,
        uint256 price
    ) internal {
        require(
            tokensGiven != 0 && tokensRecieved != 0,
            "amount must be greater than 0"
        );

        emit SuccessfulOrder(
            orderType,
            whiteListedAddress,
            tokensGiven,
            tokensRecieved,
            stablecoin,
            price
        );
    }

    function settleDelayedFunds(
        uint256 tokensToRedeem,
        address whitelistedAddress,
        address stablecoin
    ) public onlyOwnerOrBridge notPausedOrShutdown {
        require(
            kycVerifier.isAddressWhitelisted(whitelistedAddress),
            "only whitelisted may redeem funds"
        );

        bool isSufficientFunds = isHotWalletSufficient(
            tokensToRedeem,
            stablecoin
        );
        require(
            isSufficientFunds == true,
            "not enough funds in the hot wallet"
        );

        uint256 tokensOutstanding = persistentStorage.delayedRedemptionsByUser(
            whitelistedAddress
        );
        uint256 tokensRemaining = DSMath.sub(tokensOutstanding, tokensToRedeem);

        persistentStorage.setDelayedRedemptionsByUser(
            tokensRemaining,
            whitelistedAddress
        );
        transferTokenFromPool(
            stablecoin,
            whitelistedAddress,
            normalizeStablecoin(tokensToRedeem, stablecoin)
        );
    }

    function redeemFunds(
        uint256 tokensGiven,
        uint256 tokensToRedeem,
        address whitelistedAddress,
        address stablecoin,
        uint256 price
    ) internal {
        bool isSufficientFunds = isHotWalletSufficient(
            tokensToRedeem,
            stablecoin
        );

        if (isSufficientFunds) {
            transferTokenFromPool(
                stablecoin,
                whitelistedAddress,
                normalizeStablecoin(tokensToRedeem, stablecoin)
            );
            writeOrderResponse(
                "REDEEM",
                whitelistedAddress,
                tokensGiven,
                tokensToRedeem,
                stablecoin,
                price
            );
        } else {
            uint256 tokensOutstanding = persistentStorage
                .delayedRedemptionsByUser(whitelistedAddress);
            tokensOutstanding = DSMath.add(tokensOutstanding, tokensToRedeem);
            persistentStorage.setDelayedRedemptionsByUser(
                tokensOutstanding,
                whitelistedAddress
            );
            writeOrderResponse(
                "REDEEM_NO_SETTLEMENT",
                whitelistedAddress,
                tokensGiven,
                tokensToRedeem,
                stablecoin,
                price
            );
        }
    }

    function isHotWalletSufficient(uint256 tokensToRedeem, address stablecoin)
        internal
        returns (bool)
    {
        InterfaceInverseToken _stablecoin = InterfaceInverseToken(stablecoin);
        uint256 stablecoinBalance = _stablecoin.balanceOf(address(cashPool));

        if (normalizeStablecoin(tokensToRedeem, stablecoin) > stablecoinBalance)
            return false;
        return true;
    }

    function normalizeStablecoin(uint256 stablecoinValue, address stablecoin)
        internal
        returns (uint256)
    {
        erc20 = InterfaceERC20(stablecoin);
        uint256 exponent = 18 - erc20.decimals();
        return stablecoinValue / 10**exponent; // 6 decimal stable coin = 10**12
    }

    ////////////////    Daily Rebalance     ////////////////
    //////////////// Threshold Rebalance    ////////////////

    /**
     * @dev Performs rebalance calculations and saves them in persistent storages
     * @param _tokenValueNetFees The token value after fees are removed
     * @param _bestExecutionPrice The best execution price for rebalancing
     * @param _markPrice The Mark Price
     * @param _notionalPreRebalance The notional amount before rebalance
     * @param _targetLeverage The targetLeverage
     * @param _effectiveFundingRate The effectiveFundingRate
     */
    function rebalance(
        uint256 _tokenValueNetFees,
        uint256 _bestExecutionPrice,
        uint256 _markPrice,
        uint256 _notionalPreRebalance,
        uint256 _targetLeverage,
        uint256 _effectiveFundingRate
    ) public onlyOwnerOrBridge() notPausedOrShutdown() {
        (
            uint256 notional,
            int256 changeInNotional,
            uint256 tokenValue
        ) = compositionCalculator.calculateRebalanceValues(
            _tokenValueNetFees,
            _bestExecutionPrice,
            _markPrice,
            _notionalPreRebalance,
            _targetLeverage
        );

        persistentStorage.setAccounting(
            _tokenValueNetFees,
            _bestExecutionPrice,
            _markPrice,
            notional,
            changeInNotional,
            tokenValue,
            _effectiveFundingRate
        );
        emit RebalanceEvent(
            _tokenValueNetFees,
            _bestExecutionPrice,
            _markPrice,
            notional,
            changeInNotional,
            tokenValue,
            _effectiveFundingRate
        );
    }

    //////////////// Transfer Stablecoin Out of Pool   ////////////////
    //////////////// Transfer Stablecoin In of Pool    ////////////////
    //////////////// Transfer InverseToken Out of Pool ////////////////
    //////////////// Transfer InverseToken In of Pool  ////////////////

    function transferTokenToPool(
        address tokenContract,
        address whiteListedAddress,
        uint256 orderAmount
    ) internal returns (bool) {
        // Check orderAmount <= availableAmount
        // Transfer USDC to Stablecoin Cash Pool
        return
            cashPool.moveTokenToPool(
                tokenContract,
                whiteListedAddress,
                orderAmount
            );
    }

    function transferTokenFromPool(
        address tokenContract,
        address destinationAddress,
        uint256 orderAmount
    ) internal returns (bool) {
        // Check orderAmount <= availableAmount
        // Transfer USDC to Destination Address
        return
            cashPool.moveTokenfromPool(
                tokenContract,
                destinationAddress,
                orderAmount
            );
    }

    function setCashPool(address _cashPool) public onlyOwner {
        require(_cashPool != address(0), "adddress must not be empty");
        cashPool = InterfaceCashPool(_cashPool);
    }

    function setStorage(address _storage) public onlyOwner {
        require(_storage != address(0), "adddress must not be empty");
        persistentStorage = InterfaceStorageLeverage(_storage);
    }
    
    function setKycVerfier(address _kycVerifier) public onlyOwner {
        require(_kycVerifier != address(0), "adddress must not be empty");
        kycVerifier = InterfaceKYCVerifier(_kycVerifier);
    }
    
    function setCalculator(address _calculator) public onlyOwner {
        require(_calculator != address(0), "adddress must not be empty");
        compositionCalculator = InterfaceCalculator(_calculator);
    }

    modifier onlyOwnerOrBridge() {
        require(
            isOwner() || _msgSender() == persistentStorage.bridge(),
            "caller is not the owner or bridge"
        );
        _;
    }

    modifier notPausedOrShutdown() {
        require(persistentStorage.isPaused() == false, "contract is paused");
        require(
            persistentStorage.isShutdown() == false,
            "contract is shutdown"
        );
        _;
    }
}
