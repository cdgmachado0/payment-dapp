// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;


import './AppStorage.sol';
import '../Errors.sol';
import './Bits.sol';

import 'hardhat/console.sol';



abstract contract Modifiers is Bits {

    modifier noReentrancy(uint index_) { 
        if (!(_getBit(0, index_))) revert NoReentrance();
        _toggleBit(0, index_);
        _;
        _toggleBit(0, index_);
    }

    modifier isAuthorized(uint index_) {
        if (_getBit(1, index_)) revert NotAuthorized();
        _;
        _toggleBit(1, index_);
    }

    modifier onlyWhenEnabled() {
        require(s.isEnabled, 'Operation not enabled');
        _;
    }

    modifier filterDetails(UserConfig memory userDetails_) {
        if (userDetails_.user == address(0) || userDetails_.userToken == address(0)) revert CantBeZero('address'); 
        if (userDetails_.userSlippage <= 0) revert CantBeZero('slippage');
        if (!s.tokenDatabase[userDetails_.userToken]) revert NotFoundInDatabase('token');
        _;
    }
}