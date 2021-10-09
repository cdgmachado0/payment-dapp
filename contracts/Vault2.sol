// //SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.0;


// import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
// import {IRenPool, ITricrypto} from './interfaces/ICurve.sol';
// import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

// import 'hardhat/console.sol';



// contract Vault {

//     using SafeERC20 for IERC20;

//     IRenPool renPool = IRenPool(0x93054188d876f558f4a66B2EF1d97d16eDf0895B); 
//     ITricrypto tricrypto2 = ITricrypto(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
//     IERC20 renBTC = IERC20(0xEB4C2781e4ebA804CE9a9803C67d0893436bB27D);
//     IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
//     IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
//     IERC20 WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
//     address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

//     uint dappFee = 10;
//     uint totalVolume = 0;

//     mapping(address => bool) users;
//     mapping(address => uint) pendingWithdrawal;
//     mapping(address => uint) usersPayments;



//     function _calculateAfterPercentage(
//         uint _amount, 
//         uint _basisPoint
//     ) public pure returns(uint result) {
//         result = _amount - ( (_amount * _basisPoint) / 10000 ); //5 -> 0.05%;
//     }

//     function _calculateFeeAllocationPercentage(
//         uint _amount, 
//         address _user
//     ) public returns(uint userAllocation) {
//         usersPayments[_user] += _amount;
//         totalVolume += _amount;
//         userAllocation = ( (usersPayments[_user] * 10000) / totalVolume ) * 1 ether;
//     }

//     function _bytesToAddress(bytes memory bys) public pure returns (address addr) {
//         assembly {
//             addr := mload(add(bys,20))
//         } 
//     }

//     function _preSending(address _user) private {
//         pendingWithdrawal[_user] = address(this).balance;
//     }

//     function _sendEtherToUser(address _user) public {
//         _preSending(_user);
//         uint amount = pendingWithdrawal[_user];
//         pendingWithdrawal[_user] = 0;
//         payable(_user).transfer(amount);
//     }

//     function _sendsFeeToVault(uint _amount, address _payme) public returns(uint, bool) {
//         uint fee = _amount - _calculateAfterPercentage(_amount, dappFee); //10 -> 0.1%
//         uint netAmount = _amount - fee;
//         bool isTransferred = renBTC.transferFrom(_payme, address(this), fee);
//         return (netAmount, isTransferred);
//     }

//     function exchangeToUserToken(uint _amount, address _user, address _userToken, address _payme) public {
//         uint userAllocation = _calculateFeeAllocationPercentage(_amount, _user);

//         // Sends fee to Vault contract
//         // renBTC.approve(address(this), type(uint).max);
//         (uint netAmount, bool isTransferred) = _sendsFeeToVault(_amount, _payme);
//         require(isTransferred, 'Fee transfer failed');
        
//         uint tokenOut = _userToken == address(USDT) ? 0 : 2;
//         bool useEth = _userToken == address(WETH) ? false : true;
//         IERC20 userToken;
//         uint slippage;
//         if (_userToken != ETH) {
//             userToken = IERC20(_userToken);
//         }

//         //Swaps renBTC for WBTC
//         renBTC.approve(address(renPool), netAmount); 
//         slippage = _calculateAfterPercentage(netAmount, 5);
//         renPool.exchange(0, 1, netAmount, slippage);
//         uint wbtcToConvert = WBTC.balanceOf(address(this));

//         //Swaps WBTC to userToken (USDT, WETH or ETH)
//         WBTC.approve(address(tricrypto2), wbtcToConvert);
//         uint minOut = tricrypto2.get_dy(1, tokenOut, wbtcToConvert);
//         slippage = _calculateAfterPercentage(minOut, 5);
//         tricrypto2.exchange(1, tokenOut, wbtcToConvert, slippage, useEth);    

//         //Sends userToken to user
//         if (_userToken != ETH) {
//             uint ToUser = userToken.balanceOf(address(this));
//             userToken.safeTransfer(_user, ToUser);
//         } else {
//             _sendEtherToUser(_user);
//         }
//     }


// }