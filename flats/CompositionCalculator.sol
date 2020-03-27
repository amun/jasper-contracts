
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

// File: contracts/utils/Math.sol

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
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
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

// File: contracts/utils/DateTimeLibrary.sol

pragma solidity ^0.5.0;

// ----------------------------------------------------------------------------
// BokkyPooBah's DateTime Library v1.01
//
// A gas-efficient Solidity date and time library
//
// https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary
//
// Tested date range 1970/01/01 to 2345/12/31
//
// Conventions:
// Unit      | Range         | Notes
// :-------- |:-------------:|:-----
// timestamp | >= 0          | Unix timestamp, number of seconds since 1970/01/01 00:00:00 UTC
// year      | 1970 ... 2345 |
// month     | 1 ... 12      |
// day       | 1 ... 31      |
// hour      | 0 ... 23      |
// minute    | 0 ... 59      |
// second    | 0 ... 59      |
// dayOfWeek | 1 ... 7       | 1 = Monday, ..., 7 = Sunday
//
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2018-2019. The MIT Licence.
// ----------------------------------------------------------------------------

library DateTimeLibrary {
    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint256 constant SECONDS_PER_HOUR = 60 * 60;
    uint256 constant SECONDS_PER_MINUTE = 60;
    int256 constant OFFSET19700101 = 2440588;

    uint256 constant DOW_MON = 1;
    uint256 constant DOW_TUE = 2;
    uint256 constant DOW_WED = 3;
    uint256 constant DOW_THU = 4;
    uint256 constant DOW_FRI = 5;
    uint256 constant DOW_SAT = 6;
    uint256 constant DOW_SUN = 7;

    // ------------------------------------------------------------------------
    // Calculate the number of days from 1970/01/01 to year/month/day using
    // the date conversion algorithm from
    //   http://aa.usno.navy.mil/faq/docs/JD_Formula.php
    // and subtracting the offset 2440588 so that 1970/01/01 is day 0
    //
    // days = day
    //      - 32075
    //      + 1461 * (year + 4800 + (month - 14) / 12) / 4
    //      + 367 * (month - 2 - (month - 14) / 12 * 12) / 12
    //      - 3 * ((year + 4900 + (month - 14) / 12) / 100) / 4
    //      - offset
    // ------------------------------------------------------------------------
    function _daysFromDate(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 _days)
    {
        require(year >= 1970);
        int256 _year = int256(year);
        int256 _month = int256(month);
        int256 _day = int256(day);

        int256 __days = _day -
            32075 +
            (1461 * (_year + 4800 + (_month - 14) / 12)) /
            4 +
            (367 * (_month - 2 - ((_month - 14) / 12) * 12)) /
            12 -
            (3 * ((_year + 4900 + (_month - 14) / 12) / 100)) /
            4 -
            OFFSET19700101;

        _days = uint256(__days);
    }

    // ------------------------------------------------------------------------
    // Calculate year/month/day from the number of days since 1970/01/01 using
    // the date conversion algorithm from
    //   http://aa.usno.navy.mil/faq/docs/JD_Formula.php
    // and adding the offset 2440588 so that 1970/01/01 is day 0
    //
    // int L = days + 68569 + offset
    // int N = 4 * L / 146097
    // L = L - (146097 * N + 3) / 4
    // year = 4000 * (L + 1) / 1461001
    // L = L - 1461 * year / 4 + 31
    // month = 80 * L / 2447
    // dd = L - 2447 * month / 80
    // L = month / 11
    // month = month + 2 - 12 * L
    // year = 100 * (N - 49) + year + L
    // ------------------------------------------------------------------------
    function _daysToDate(uint256 _days)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        int256 __days = int256(_days);

        int256 L = __days + 68569 + OFFSET19700101;
        int256 N = (4 * L) / 146097;
        L = L - (146097 * N + 3) / 4;
        int256 _year = (4000 * (L + 1)) / 1461001;
        L = L - (1461 * _year) / 4 + 31;
        int256 _month = (80 * L) / 2447;
        int256 _day = L - (2447 * _month) / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint256(_year);
        month = uint256(_month);
        day = uint256(_day);
    }

    function daysFromDate(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 daysSinceDate)
    {
        daysSinceDate = _daysFromDate(year, month, day);
    }
    function timestampFromDate(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 timestamp)
    {
        timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY;
    }
    function timestampFromDateTime(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 hour,
        uint256 minute,
        uint256 second
    ) internal pure returns (uint256 timestamp) {
        timestamp =
            _daysFromDate(year, month, day) *
            SECONDS_PER_DAY +
            hour *
            SECONDS_PER_HOUR +
            minute *
            SECONDS_PER_MINUTE +
            second;
    }
    function timestampToDate(uint256 timestamp)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function timestampToDateTime(uint256 timestamp)
        internal
        pure
        returns (
            uint256 year,
            uint256 month,
            uint256 day,
            uint256 hour,
            uint256 minute,
            uint256 second
        )
    {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        uint256 secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
        secs = secs % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
        second = secs % SECONDS_PER_MINUTE;
    }

    function isValidDate(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (bool valid)
    {
        if (year >= 1970 && month > 0 && month <= 12) {
            uint256 daysInMonth = _getDaysInMonth(year, month);
            if (day > 0 && day <= daysInMonth) {
                valid = true;
            }
        }
    }
    function isValidDateTime(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 hour,
        uint256 minute,
        uint256 second
    ) internal pure returns (bool valid) {
        if (isValidDate(year, month, day)) {
            if (hour < 24 && minute < 60 && second < 60) {
                valid = true;
            }
        }
    }
    function isLeapYear(uint256 timestamp)
        internal
        pure
        returns (bool leapYear)
    {
        (uint256 year, , ) = _daysToDate(timestamp / SECONDS_PER_DAY);
        leapYear = _isLeapYear(year);
    }
    function _isLeapYear(uint256 year) internal pure returns (bool leapYear) {
        leapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    }
    function isWeekDay(uint256 timestamp) internal pure returns (bool weekDay) {
        weekDay = getDayOfWeek(timestamp) <= DOW_FRI;
    }
    function isWeekEnd(uint256 timestamp) internal pure returns (bool weekEnd) {
        weekEnd = getDayOfWeek(timestamp) >= DOW_SAT;
    }
    function getDaysInMonth(uint256 timestamp)
        internal
        pure
        returns (uint256 daysInMonth)
    {
        (uint256 year, uint256 month, ) = _daysToDate(
            timestamp / SECONDS_PER_DAY
        );
        daysInMonth = _getDaysInMonth(year, month);
    }
    function _getDaysInMonth(uint256 year, uint256 month)
        internal
        pure
        returns (uint256 daysInMonth)
    {
        if (
            month == 1 ||
            month == 3 ||
            month == 5 ||
            month == 7 ||
            month == 8 ||
            month == 10 ||
            month == 12
        ) {
            daysInMonth = 31;
        } else if (month != 2) {
            daysInMonth = 30;
        } else {
            daysInMonth = _isLeapYear(year) ? 29 : 28;
        }
    }
    // 1 = Monday, 7 = Sunday
    function getDayOfWeek(uint256 timestamp)
        internal
        pure
        returns (uint256 dayOfWeek)
    {
        uint256 _days = timestamp / SECONDS_PER_DAY;
        dayOfWeek = ((_days + 3) % 7) + 1;
    }

    function getYear(uint256 timestamp) internal pure returns (uint256 year) {
        (year, , ) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function getMonth(uint256 timestamp) internal pure returns (uint256 month) {
        (, month, ) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function getDay(uint256 timestamp) internal pure returns (uint256 day) {
        (, , day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    function getHour(uint256 timestamp) internal pure returns (uint256 hour) {
        uint256 secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
    }
    function getMinute(uint256 timestamp)
        internal
        pure
        returns (uint256 minute)
    {
        uint256 secs = timestamp % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
    }
    function getSecond(uint256 timestamp)
        internal
        pure
        returns (uint256 second)
    {
        second = timestamp % SECONDS_PER_MINUTE;
    }

    function addYears(uint256 timestamp, uint256 _years)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        (uint256 year, uint256 month, uint256 day) = _daysToDate(
            timestamp / SECONDS_PER_DAY
        );
        year += _years;
        uint256 daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp =
            _daysFromDate(year, month, day) *
            SECONDS_PER_DAY +
            (timestamp % SECONDS_PER_DAY);
        require(newTimestamp >= timestamp);
    }
    function addMonths(uint256 timestamp, uint256 _months)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        (uint256 year, uint256 month, uint256 day) = _daysToDate(
            timestamp / SECONDS_PER_DAY
        );
        month += _months;
        year += (month - 1) / 12;
        month = ((month - 1) % 12) + 1;
        uint256 daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp =
            _daysFromDate(year, month, day) *
            SECONDS_PER_DAY +
            (timestamp % SECONDS_PER_DAY);
        require(newTimestamp >= timestamp);
    }
    function addDays(uint256 timestamp, uint256 _days)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        newTimestamp = timestamp + _days * SECONDS_PER_DAY;
        require(newTimestamp >= timestamp);
    }
    function addHours(uint256 timestamp, uint256 _hours)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        newTimestamp = timestamp + _hours * SECONDS_PER_HOUR;
        require(newTimestamp >= timestamp);
    }
    function addMinutes(uint256 timestamp, uint256 _minutes)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        newTimestamp = timestamp + _minutes * SECONDS_PER_MINUTE;
        require(newTimestamp >= timestamp);
    }
    function addSeconds(uint256 timestamp, uint256 _seconds)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        newTimestamp = timestamp + _seconds;
        require(newTimestamp >= timestamp);
    }

    function subYears(uint256 timestamp, uint256 _years)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        (uint256 year, uint256 month, uint256 day) = _daysToDate(
            timestamp / SECONDS_PER_DAY
        );
        year -= _years;
        uint256 daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp =
            _daysFromDate(year, month, day) *
            SECONDS_PER_DAY +
            (timestamp % SECONDS_PER_DAY);
        require(newTimestamp <= timestamp);
    }
    function subMonths(uint256 timestamp, uint256 _months)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        (uint256 year, uint256 month, uint256 day) = _daysToDate(
            timestamp / SECONDS_PER_DAY
        );
        uint256 yearMonth = year * 12 + (month - 1) - _months;
        year = yearMonth / 12;
        month = (yearMonth % 12) + 1;
        uint256 daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp =
            _daysFromDate(year, month, day) *
            SECONDS_PER_DAY +
            (timestamp % SECONDS_PER_DAY);
        require(newTimestamp <= timestamp);
    }
    function subDays(uint256 timestamp, uint256 _days)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        newTimestamp = timestamp - _days * SECONDS_PER_DAY;
        require(newTimestamp <= timestamp);
    }
    function subHours(uint256 timestamp, uint256 _hours)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        newTimestamp = timestamp - _hours * SECONDS_PER_HOUR;
        require(newTimestamp <= timestamp);
    }
    function subMinutes(uint256 timestamp, uint256 _minutes)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        newTimestamp = timestamp - _minutes * SECONDS_PER_MINUTE;
        require(newTimestamp <= timestamp);
    }
    function subSeconds(uint256 timestamp, uint256 _seconds)
        internal
        pure
        returns (uint256 newTimestamp)
    {
        newTimestamp = timestamp - _seconds;
        require(newTimestamp <= timestamp);
    }

    function diffYears(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 _years)
    {
        require(fromTimestamp <= toTimestamp);
        (uint256 fromYear, , ) = _daysToDate(fromTimestamp / SECONDS_PER_DAY);
        (uint256 toYear, , ) = _daysToDate(toTimestamp / SECONDS_PER_DAY);
        _years = toYear - fromYear;
    }
    function diffMonths(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 _months)
    {
        require(fromTimestamp <= toTimestamp);
        (uint256 fromYear, uint256 fromMonth, ) = _daysToDate(
            fromTimestamp / SECONDS_PER_DAY
        );
        (uint256 toYear, uint256 toMonth, ) = _daysToDate(
            toTimestamp / SECONDS_PER_DAY
        );
        _months = toYear * 12 + toMonth - fromYear * 12 - fromMonth;
    }
    function diffDays(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 _days)
    {
        require(fromTimestamp <= toTimestamp);
        _days = (toTimestamp - fromTimestamp) / SECONDS_PER_DAY;
    }
    function diffHours(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 _hours)
    {
        require(fromTimestamp <= toTimestamp);
        _hours = (toTimestamp - fromTimestamp) / SECONDS_PER_HOUR;
    }
    function diffMinutes(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 _minutes)
    {
        require(fromTimestamp <= toTimestamp);
        _minutes = (toTimestamp - fromTimestamp) / SECONDS_PER_MINUTE;
    }
    function diffSeconds(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 _seconds)
    {
        require(fromTimestamp <= toTimestamp);
        _seconds = toTimestamp - fromTimestamp;
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

// File: contracts/PersistentStorage.sol

pragma solidity ^0.5.0;



contract PersistentStorage is Ownable {

  address public tokenSwapManager;
  address public bridge;

  bool public isPaused;
  uint256 public isShutdown;

  struct Accounting {
    uint256 price;
    uint256 cashPositionPerToken;
    uint256 balancePerToken;
    uint256 lendingFee;
  }

  struct CreateOrderTimestamp {
    uint256 numOfTokens;
    uint256 timestamp;
  }

  struct Order {
    string orderType;
    uint256 tokensGiven;
    uint256 tokensRecieved;
    uint256 avgBlendedFee;
  }

  uint256 public lastActivityDay;
  uint256 public minRebalanceAmount;
  uint256 public managementFee;

  mapping (uint256 => Accounting[]) private accounting;

  mapping (address => bool) public whitelistedAddresses;

  uint256[] public mintingFeeBracket;
  mapping (uint256 => uint256) public mintingFee;

  Order[] public allOrders;
  mapping (address => Order[]) public orderByUser;
  mapping (address => CreateOrderTimestamp[]) public lockedOrders;


  event AccountingValuesSet(uint256 today);
  event RebalanceValuesSet(uint256 newMinRebalanceAmount);
  event ManagementFeeValuesSet(uint256 newManagementFee);


 function initialize(address ownerAddress, uint256 _managementFee, uint256 _minRebalanceAmount) public initializer {
    Ownable.initialize(ownerAddress);
    managementFee = _managementFee;
    minRebalanceAmount = _minRebalanceAmount;
    mintingFeeBracket.push(50000 ether);
    mintingFeeBracket.push(100000 ether);
    mintingFee[50000 ether] = 3 ether / 1000; //0.3%
    mintingFee[100000 ether] = 2 ether / 1000; //0.2%
    mintingFee[2^256-1] = 1 ether / 1000; //0.1% all values higher
  }

  function setTokenSwapManager(address _tokenSwapManager) public onlyOwner {
    require(_tokenSwapManager != address(0), 'adddress must not be empty');
    tokenSwapManager = _tokenSwapManager;
  }

  function setBridge(address _bridge) public onlyOwner {
    require(_bridge != address(0), 'adddress must not be empty');
    bridge = _bridge;
  }

  function setIsPaused(bool _isPaused) public onlyOwner {
    isPaused = _isPaused;
  }

  function setIsShutdown() public onlyOwner {
    isShutdown = 1;
  }



  /**
  * @dev Throws if called by any account other than the owner.
  */
  modifier onlyOwnerOrTokenSwap() {
      require(isOwner() || _msgSender() == tokenSwapManager, "caller is not the owner or token swap manager");
      _;
  }



  /*
  * Saves order in mapping (address => Order[]) orderByUser
  * orderIndex == 100000000, append to Order[]
  * orderIndex != 100000000, overwrite element at orderIndex
  */

  function setOrderByUser(
    address whitelistedAddress,
    string memory orderType,
    uint256 tokensGiven,
    uint256 tokensRecieved,
    uint256 avgBlendedFee,
    uint256 orderIndex
  )
    public
    onlyOwnerOrTokenSwap
  {
    Order memory newOrder = Order(
      orderType,
      tokensGiven,
      tokensRecieved,
      avgBlendedFee
    );

    if (orderIndex == 100000000) {
      orderByUser[whitelistedAddress].push(newOrder);
    } else {
      orderByUser[whitelistedAddress][orderIndex] = newOrder;
    }
  }

  /*
  * Gets Order[] For User Address
  * Return order at Index in Order[]
  */

  function getOrderByUser(
    address whitelistedAddress,
    uint256 orderIndex
  )
    public view
    returns (string memory orderType, uint256 tokensGiven, uint256 tokensRecieved, uint256 avgBlendedFee)
  {
    Order storage orderAtIndex = orderByUser[whitelistedAddress][orderIndex];
    return (
      orderAtIndex.orderType,
      orderAtIndex.tokensGiven,
      orderAtIndex.tokensRecieved,
      orderAtIndex.avgBlendedFee

    );

  }

  /*
  * Save order to allOrders array
  * orderIndex == 100000000, append to allOrders array
  * orderIndex != 100000000, overwrite element at orderIndex
  */

  function setOrder(
    string memory orderType,
    uint256 tokensGiven,
    uint256 tokensRecieved,
    uint256 avgBlendedFee,
    uint256 orderIndex
  )
    public
    onlyOwnerOrTokenSwap
  {
    Order memory newOrder = Order(
      orderType,
      tokensGiven,
      tokensRecieved,
      avgBlendedFee
    );

    if (orderIndex == 100000000) {
      allOrders.push(newOrder);
    } else {
      allOrders[orderIndex] = newOrder;
    }

  }

  /*
  * Saves order to allOrders array
  * orderIndex == 100000000, append to allOrders array
  * orderIndex != 100000000, overwrite element at orderIndex
  */

  function getOrder(uint256 index)
    public view
    returns (string memory orderType, uint256 tokensGiven, uint256 tokensRecieved, uint256 avgBlendedFee)
  {
    Order storage orderAtIndex = allOrders[index];
    return (
      orderAtIndex.orderType,
      orderAtIndex.tokensGiven,
      orderAtIndex.tokensRecieved,
      orderAtIndex.avgBlendedFee
    );
  }

  /*
  * Saves order to mapping (address => CreateOrderTimestamp[]) lockedOrders
  * Appends order to CreateOrderTimestamp[]
  */

  function setLockedOrderForUser(
    address authorizedUser,
    uint256 lockedAmount,
    uint256 blockTimestamp
  )
    public
    onlyOwnerOrTokenSwap
  {
    require(authorizedUser != address(0), 'adddress must not be empty');
    require(lockedAmount != 0, 'creation order must be greater than 0');

    CreateOrderTimestamp memory newCreateOrder = CreateOrderTimestamp(lockedAmount, blockTimestamp);
    CreateOrderTimestamp[] storage allCreateOrders = lockedOrders[authorizedUser];
    allCreateOrders.push(newCreateOrder);

  }

  /*
  * Get order from mapping (address => CreateOrderTimestamp[]) lockedOrders
  * Returns element at index in CreateOrderTimestamp[]
  */

  function getLockedOrderForUser(
    address authorizedUser,
    uint256 index
  )
    public
    view
    returns (uint256 timelockedAmount, uint256 blockTimestamp)
  {
    require(authorizedUser != address(0), 'adddress must not be empty');
    CreateOrderTimestamp[] memory allCreateOrders = lockedOrders[authorizedUser];

    return (
      allCreateOrders[index].numOfTokens,
      allCreateOrders[index].timestamp
    );
  }


  /*
  * Get CreateOrderTimestamp[] array size
  */
  function getLockedOrdersArraySize(address authorizedUser)
    public
    view
    returns (uint256 count)
  {
    require(authorizedUser != address(0), 'adddress must not be empty');
    CreateOrderTimestamp[] memory allCreateOrders = lockedOrders[authorizedUser];
    return allCreateOrders.length;
  }


  // @dev Set whitelisted addresses
  function setWhitelistedAddress(address adddressToAdd) public onlyOwner {
    require(adddressToAdd != address(0), 'adddress must not be empty');

    whitelistedAddresses[adddressToAdd] = true;
  }

  // @dev Remove whitelisted addresses
  function removeWhitelistedAddress(address addressToRemove) public onlyOwner {
    require(whitelistedAddresses[addressToRemove], 'address must be added to be removed allowed');

    delete whitelistedAddresses[addressToRemove];
  }

  // @dev Updates whitelisted addresses
  function updateWhitelistedAddress(address oldAddress, address newAddress) public {
    removeWhitelistedAddress(oldAddress);
    setWhitelistedAddress(newAddress);
  }

  // @dev Get accounting values for a specific day
  // @param date format as 20200123 for 23th of January 2020
  function getAccounting(uint256 date) public view returns (uint256, uint256, uint256, uint256) {
      return(
        accounting[date][accounting[date].length-1].price,
        accounting[date][accounting[date].length-1].cashPositionPerToken,
        accounting[date][accounting[date].length-1].balancePerToken,
        accounting[date][accounting[date].length-1].lendingFee
      );
  }

  // @dev Set accounting values for the day
  function setAccounting
    (
      uint256 _price,
      uint256 _cashPositionPerToken,
      uint256 _balancePerToken,
      uint256 _lendingFee
    )
      external
      onlyOwnerOrTokenSwap
  {
    (uint256 year, uint256 month, uint256 day) = DateTimeLibrary.timestampToDate(now);
    uint256 today = year * 10000 + month * 100 + day;
      accounting[today].push(Accounting(_price, _cashPositionPerToken, _balancePerToken, _lendingFee));
      lastActivityDay = today;
      emit AccountingValuesSet(today);
  }

  // @dev Set accounting values for the day
  function setAccountingForLastActivityDay
    (
      uint256 _price,
      uint256 _cashPositionPerToken,
      uint256 _balancePerToken,
      uint256 _lendingFee
    )
      external
      onlyOwnerOrTokenSwap
  {
      accounting[lastActivityDay].push(Accounting(_price, _cashPositionPerToken, _balancePerToken, _lendingFee));
      emit AccountingValuesSet(lastActivityDay);
  }

  // @dev Set last rebalance information
  function setMinRebalanceAmount(uint256 _minRebalanceAmount) external onlyOwner {
    minRebalanceAmount = _minRebalanceAmount;

    emit RebalanceValuesSet(minRebalanceAmount);
  }

  // @dev Set last rebalance information
  function setManagementFee(uint256 _managementFee) external onlyOwner {
    managementFee = _managementFee;
    emit ManagementFeeValuesSet(managementFee);
  }

  // @dev Returns price
  function getPrice() public view returns (uint256 price) {
    return accounting[lastActivityDay][accounting[lastActivityDay].length-1].price;
  }

  // @dev Returns cash position amount
  function getCashPositionPerToken() public view returns (uint256 amount) {
      return accounting[lastActivityDay][accounting[lastActivityDay].length-1].cashPositionPerToken;
  }

  // @dev Returns borrowed crypto amount
  function getBalancePerToken() public view returns (uint256 amount) {
    return accounting[lastActivityDay][accounting[lastActivityDay].length-1].balancePerToken;
  }

  // @dev Returns lending fee
  function getLendingFee() public view returns (uint256 lendingRate) {
    return accounting[lastActivityDay][accounting[lastActivityDay].length-1].lendingFee;
  }
 // @dev Returns lending fee
  function getManagementFee() public view returns (uint256 lendingRate) {
    return managementFee;
  }
  // @dev Returns total fee
  function getTotalFee() public view returns (uint256 totalFee) {
    return getLendingFee() + getManagementFee();
  }
  // @dev Sets last minting fee
  function setLastMintingFee(uint256 _mintingFee) public onlyOwner {
    mintingFee[2^256-1] = _mintingFee;
  }
  // @dev Adds minting fee
  function addMintingFeeBracket(uint256 _mintingFeeLimit, uint256 _mintingFee) public onlyOwner {
    require(_mintingFeeLimit > mintingFeeBracket[mintingFeeBracket.length-1], 'New minting fee bracket needs to be bigger then last one');
    mintingFeeBracket.push(_mintingFeeLimit);
    mintingFee[_mintingFeeLimit] = _mintingFee;
  }
  // @dev Deletes last minting fee
  function deleteLastMintingFeeBracket() public onlyOwner {
    delete mintingFee[mintingFeeBracket[mintingFeeBracket.length-1]];
    delete mintingFeeBracket[mintingFeeBracket.length-1];
  }
  // @dev Changes minting fee
  function changeMintingLimit(uint256 _position, uint256 _mintingFeeLimit, uint256 _mintingFee) public onlyOwner {
    require(_mintingFeeLimit > mintingFeeBracket[mintingFeeBracket.length-1], 'New minting fee bracket needs to be bigger then last one');
    if(_position != 0){
      require(_mintingFeeLimit > mintingFeeBracket[_position-1], 'New minting fee bracket needs to be bigger then last one');
    }
    if(_position < mintingFeeBracket.length-1){
      require(_mintingFeeLimit < mintingFeeBracket[_position+1], 'New minting fee bracket needs to be smaller then next one');
    }
    mintingFeeBracket[_position] = _mintingFeeLimit;
    mintingFee[_mintingFeeLimit] = _mintingFee;
  }
  // @dev Returns minting fee for cash
  function getMintingFee(uint256 cash) public view returns(uint256){
    for ( uint i = 0; i < mintingFeeBracket.length; i++ ) {
      if (cash <= mintingFeeBracket[i]) {
        return mintingFee[mintingFeeBracket[i]];
      }
    }
    return mintingFee[2^256-1];
  }
}

// File: contracts/Abstract/InterfaceInverseToken.sol

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

// File: contracts/CompositionCalculator.sol

pragma solidity ^0.5.0;







/**
 * @dev uint256 are expected to use last 18 numbers as decimal points except when specifid differently in @params
 */
contract CompositionCalculator is Initializable {
    using SafeMath for uint256;

    PersistentStorage public persistentStorage;
    InterfaceInverseToken public inverseToken;

    function initialize(
        address _persistentStorageAddress,
        address _inverseTokenAddress
    ) public initializer {
        persistentStorage = PersistentStorage(_persistentStorageAddress);
        inverseToken = InterfaceInverseToken(_inverseTokenAddress);
    }

    //*************************************************************************
    //************************** Pure Functions *******************************
    //*************************************************************************

    /**
     * @dev Returns NAV for the given values
     * @param _cashPosition The yearly average lending fee for borrowed balance
     * @param _balance The balnce (dept/borrow) in crypto
     * @param _price The momentary price of the crypto
     */
    function getNAV(uint256 _cashPosition, uint256 _balance, uint256 _price)
        public
        pure
        returns (uint256 nav)
    {
        // Calculate NAV of Product
        uint256 balanceWorth = DSMath.wmul(_balance, _price);
        require(
            _cashPosition > balanceWorth,
            "The cash position needs to be bigger then the borrowed crypto is worth"
        );
        nav = DSMath.sub(_cashPosition, balanceWorth);
        return nav;
    }

    /**
     * @dev Returns the crypto amount to pay as lending fee
     * @param _lendingFee The yearly average lending fee for borrowed balance
     * @param _balance The balnce (dept/borrow) in crypto
     * @param _days The days since the last fee calculation (Natural number)
     */
    function getLendingFeeInCrypto(
        uint256 _lendingFee,
        uint256 _balance,
        uint256 _days
    ) public pure returns (uint256 feeInCrypto) {
        uint256 lendingFeePercent = DSMath.wdiv(_lendingFee, 100 ether);
        uint256 feePerDay = DSMath.wdiv(lendingFeePercent, 365 ether);
        uint256 feeInCryptoForOneDay = DSMath.wmul(feePerDay, _balance);
        feeInCrypto = DSMath.mul(_days, feeInCryptoForOneDay);
    }

    /**
     * Returns the change of balance with decimal at 18
     * @param _nav The current nav of the product
     * @param _balance The balnce (dept/borrow) in crypto
     * @param _price The momentary price of the crypto
     */
    function getNeededChangeInBalanceToRebalance(
        uint256 _nav,
        uint256 _balance,
        uint256 _price
    ) public pure returns (uint256 changeInBalance, bool negative) {
        require(_price != 0, "Price cant be zero");

        uint256 newAcountBalance = DSMath.wdiv(_nav, _price);

        if (newAcountBalance >= _balance) {
            changeInBalance = DSMath.sub(newAcountBalance, _balance);
            negative = false;
        } else {
            changeInBalance = DSMath.sub(_balance, newAcountBalance);
            negative = true;
        }
    }

    /**
     * @param _a First number
     * @param _b Second number
     * @param _isBNegative Is number b negative
     */
    function addOrSub(
        //getDeliverables
        uint256 _a,
        uint256 _b,
        bool _isBNegative
    ) internal pure returns (uint256 result) {
        if (_isBNegative) {
            return _a.sub(_b);
        } else {
            return _a.add(_b);
        }
    }

    /**
     * @dev Returns imported values for a PCF
     * @param _cashPosition The total cash position on the token
     * @param _balance The balance (dept/borrow) in crypto
     * @param _price The momentary price of the crypto
     * @param _lendingFee The yearly average lending fee for borrowed balance
     * @param _days The days since the last fee calculation  (Natural number)
     * @param _minRebalanceAmount The minimum amount to rebalance
     */
    function calculatePCF(
        uint256 _cashPosition,
        uint256 _balance,
        uint256 _price,
        uint256 _lendingFee,
        uint256 _days,
        uint256 _minRebalanceAmount
    )
        public
        pure
        returns (
            uint256 endNav,
            uint256 endBalance,
            uint256 endCashPosition,
            uint256 feeInFiat,
            uint256 changeInBalance,
            bool isChangeInBalanceNeg
        )
    {
        require(_price != 0, "Price cant be zero");
        // Update Calculation for NAV, Cash Position, Loan Positions, and Accrued Fees

        //remove fees
        uint256 feeInCrypto = getLendingFeeInCrypto(
            _lendingFee,
            _balance,
            _days
        );
        require(
            feeInCrypto <= _balance,
            "The balance cant be smaller then the fee"
        );

        feeInFiat = DSMath.wmul(feeInCrypto, _price);

        //cashPositionWithoutFee
        endCashPosition = DSMath.sub(_cashPosition, feeInFiat);

        //calculte change in balance (rebalance)
        endBalance = DSMath.wdiv(
            getNAV(endCashPosition, _balance, _price),
            _price
        );

        (
            changeInBalance,
            isChangeInBalanceNeg
        ) = getNeededChangeInBalanceToRebalance(
            getNAV(endCashPosition, _balance, _price),
            _balance,
            _price
        );

        if (changeInBalance < _minRebalanceAmount) {
            changeInBalance = 0;
            endBalance = _balance;
        }

        //result
        endCashPosition = addOrSub(
            endCashPosition, //cashPositionWithoutFee
            DSMath.wmul(changeInBalance, _price),
            isChangeInBalanceNeg
        );
        endNav = getNAV(endCashPosition, endBalance, _price);
    }

    /**
     * @param _cashPosition The total cash position on the token
     * @param _balance The balance (dept/borrow) in crypto
     * @param _price The momentary price of the crypto
     * @param _lendingFee The yearly average lending fee for borrowed balance
     * @param _days The days since the last fee calculation (Natural number)
     */
    function calculatePCFWithoutMin(
        //getDeliverables
        uint256 _cashPosition,
        uint256 _balance,
        uint256 _price,
        uint256 _lendingFee,
        uint256 _days
    )
        public
        pure
        returns (
            uint256 endNav,
            uint256 endBalance,
            uint256 endCashPosition,
            uint256 feeInFiat,
            uint256 changeInBalance,
            bool isChangeInBalanceNeg
        )
    {
        return
            calculatePCF(
                _cashPosition,
                _balance,
                _price,
                _lendingFee,
                _days,
                0
            );
    }

    /**
     * @dev Returns the amount of token created by cash at price
     * @param _cashPosition The total cash position on the token
     * @param _balance The balance (dept/borrow) in crypto
     * @param _totalTokenSupply The total token supply
     * @param _cash The cash provided to create token
     * @param _spotPrice The momentary price of the crypto
     */
    function getTokenAmountCreatedByCash(
        //Create
        uint256 _cashPosition,
        uint256 _balance,
        uint256 _totalTokenSupply,
        uint256 _cash,
        uint256 _spotPrice
    ) public pure returns (uint256 tokenAmountCreated) {
        require(_spotPrice != 0, "Price cant be zero");
        require(_totalTokenSupply != 0, "Token supply cant be zero");

        uint256 exNav = getNAV(_cashPosition, _balance, _spotPrice);
        uint256 navPerToken = DSMath.wdiv(exNav, _totalTokenSupply);
        tokenAmountCreated = DSMath.wdiv(_cash, navPerToken);
    }

    /**
     * @dev Returns the amount of cash redeemed at price
     * @param _cashPosition The total cash position on the token
     * @param _balance The balance (dept/borrow) in crypto
     * @param _totalTokenSupply The total token supply
     * @param _tokenAmount The token provided to redeem cash
     * @param _spotPrice The momentary price of the crypto
     */
    function getCashAmountCreatedByToken(
        //Redeem
        uint256 _cashPosition,
        uint256 _balance,
        uint256 _totalTokenSupply,
        uint256 _tokenAmount,
        uint256 _spotPrice
    ) public pure returns (uint256 cashFromTokenRedeem) {
        require(_spotPrice != 0, "Price cant be zero");
        require(_totalTokenSupply != 0, "Token supply cant be zero");
        require(
            _totalTokenSupply >= _tokenAmount,
            "Token redeem cant be bigger then supply"
        );

        uint256 exNav = getNAV(_cashPosition, _balance, _spotPrice);
        uint256 navPerToken = DSMath.wdiv(exNav, _totalTokenSupply);

        cashFromTokenRedeem = DSMath.wmul(_tokenAmount, navPerToken);
    }

    /**
     * @dev Returns cash without fee
     * @param _cash The cash provided to create token
     * @param _mintingFee The minting fee to remove
     */
    function removeMintingFeeFromCash(uint256 _cash, uint256 _mintingFee)
        public
        pure
        returns (uint256 cashAfterFee)
    {
        uint256 creationFeeInCash = DSMath.wmul(_cash, _mintingFee);
        cashAfterFee = DSMath.sub(_cash, creationFeeInCash);
    }

    //*************************************************************************
    //***************** Get values for last PCF *******************************
    //*************************************************************************

    /**
     * @dev Returns the current NAV
     */
    function getCurrentNAV() public view returns (uint256 nav) {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        require(totalTokenSupply != 0, "Token supply cant be zero");

        uint256 cashPosition = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getCashPositionPerToken()
        );
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        uint256 price = persistentStorage.getPrice();

        nav = getNAV(cashPosition, balance, price);
    }

    /**
     * @dev Returns cash without fee
     * @param _cash The cash provided to create token
     */
    function removeCurrentMintingFeeFromCash(uint256 _cash)
        public
        view
        returns (uint256 cashAfterFee)
    {
        uint256 creationFee = persistentStorage.getMintingFee(_cash);
        cashAfterFee = removeMintingFeeFromCash(_cash, creationFee);
    }

    /**
     * @dev Returns the amount of token created by cash
     * @param _cash The cash provided to create token
     * @param _spotPrice The momentary price of the crypto
     */
    function getCurrentTokenAmountCreatedByCash(
        //Create
        uint256 _cash,
        uint256 _spotPrice
    ) public view returns (uint256 tokenAmountCreated) {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        require(totalTokenSupply != 0, "Token supply cant be zero");
        uint256 cashPosition = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getCashPositionPerToken()
        );

        uint256 cashAfterFee = removeCurrentMintingFeeFromCash(_cash);
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        tokenAmountCreated = getTokenAmountCreatedByCash(
            cashPosition,
            balance,
            totalTokenSupply,
            cashAfterFee,
            _spotPrice
        );
    }

    /**
     * @dev Returns the amount of cash redeemed at spot price
     * @param _tokenAmount The token provided to redeem cash
     * @param _spotPrice The momentary price of the crypto
     */
    function getCurrentCashAmountCreatedByToken(
        //Redeem
        uint256 _tokenAmount,
        uint256 _spotPrice
    ) public view returns (uint256 cashFromTokenRedeem) {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        require(totalTokenSupply != 0, "Token supply cant be zero");

        uint256 cashPosition = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getCashPositionPerToken()
        );
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        uint256 cashFromToken = getCashAmountCreatedByToken(
            cashPosition,
            balance,
            totalTokenSupply,
            _tokenAmount,
            _spotPrice
        );
        cashFromTokenRedeem = removeCurrentMintingFeeFromCash(cashFromToken);
    }

    function getDaysSinceLastRebalance()
        public
        view
        returns (uint256 daysSinceLastRebalance)
    {
        uint256 lastRebalanceDay = persistentStorage.lastActivityDay();
        uint256 year = lastRebalanceDay.div(10000);
        uint256 month = lastRebalanceDay.div(100) - year.mul(100);
        uint256 day = lastRebalanceDay - year.mul(10000) - month.mul(100);

        uint256 startDate = DateTimeLibrary.timestampFromDate(year, month, day);
        daysSinceLastRebalance = (now - startDate) / 60 / 60 / 24;
    }

    /**
     * @dev Returns the lending fee in crypto
     */
    function getCurrentLendingFeeInCrypto()
        public
        view
        returns (uint256 cryptoForLendingFee)
    {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        uint256 lendingFee = persistentStorage.getLendingFee();
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        uint256 daysSinceLastRebalance = getDaysSinceLastRebalance();

        cryptoForLendingFee = getLendingFeeInCrypto(
            lendingFee,
            balance,
            daysSinceLastRebalance
        );
    }

    /**
     * @dev Returns balance change needed to perform to have a balanced cashposition to balance ratio
     */
    function getCurrentNeededChangeInBalanceToRebalance(uint256 _price)
        public
        view
        returns (uint256 neededChangeInBalance, bool isNegative)
    {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        uint256 nav = getCurrentNAV();
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        return getNeededChangeInBalanceToRebalance(nav, balance, _price);
    }

    /**
     * @dev Returns total balance
     */
    function getTotalBalance() external view returns (uint256 totalBalance) {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        totalBalance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        return totalBalance;
    }

    /**
     * @dev Returns current PCF values for the given price
     * @param _price The momentary price of the crypto
     */
    function calculateDailyPCF(uint256 _price, uint256 _lendingFee)
        public
        view
        returns (
            uint256 endNav,
            uint256 endBalance,
            uint256 endCashPosition,
            uint256 feeInFiat,
            uint256 changeInBalance,
            bool isChangeInBalanceNeg
        )
    {
        require(_price != 0, "Price cant be zero");
        uint256 totalTokenSupply = inverseToken.totalSupply();
        uint256 balance = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getBalancePerToken()
        );
        uint256 cashPosition = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getCashPositionPerToken()
        );
        uint256 daysSinceLastRebalance = getDaysSinceLastRebalance();
        uint256 minRebalanceAmount = persistentStorage.minRebalanceAmount();

        return
            calculatePCF(
                cashPosition,
                balance,
                _price,
                _lendingFee,
                daysSinceLastRebalance,
                minRebalanceAmount
            );
    }

    /**
     * @dev Returns total cash position
     */
    function getTotalCashPosition()
        public
        view
        returns (uint256 totalCashPosition)
    {
        uint256 totalTokenSupply = inverseToken.totalSupply();
        totalCashPosition = DSMath.wmul(
            totalTokenSupply,
            persistentStorage.getCashPositionPerToken()
        );
    }
    function wmul(uint256 x, uint256 y) external pure returns (uint256 z) {
        z = DSMath.wmul(x, y);
    }

    function wdiv(uint256 x, uint256 y) external pure returns (uint256 z) {
        z = DSMath.wdiv(x, y);
    }

}