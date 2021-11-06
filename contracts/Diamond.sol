// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import { LibDiamond } from "./libraries/LibDiamond.sol";
import { IDiamondCut } from "./interfaces/IDiamondCut.sol";

import { IDiamondLoupe } from "./interfaces/IDiamondLoupe.sol";
import { IERC173 } from "./interfaces/IERC173.sol";

import './facets/DummyFacet.sol';

import 'hardhat/console.sol';

contract Diamond {    

    // constructor(address _contractOwner, address _diamondCutFacet) payable {        
    //     LibDiamond.setContractOwner(_contractOwner); 

    //     // Add the diamondCut external function from the diamondCutFacet
    //     IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
    //     bytes4[] memory functionSelectors = new bytes4[](1);
    //     functionSelectors[0] = IDiamondCut.diamondCut.selector; //---> msg.sig problematic
    //     cut[0] = IDiamondCut.FacetCut({
    //         facetAddress: _diamondCutFacet, 
    //         action: IDiamondCut.FacetCutAction.Add, 
    //         functionSelectors: functionSelectors
    //     });
    //     LibDiamond.diamondCut(cut, address(0), "");        
    // }


    // constructor(
    //     address _contractOwner, 
    //     address _diamondCutFacet,
    //     bytes4[] memory _selectDummy, 
    //     address _dummyFacet,
    //     address _init,
    //     bytes memory _calldata
    // ) payable {        
    //     LibDiamond.setContractOwner(_contractOwner);

    //     // Add the diamondCut external function from the diamondCutFacet
    //     IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);
    //     bytes4[] memory functionSelectors = new bytes4[](1);
    //     functionSelectors[0] = IDiamondCut.diamondCut.selector; //---> msg.sig problematic
    //     cut[0] = IDiamondCut.FacetCut({
    //         facetAddress: _diamondCutFacet, 
    //         action: IDiamondCut.FacetCutAction.Add, 
    //         functionSelectors: functionSelectors
    //     });

    //     functionSelectors = new bytes4[](2);
    //     functionSelectors[0] = _selectDummy[0];
    //     functionSelectors[1] = _selectDummy[1];
    //     cut[1] = IDiamondCut.FacetCut({
    //         facetAddress: _dummyFacet, 
    //         action: IDiamondCut.FacetCutAction.Add, 
    //         functionSelectors: functionSelectors
    //     });
        
    //     LibDiamond.diamondCut(cut, address(0), "");        
    // }



    constructor(IDiamondCut.FacetCut[] memory _diamondCut, address _contractOwner, bytes memory _calldata, address _init) payable {        
        LibDiamond.diamondCut(_diamondCut, address(0), new bytes(0));
        console.log('owner2: ', _contractOwner);
        LibDiamond.setContractOwner(_contractOwner);

        (bool success, ) = _init.delegatecall(_calldata);
        require(success, 'Diamond: Init failed');

        // LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        // for (uint i; i < _facets.selectors.length; i++) {
        //     bytes4[] memory selectors = _facets.selectors[i];
        //     for (uint j; j < selectors.length; j++) {
        //         ds.facets[selectors[j]] = _facets.addresses[i];
        //     }
        // }

        // ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        // ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        // ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        // ds.supportedInterfaces[type(IERC173).interfaceId] = true;



    }




    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable { 
        console.log('msg.sig: ');
        console.logBytes4(msg.sig);
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = ds.facets[msg.sig];
        console.log('facet: ', facet);
        require(facet != address(0), "Diamond: Function does not exist");
        // revert('yeeeeeiiiiii');
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {}
}
