//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IRenPool, ITricrypto} from '../interfaces/ICurve.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './VaultFacet.sol';
import '../libraries/Helpers.sol';
import '../interfaces/ICrvLpToken.sol';

import '../AppStorage.sol';

import 'hardhat/console.sol';

// import {Exchange} from '../libraries/Helpers.sol';
import {Getters} from '../AppStorage.sol';





contract ManagerFacet { 
    AppStorage s; 

    using SafeERC20 for IERC20;
    using Helpers for uint256;
    using Helpers for address;

    // function getVar() external view {
    //     console.log('renBTC addr***: ', address(s.renBTC));
    // }



    function updateIndex() private {
        s.distributionIndex = ((1 ether * 10 ** 8) / s.totalVolume);
    }

    function modifyPaymentsAndVolumeExternally(address _user, uint _newAmount) external {
        s.usersPayments[_user] -= _newAmount;
        s.totalVolume -= _newAmount;
        updateIndex();
    }

    function updateManagerState(
        uint _amount, 
        address _user
    ) public {
        s.usersPayments[_user] += _amount;
        s.totalVolume += _amount;
        updateIndex();
    }

    function transferUserAllocation(address _sender, address _receiver, uint _amount) public {
        uint amountToTransfer = _getAllocationToTransfer(_amount, _sender);
        s.usersPayments[_sender] -= amountToTransfer;
        s.usersPayments[_receiver] += amountToTransfer;
    }

    function _getAllocationToTransfer(uint _amount, address _user) public view returns(uint) {
        uint percentageToTransfer = (_amount * 10000) / s.PYY.balanceOf(_user);
        return (percentageToTransfer * s.usersPayments[_user]) / 10000;
    }

    function _bytesToAddress(bytes memory _bytes) public pure returns (address addr) {
        assembly {
            addr := mload(add(_bytes,20))
        } 
    }

    function _preSending(address _user) private {
        s.pendingWithdrawal[_user] = address(this).balance;
    }

    function _sendEtherToUser(address _user) public {
        _preSending(_user);
        uint amount = s.pendingWithdrawal[_user];
        s.pendingWithdrawal[_user] = 0;
        payable(_user).transfer(amount);
    }

    function _getFee(uint _amount) public returns(uint, bool) {
        uint fee = _amount - _amount._calculateSlippage(s.dappFee); //10 -> 0.1%
        bool isTransferred = s.WBTC.transfer(address(s.vault), fee);
        uint netAmount = s.WBTC.balanceOf(address(this));
        return (netAmount, isTransferred);
    }


    /***** Helper swapping functions ******/
    function swapsRenForWBTC(uint _netAmount) public returns(uint wbtcAmount) {
        console.log(13);
        console.log('msg.sender: ', msg.sender);
        console.log('address(this): ', address(this));
        console.log(15);
        s.renBTC.approve(address(s.renPool), _netAmount); //original ***

        // (bool x, ) = address(s.renBTC).call(
        //     abi.encodeWithSignature(
        //         'approve(address,uint256)', 
        //         address(s.renPool), _netAmount
        //     )
        // );
        // require(x, 'filll');

        console.log('allowance: ', s.renBTC.allowance(address(s.manager), address(s.renPool)));

        console.log(14);
        uint slippage = _netAmount._calculateSlippage(5); //pass this as a general variable to the Diamond
        console.log(11);
        revert('hereeee');

        s.renPool.exchange(0, 1, _netAmount, slippage);
        
        console.log(12);
        wbtcAmount = s.WBTC.balanceOf(address(this));
    }

    function swapsWBTCForUserToken(uint _wbtcToConvert, uint _tokenOut, bool _useEth) public {
        s.WBTC.approve(address(s.tricrypto), _wbtcToConvert);
        uint minOut = s.tricrypto.get_dy(1, _tokenOut, _wbtcToConvert);
        uint slippage = minOut._calculateSlippage(5);
        s.tricrypto.exchange(1, _tokenOut, _wbtcToConvert, slippage, _useEth);
    }
    /*****************/

    


    function exchangeToUserToken(uint _amount, address _user, address _userToken) public {
        updateManagerState(_amount, _user);

        // (bool x, ) = address(s.getters).call(
        //     abi.encodeWithSignature('getVar(uint256)', _amount)
        // );
        // require(x, 'sss');
        
        uint tokenOut = _userToken == address(s.USDT) ? 0 : 2;
        bool useEth = _userToken == address(s.WETH) ? false : true;
        IERC20 userToken;
        if (_userToken != s.ETH) {
            userToken = IERC20(_userToken);
        }
        console.log(1);
        //Swaps renBTC for WBTC
        uint wbtcAmount = swapsRenForWBTC(_amount);
        // uint wbtcAmount = 1;
        // (bool x, ) = address(Helpers).delegatecall(
        //     abi.encodeWithSignature('swapsRenForWBTC(uint256)', _amount)
        // );
        // require(x, 'ffff');

        console.log(2);
        //Sends fee (in WBTC) to Vault contract
        (uint netAmount, bool isTransferred) = _getFee(wbtcAmount);
        require(isTransferred, 'Fee transfer failed');
        console.log(3);
        //Swaps WBTC to userToken (USDT, WETH or ETH)  
        swapsWBTCForUserToken(netAmount, tokenOut, useEth);
        console.log(4);
        //Sends userToken to user
        if (_userToken != s.ETH) {
            uint ToUser = userToken.balanceOf(address(this));
            userToken.safeTransfer(_user, ToUser);
        } else {
            _sendEtherToUser(_user);
        }
        console.log(5);
        //Deposits fees in Curve's renPool
        s.vault.depositInCurve();
        
    }


}