//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './interfaces/IGatewayRegistry.sol';
import './interfaces/IGateway.sol';
import {IRenPool, ITricrypto} from './interfaces/ICurve.sol';
// import './interfaces/IERC20.sol';



contract PayMe2 {

    IGatewayRegistry public registry;
    IRenPool renPool = IRenPool(0x93054188d876f558f4a66B2EF1d97d16eDf0895B); // arb: 0x3E01dD8a5E1fb3481F0F589056b428Fc308AF0Fb
    ITricrypto tricrypto = ITricrypto(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46); //arb: 0x960ea3e3C7FB317332d990873d354E18d7645590
    uint priceImpact = 0.05 * 10 ** 8;

    event Deposit(uint amount, bytes msg);
    event Withdrawal(bytes _to, uint256 _amount, bytes _msg);

    constructor(address _registry) {
        registry = IGatewayRegistry(_registry);
    }

    /** 
    i = toke in - 0 renBTC
    j = token out - 1 wBTC
    dx = amount
    min = slippage
    */
    function exchangeToWETH(uint _amount) private {
        uint slippage = _amount - (_amount * priceImpact);
        renPool.exchange(0, 1, _amount, slippage);
        


    }


    function deposit(
        bytes calldata _msg,
        uint _amount,
        bytes32 _nHash,
        bytes calldata _sig
    ) external {
        bytes32 pHash = keccak256(abi.encode(_msg));
        IGateway BTCGateway = registry.getGatewayBySymbol('BTC');
        BTCGateway.mint(pHash, _amount, _nHash, _sig);
        emit Deposit(_amount, _msg);
    }

    function withdraw(bytes calldata _msg, bytes calldata _to, uint256 _amount) external {
        uint256 burnedAmount = registry.getGatewayBySymbol("BTC").burn(_to, _amount);
        emit Withdrawal(_to, burnedAmount, _msg);
    }

    
} //delete the 'msg' params, add integration to arbitrum, trade in Curve