//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
// import {IRenPool, ITricrypto} from '../interfaces/ICurve.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './VaultFacet.sol';
import '../libraries/Helpers.sol';
import '../AppStorage.sol';
import '../interfaces/ICrvLpToken.sol';
import '../interfaces/IWETH.sol';
// import '../interfaces/IRen.sol';
import '../HelpersAbs.sol';

import 'hardhat/console.sol';

import './ERC4626Facet/ERC4626Facet.sol';




contract ManagerFacet is ERC4626Facet { 
    // AppStorage s; 

    using SafeERC20 for IERC20;
    // using Helpers for uint256;
    // using Helpers for address;


    // function updateIndex() private { 
    //     s.distributionIndex = 
    //         s.totalVolume != 0 ? ((1 ether * 10 ** 8) / s.totalVolume) : 0;
    // }

    // function modifyPaymentsAndVolumeExternally(address _user, uint _newAmount) external {
    //     s.usersPayments[_user] -= _newAmount;
    //     s.totalVolume -= _newAmount;
    //     updateIndex();
    // }

    // function updateManagerState(
    //     uint _amount, 
    //     address _user
    // ) public {
    //     s.usersPayments[_user] += _amount;
    //     s.totalVolume += _amount;
    //     updateIndex();
    // }

    function transferUserAllocation(address _sender, address _receiver, uint _amount) public {
        uint amountToTransfer = _getAllocationToTransfer(_amount, _sender);
        s.usersPayments[_sender] -= amountToTransfer;
        s.usersPayments[_receiver] += amountToTransfer;
    }

    function _getAllocationToTransfer(uint _amount, address _user) public returns(uint) {
        (bool success, bytes memory returnData) = address(s.PYY).delegatecall(
            abi.encodeWithSignature('balanceOf(address)', _user)
        );
        require(success);
        (uint balancePYY) = abi.decode(returnData, (uint));
        
        uint percentageToTransfer = (_amount * 10000) / balancePYY;
        return (percentageToTransfer * s.usersPayments[_user]) / 10000;
    }

    function _getFee(uint amount_) public returns(uint, uint) {
        uint fee = amount_ - calculateSlippage(amount_, s.dappFee);
        s.feesVault += fee;
        uint netAmount = s.WETH.balanceOf(address(this)) - fee;
        return (netAmount, fee);
    }

    function swapsForUserToken(uint _amountIn, uint _baseTokenOut, address _userToken) public payable {
        uint minOut = s.tricrypto.get_dy(2, _baseTokenOut, _amountIn);
        uint slippage = calculateSlippage(minOut, s.slippageTradingCurve);
        s.tricrypto.exchange(2, _baseTokenOut, _amountIn, slippage, false);

        if (_userToken == address(s.renBTC)) { 
            //renBTC: 1 / WBTC: 0
            executeFinalTrade(0, 1, s.WBTC);
        } else if (_userToken == address(s.MIM)) {
            //MIM: 0 / USDT: 2 / USDC: 1
            executeFinalTrade(2, 0, s.USDT);
        } else if (_userToken == address(s.USDC)) {
            //USDC: 0 / USDT: 1
            executeFinalTrade(1, 0, s.USDT);
        } else if (_userToken == address(s.FRAX)){
            //FRAX: 0 / USDT: 2 / USDC: 1
            executeFinalTrade(2, 0, s.USDT, _userToken);
        } 
    }

    /**
    BTC: 1 / USDT: 0 / WETH: 2
     */

    function exchangeToUserToken(address _user, address _userToken) external payable {
        // updateManagerState(msg.value, _user);
        uint baseTokenOut;

        s.WETH.deposit{value: msg.value}();
        uint wethIn = s.WETH.balanceOf(address(this));

        //deposits in ERC4626
        deposit(wethIn, _user);

        if (_userToken == address(s.WBTC) || _userToken == address(s.renBTC)) {
            baseTokenOut = 1;
        } else {
            baseTokenOut = 0;
        }

        //Sends fee to Vault contract
        (uint netAmountIn, uint fee) = _getFee(wethIn);
        
        //Swaps ETH to userToken (Base: USDT-WBTC / Route: MIM-USDC-renBTC-WBTC)  
        swapsForUserToken(netAmountIn, baseTokenOut, _userToken);
      
        //Sends userToken to user
        uint toUser = IERC20(_userToken).balanceOf(address(this));
        IERC20(_userToken).safeTransfer(_user, toUser);
        
        // s.WETH.deposit{value: fee}();

        //Deposits fees in Curve's renPool
        (bool success, ) = address(s.vault).delegatecall(
            abi.encodeWithSignature('depositCurveYearn(uint256)', fee)
        );
        require(success);
    }

}