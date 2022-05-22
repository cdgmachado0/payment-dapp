//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import '../interfaces/IL1_ETH_Bridge.sol';
import '../interfaces/DelayedInbox.sol';
import './FakePYY.sol';
import './Emitter.sol';

import 'hardhat/console.sol'; 

import '../interfaces/IOps.sol';

import './StorageBeacon.sol';
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import './ozUpgradeableBeacon.sol';



contract PayMeFacetHop is Initializable {

    // struct UserConfig {
    //     address user;
    //     address userToken;
    //     uint userSlippage; 
    // }

    // struct VariableConfig {
    //     uint maxSubmissionCost;
    //     uint gasPriceBid;
    //     uint autoRedeem;
    // }


    StorageBeacon.UserConfig userDetails;
    StorageBeacon.FixedConfig fxConfig;

    // address ETH;
    // address beacon; 


    modifier onlyOps() {
        require(msg.sender == fxConfig.ops, "OpsReady: onlyOps");
        _;
    }


    function initialize(
        uint userId_, 
        address beacon_
        // address eth_
    ) external initializer {
        userDetails = _getStorageBeacon(beacon_).getUserById(userId_);         
        fxConfig = _getStorageBeacon(beacon_).getFixedConfig();
        // beacon = beacon_;
        // ETH = eth_;
    }


    function _getStorageBeacon(address beacon_) private view returns(StorageBeacon) { 
        return StorageBeacon(ozUpgradeableBeacon(beacon_).storageBeacon());
    }


    function sendToArb( 
        StorageBeacon.VariableConfig memory varConfig_,
        StorageBeacon.UserConfig memory userDetails_
    ) external payable onlyOps { //onlyOps
        address inbox = fxConfig.inbox;
        address PYY = fxConfig.PYY;
        address emitter = fxConfig.emitter;
        address opsGel = fxConfig.ops;
        address ETH = fxConfig.ETH;
        uint maxGas = fxConfig.maxGas;

        uint maxSubmissionCost = varConfig_.maxSubmissionCost;
        uint gasPriceBid = varConfig_.gasPriceBid;
        uint autoRedeem = varConfig_.autoRedeem;

        (uint fee, ) = IOps(opsGel).getFeeDetails();
        _transfer(fee, ETH);

        bytes memory swapData = abi.encodeWithSelector(
            FakePYY(payable(PYY)).exchangeToUserToken.selector, 
            userDetails_
        );

        bytes memory ticketData = abi.encodeWithSelector(
            DelayedInbox(inbox).createRetryableTicket.selector, 
            PYY, 
            address(this).balance - autoRedeem, 
            maxSubmissionCost,  
            PYY, 
            PYY, 
            maxGas,  
            gasPriceBid, 
            swapData
        );

        (bool success, bytes memory returnData) = inbox.call{value: address(this).balance}(ticketData);
        require(success, 'PayMeFacetHop: retryable ticket failed');
        uint ticketID = abi.decode(returnData, (uint));

        Emitter(emitter).forwardEvent(ticketID); 
    }



    function _transfer(uint256 _amount, address _paymentToken) internal {
        address gelato = fxConfig.gelato;
        address ETH = fxConfig.ETH;

        if (_paymentToken == ETH) {
            (bool success, ) = gelato.call{value: _amount}("");
            require(success, "_transfer: ETH transfer failed");
        } else {
            SafeERC20.safeTransfer(IERC20(_paymentToken), gelato, _amount);
        }
    }

}





