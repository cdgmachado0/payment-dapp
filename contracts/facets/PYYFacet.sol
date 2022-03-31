//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '../libraries/Helpers.sol';
import '../interfaces/ICrvLpToken.sol';
import '../interfaces/IWETH.sol';
import './ExecutorF.sol';
import './pyERC4626/pyERC4626.sol';
import '../interfaces/IYtri.sol';
import {ITri} from '../interfaces/ICurve.sol';

import 'hardhat/console.sol';




contract PYYFacet is pyERC4626 {

    using SafeERC20 for IERC20;


    function _getFee(uint amount_) public returns(uint, uint) {
        uint fee = amount_ - ExecutorF(s.executor).calculateSlippage(amount_, s.dappFee);
        s.feesVault += fee;
        uint netAmount = IWETH(s.WETH).balanceOf(address(this)) - fee;
        return (netAmount, fee);
    }

    function _delegateExecutor(int128 tokenIn_, int128 tokenOut_, IERC20 contractIn_) private { 
        (bool success, ) = s.executor.delegatecall(
            abi.encodeWithSignature(
                'executeFinalTrade(int128,int128,address)', 
                tokenIn_, tokenOut_, contractIn_
            )
        );
        require(success, 'PYYFacet: delegatecall to Executor failed');
    }

    function _delegateExecutor(
        int128 tokenIn_, 
        int128 tokenOut_, 
        address contractIn_, 
        address userToken_
    ) private returns(uint, string memory) { //<----- fails delegatecall but runs call
        console.log(14);
        console.log('s.executor: ', s.executor);
        (bool success, ) = s.executor.delegatecall(
            abi.encodeWithSignature(
                'executeFinalTrade(int128,int128,address,address)', 
                tokenIn_, tokenOut_, contractIn_, userToken_
            )
        );
        require(success, 'PYYFacet: delegatecall (overload) to Executor failed');
        return (0, "");
    }


    function swapsForUserToken(uint _amountIn, uint _baseTokenOut, address _userToken) public payable {
        uint minOut = ITri(s.tricrypto).get_dy(2, _baseTokenOut, _amountIn);
        uint slippage = ExecutorF(s.executor).calculateSlippage(minOut, s.slippageTradingCurve);
        IWETH(s.WETH).approve(s.tricrypto, _amountIn);
        ITri(s.tricrypto).exchange(2, _baseTokenOut, _amountIn, slippage, false);

        if (_userToken == s.renBTC) { 
            //renBTC: 1 / WBTC: 0
            _delegateExecutor(0, 1, IERC20(s.WBTC));

            // ExecutorF(s.executor).executeFinalTrade(0, 1, IERC20(s.WBTC));
        } else if (_userToken == s.MIM) {
            //MIM: 0 / USDT: 2 / USDC: 1
            _delegateExecutor(2, 0, IERC20(s.USDT));
            
            // ExecutorF(s.executor).executeFinalTrade(2, 0, IERC20(s.USDT));
        } else if (_userToken == s.USDC) {
            //USDC: 0 / USDT: 1
            _delegateExecutor(1, 0, IERC20(s.USDT));

            // ExecutorF(s.executor).executeFinalTrade(1, 0, IERC20(s.USDT));
        } else if (_userToken == s.FRAX){
            //FRAX: 0 / USDT: 2 / USDC: 1
            console.log(13);
            _delegateExecutor(2, 0, s.USDT, _userToken);

            // ExecutorF(s.executor).executeFinalTrade(2, 0, IERC20(s.USDT), _userToken);
        } 
    }

    /**
    BTC: 1 / USDT: 0 / WETH: 2
     */

    function exchangeToUserToken(address _user, address _userToken) external payable {
        uint baseTokenOut;

        IWETH(s.WETH).deposit{value: msg.value}();
        uint wethIn = IWETH(s.WETH).balanceOf(address(this));

        //deposits in ERC4626
        deposit(wethIn, _user);

        if (_userToken == s.WBTC || _userToken == s.renBTC) {
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
        
        //Deposits fees in Curve's renPool
        depositCurveYearn(fee);
    }

    
    //*********** From VaultFacet ***********/


    function withdrawUserShare(address user_, uint shares_, address userToken_) public { 
        IYtri(s.yTriPool).withdraw(IYtri(s.yTriPool).balanceOf(address(this)));

        uint assets = redeem(shares_, user_, user_);

        //tricrypto= USDT: 0 / crv2- USDT: 1 , USDC: 0 / mim- MIM: 0 , CRV2lp: 1
        uint tokenAmountIn = ITri(s.tricrypto).calc_withdraw_one_coin(assets, 0); 
        uint minOut = ExecutorF(s.executor).calculateSlippage(tokenAmountIn, s.slippageOnCurve);
        ITri(s.tricrypto).remove_liquidity_one_coin(assets, 0, minOut);

        if (userToken_ == s.USDC) { 
            ExecutorF(s.executor).executeFinalTrade(1, 0, IERC20(s.USDT));
        } else if (userToken_ == s.MIM) {
            ExecutorF(s.executor).executeFinalTrade(2, 0, IERC20(s.USDT));
        } else if (userToken_ == s.FRAX) {
            ExecutorF(s.executor).executeFinalTrade(2, 0, s.USDT, userToken_);
        }

        uint userTokens = IERC20(userToken_).balanceOf(address(this));

        (bool success, ) = userToken_.call(
            abi.encodeWithSignature(
                'transfer(address,uint256)', 
                user_, userTokens 
            ) 
        );
        require(success, 'VaultFacet: call transfer() failed'); 
    }


    function _calculateTokenAmountCurve(uint _wethAmountIn) private returns(uint, uint[3] memory) {
        uint[3] memory amounts;
        amounts[0] = 0;
        amounts[1] = 0;
        amounts[2] = _wethAmountIn;
        uint tokenAmount = ITri(s.tricrypto).calc_token_amount(amounts, true);
        return (tokenAmount, amounts);
    } 
    

    function depositCurveYearn(uint fee_) public payable {
        //Deposit WETH in Curve Tricrypto pool
        (uint tokenAmountIn, uint[3] memory amounts) = _calculateTokenAmountCurve(fee_);
        uint minAmount = ExecutorF(s.executor).calculateSlippage(tokenAmountIn, s.slippageOnCurve);
        IWETH(s.WETH).approve(s.tricrypto, tokenAmountIn);
        ITri(s.tricrypto).add_liquidity(amounts, minAmount);

        //Deposit crvTricrypto in Yearn
        IERC20(s.crvTricrypto).approve(s.yTriPool, IERC20(s.crvTricrypto).balanceOf(address(this)));
        IYtri(s.yTriPool).deposit(IERC20(s.crvTricrypto).balanceOf(address(this)));
    }

}