const { ethers } = require("ethers");
const assert = require('assert');
const { parseEther, formatEther } = ethers.utils;
require('dotenv').config();


const {
    balanceOfOZL, 
    getVarsForHelpers,
    sendETH,
    deploy,
    getOzelIndex,
    getRegulatorCounter,
    replaceForModVersion
} = require('../../scripts/helpers-arb.js');

const { 
    usdcAddr,
    fraxAddr,
    defaultSlippage,
} = require('../../scripts/state-vars.js');



let userDetails;
let callerAddr;
let ozelIndex;
let deployedDiamond;
let accounts, signers,regulatorCounter, higherIndex;
let iface, abi, selector;



/**
 * The test from below tests the stabilizing mechanism performed on updateIndex()
 * and balanceOf() which involves the main variable (Ozel Index) and its stabilizing
 * variables. 
 * 
 * It uses the ModExecutorFacet contract with hard-coded values in order to represent
 * a point in the future where the mechanism kicks in. 
 * 
 * The two main differences from the real implementation on ExecutorFacet is on
 * line 133, 136 140 (from the Mod version) that uses much lower values in order to
 * show the workings of the mechanism.
 */

 describe('Ozel Index', async function () { 
    this.timeout(100000000000000000000);

    before( async () => {
        const deployedVars = await deploy(); 
        ({
            deployedDiamond, 
            WETH,
            USDT,
            WBTC,
            renBTC,
            USDC,
            MIM,
            FRAX,
            crvTri,
            callerAddr, 
            caller2Addr,
            ozlFacet,
            yvCrvTri
        } = deployedVars);
    
        getVarsForHelpers(deployedDiamond, ozlFacet);

        userDetails = [
            callerAddr,
            fraxAddr,
            defaultSlippage
        ];

        abi = ['function updateExecutorState(uint256 amount_, address user_, uint256 lockNum_) external payable'];
        iface = new ethers.utils.Interface(abi);
        selector = iface.getSighash('updateExecutorState');
    });

    it('should successfully stabilize the index for OZL balances calculations / UpdateIndexV1 & balanceOf()', async () => {
        await replaceForModVersion('UpdateIndexV1', false, selector, userDetails, false, true);
        
        userDetails[1] = usdcAddr;
        accounts = await hre.ethers.provider.listAccounts();
        signers = await hre.ethers.getSigners();

        for (let i=5; i < accounts.length; i++) {
            await signers[i].sendTransaction({
                to: accounts[4],
                value: parseEther('9999')
            });
        }

        const bal4 = formatEther(await signers[4].getBalance());

        for (let i=0; i < 4; i++) {
            const balQ = bal4 / 4;
            await signers[4].sendTransaction({
                to: accounts[i],
                value: parseEther(i === 3 ? (balQ - 1).toString() : balQ.toString())
            });
        }

        console.log('.');
        console.log('*** stabilization happens in tx #16 ***');
        console.log('calculating...');
        
        for (let i=0, j=0; i < 19; i++, j++) { 
            console.log('.');
            console.log(`tx #${i}`);

            if (j == 4) j = 0;
            userDetails[0] = await signers[j].getAddress();

            await sendETH(userDetails, j); 

            ozelIndex = formatEther(await getOzelIndex());
            if (i === 0) higherIndex = ozelIndex;

            console.log('Ozel Index: ', ozelIndex);

            a = await balanceOfOZL(accounts[0]);
            console.log('OZL bal #0: ', a);
            b = await balanceOfOZL(accounts[1]);
            console.log('OZL bal #1: ', b);
            c = await balanceOfOZL(accounts[2]);
            console.log('OZL bal #2: ', c);
            d = await balanceOfOZL(accounts[3]);
            console.log('OZL bal #3: ', d);
            const total = a + b + c + d;
            console.log('TOTAL: ', total);

            regulatorCounter = await getRegulatorCounter();

            assert(total <= 100 && total >= 99.85);
            assert(ozelIndex > 0 && ozelIndex <= higherIndex);
            assert(regulatorCounter < 2 && regulatorCounter >= 0);
        }
    });



});