// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;


import './AppStorage.sol';

import 'hardhat/console.sol';


abstract contract Bits {

    AppStorage s;

    function _getBit(uint bitmap_, uint index_) internal view returns(bool) {
        uint bit = s.bitLocks[bitmap_] & (1 << index_);
        return bit > 0;
    }

    function _toggleBit(uint bitmap_, uint index_) internal {
        s.bitLocks[bitmap_] ^= (1 << index_);
    }

    function set(uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        s.bitLocks[bucket] |= mask;
    }
}