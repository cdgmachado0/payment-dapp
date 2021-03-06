// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.14; 


import '@rari-capital/solmate/src/utils/ReentrancyGuard.sol';
import '@rari-capital/solmate/src/utils/SafeTransferLib.sol';
import '@rari-capital/solmate/src/tokens/ERC20.sol';
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '../../libraries/FixedPointMathLib.sol';
import '../../interfaces/DelayedInbox.sol';
import '../../interfaces/IOps.sol';
import '../FakeOZL.sol';
import '../Emitter.sol';
import '../StorageBeacon.sol';
import '../ozUpgradeableBeacon.sol';
import '../../Errors.sol';

import 'hardhat/console.sol';




contract FaultyOzPayMe is ReentrancyGuard, Initializable { 
    using FixedPointMathLib for uint;

    StorageBeacon.UserConfig userDetails;
    StorageBeacon.FixedConfig fxConfig;

    address private _beacon;

    event FundsToArb(address indexed sender, uint amount);
    event EmergencyTriggered(address indexed sender, uint amount);
    event NewUserToken(address indexed user, address indexed newToken);
    event NewUserSlippage(address indexed user, uint indexed newSlippage);

    //Custom event that checks for the second attempt on EmergencyMode
    event SecondAttempt(uint success);


    modifier onlyOps() {
        require(msg.sender == fxConfig.ops, 'ozPayMe: onlyOps');
        _;
    }

    modifier onlyUser() {
        require(msg.sender == userDetails.user, 'ozPayMe: Not authorized');
        _;
    }

    function initialize(
        uint userId_, 
        address beacon_
    ) external initializer {
        userDetails = StorageBeacon(_getStorageBeacon(beacon_, 0)).getUserDetailsById(userId_);  
        fxConfig = StorageBeacon(_getStorageBeacon(beacon_, 0)).getFixedConfig();
        _beacon = beacon_;
    }


    function _getStorageBeacon(address beacon_, uint version_) private view returns(address) { 
        return ozUpgradeableBeacon(beacon_).storageBeacon(version_);
    }


    function sendToArb( 
        StorageBeacon.VariableConfig memory varConfig_,
        StorageBeacon.UserConfig memory userDetails_
    ) external payable onlyOps { 
        StorageBeacon storageBeacon = StorageBeacon(_getStorageBeacon(_beacon, 0)); 

        if (userDetails_.user == address(0) || userDetails_.userToken == address(0)) revert CantBeZero('address');
        if (!storageBeacon.isUser(userDetails_.user)) revert NotFoundInDatabase('user');
        if (userDetails_.userSlippage <= 0) revert CantBeZero('slippage');
        if (!(address(this).balance > 0)) revert CantBeZero('contract balance');

        (uint fee, ) = IOps(fxConfig.ops).getFeeDetails();
        _transfer(fee, fxConfig.ETH);

        bool isEmergency;

        bytes memory swapData = abi.encodeWithSelector(
            FakeOZL(payable(fxConfig.OZL)).exchangeToUserToken.selector, 
            userDetails_
        );

        bytes memory ticketData = abi.encodeWithSelector(
            DelayedInbox(fxConfig.inbox).createRetryableTicket.selector, 
            fxConfig.OZL, 
            address(this).balance - varConfig_.autoRedeem,
            varConfig_.maxSubmissionCost,  
            fxConfig.OZL, 
            fxConfig.OZL, 
            fxConfig.maxGas,  
            varConfig_.gasPriceBid, 
            swapData
        );

        uint amountToSend = address(this).balance;
        (bool success, bytes memory returnData) = fxConfig.inbox.call{value: address(this).balance}(ticketData);
        if (!success) {
            (success, returnData) = fxConfig.inbox.call{value: address(this).balance}(ticketData); 
            if (!success) { 
                _runEmergencyMode();
                isEmergency = true;
                emit EmergencyTriggered(userDetails_.user, amountToSend);
            }
        }

        if (!isEmergency) {
            if (!storageBeacon.getEmitterStatus()) { 
                uint ticketID = abi.decode(returnData, (uint));
                Emitter(fxConfig.emitter).forwardEvent(ticketID); 
            }
            emit FundsToArb(userDetails_.user, amountToSend);
        }
    }


    function _calculateMinOut(StorageBeacon.EmergencyMode memory eMode_, uint i_) private view returns(uint minOut) {
        (,int price,,,) = eMode_.priceFeed.latestRoundData();
        uint expectedOut = address(this).balance.mulDivDown(uint(price) * 10 ** 10, 1 ether);
        uint minOutUnprocessed = expectedOut - expectedOut.mulDivDown(userDetails.userSlippage * i_ * 100, 1000000); 
        minOut = minOutUnprocessed.mulWadDown(10 ** 6);
    }



    function _runEmergencyMode() private nonReentrant { 
        StorageBeacon.EmergencyMode memory eMode = StorageBeacon(_getStorageBeacon(_beacon, 0)).getEmergencyMode();

        for (uint i=1; i <= 2;) {
            ISwapRouter.ExactInputSingleParams memory params =
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: eMode.tokenIn,
                    tokenOut: eMode.tokenOut,
                    fee: eMode.poolFee,
                    recipient: userDetails.user,
                    deadline: block.timestamp,
                    amountIn: i == 1 ? 0 : address(this).balance,
                    amountOutMinimum: _calculateMinOut(eMode, i), 
                    sqrtPriceLimitX96: 0
                });

            //Gives faulty params to this function so it fails the first time and executes the second
            try eMode.swapRouter.exactInputSingle{value: address(this).balance}(params) {
                break;
            } catch {
                if (i == 1) {
                    unchecked { ++i; }
                    emit SecondAttempt(23);
                    continue; 
                } else {
                    (bool success, ) = payable(userDetails.user).call{value: address(this).balance}('');
                    if (!success) revert CallFailed('ozPayMe: Emergency ETH transfer failed');
                    unchecked { ++i; }
                }
            }
        } 
    }


    function _transfer(uint256 _amount, address _paymentToken) private {
        if (_paymentToken == fxConfig.ETH) {
            (bool success, ) = fxConfig.gelato.call{value: _amount}("");
            if (!success) revert CallFailed("_transfer: ETH transfer failed");
        } else {
            SafeTransferLib.safeTransfer(ERC20(_paymentToken), fxConfig.gelato, _amount); 
        }
    }


    function changeUserToken(address newUserToken_) external onlyUser {
        userDetails.userToken = newUserToken_;
        emit NewUserToken(msg.sender, newUserToken_);
    }

    function changeUserSlippage(uint newUserSlippage_) external onlyUser {
        userDetails.userSlippage = newUserSlippage_;
        emit NewUserSlippage(msg.sender, newUserSlippage_);
    } 
    
    
}







