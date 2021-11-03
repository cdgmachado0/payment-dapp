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

    struct ConstructorArgs {
        address owner;
        address ghstContract;
        address uniV2PoolContract;
    }


    constructor(IDiamondCut.FacetCut[] memory _diamondCut, ConstructorArgs memory _args) payable {        
        LibDiamond.diamondCut(_diamondCut, address(0), '');
        console.log('owner: ', _args.owner);
        console.log('ghstContract: ', _args.ghstContract);
        console.log('uni: ', _args.uniV2PoolContract);
        revert('revert in constructor');
    }



    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable { 
        console.log('msg.sender: ', msg.sender);
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
        revert('yeeeeeiiiiii');
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