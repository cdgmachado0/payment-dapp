const { ethers } = require("ethers");
const assert = require('assert');
// const expect = require('chai').expect;
// const expect = require('expect');
const truffleAssert = require('truffle-assertions');

const { 
    parseEther, 
    formatEther, 
    defaultAbiCoder: abiCoder, 
    keccak256,
    id,
    hexZeroPad,
    hexStripZeros,
    arrayify
} = ethers.utils;
const { deploy } = require('../scripts/deploy.js');
const { Bridge } = require('arb-ts');
const { hexDataLength } = require('@ethersproject/bytes');
require('dotenv').config();



const {
    balanceOfPYY, 
    transferPYY, 
    withdrawSharePYY, 
    getVarsForHelpers,
    sendETH,
    getCalldata,
    getCalldata2
} = require('../scripts/helpers-arb.js');

const { 
    chainId,
    pokeMeOpsAddr,
    hopBridge,
    usdtAddrArb,
    wbtcAddr,
    renBtcAddr,
    usdcAddr,
    mimAddr,
    fraxAddr,
    inbox,
    signerX,
    l2Provider,
    l2Signer,
    l1Signer,
    wethAddr,
    defaultSlippage,
    gelatoAddr,
    ETH,
    swapRouterUniAddr,
    poolFeeUni,
    nullAddr,
    chainlinkAggregatorAddr,
    deadAddr
 } = require('../scripts/state-vars.js');

 const {
    deployContract,
    sendTx,
    getArbitrumParams,
    activateOzBeaconProxy,
    deploySystemOptimistically,
    errors,
    getEventParam,
    sendETHv2
 } = require('../scripts/helpers-eth');



let signerAddr, signerAddr2;
let ozERC1967proxyAddr, storageBeacon;
let userDetails;
let newProxyAddr, newProxy;
let balance;
let newUserToken, newUserSlippage;



 describe('Ethereum-side', async () => {
    before( async () => {
        const bridge = await Bridge.init(l1Signer, l2Signer);
        ([signerAddr, signerAddr2] = await hre.ethers.provider.listAccounts()); 
        console.log('signer address: ', signerAddr);

        userDetails = [
            signerAddr,
            usdtAddrArb,
            defaultSlippage
        ];
        ([ozERC1967proxyAddr, storageBeacon] = await deploySystemOptimistically(userDetails, signerAddr));
    });

    describe('ozBeaconProxy', async () => {
        it('should create a proxy successfully', async () => {
            await sendTx({
                receiver: ozERC1967proxyAddr,
                method: 'createNewProxy',
                args: [userDetails]
            });
            newProxyAddr = (await storageBeacon.getProxyByUser(signerAddr)).toString(); 
            console.log('Proxy #1: ', newProxyAddr);
            assert.equal(newProxyAddr.length, 42);
        });


        it('should have an initial balance of 0.01 ETH', async () => {
            await sendETHv2(newProxyAddr);
            balance = await hre.ethers.provider.getBalance(newProxyAddr);
            assert.equal(formatEther(balance), '0.01');
        });

        it('should have a final balance of 0 ETH', async () => {
            const ops = await hre.ethers.getContractAt('IOps', pokeMeOpsAddr);
            const taskId = await storageBeacon.getTaskID(signerAddr);
            console.log('task id: ', taskId);

            // const creator = await ops.taskCreator(taskId);
            // console.log('creaton: ', creator);
            
            await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [pokeMeOpsAddr],
            });

            const opsSigner = await hre.ethers.provider.getSigner(pokeMeOpsAddr);
            let iface = new ethers.utils.Interface(['function checker()']);
            const resolverData = iface.encodeFunctionData('checker');
            const resolverHash = await ops.connect(opsSigner).getResolverHash(newProxyAddr, resolverData);

            // console.log(1);
            // await opsSigner.sendTransaction({
            //     to: newProxyAddr,
            //     data
            // });
            // console.log(2);

            await hre.network.provider.request({
                method: "hardhat_stopImpersonatingAccount",
                params: [pokeMeOpsAddr],
            });


            await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [gelatoAddr],
            });

            const gelatoSigner = await hre.ethers.provider.getSigner(gelatoAddr);
            // const opsAbi = ['function uint256 _txFee, address _feeToken, address _taskCreator, bool __useTaskTreasuryFunds, bool _revertOnFailure, bytes32 __resolverHash, address _execAddress, bytes calldata _execData'];
            iface = new ethers.utils.Interface(['function sendToArb()']);
            const execData = iface.encodeFunctionData('sendToArb');
            await ops.connect(gelatoSigner).exec(0, ETH, ozERC1967proxyAddr, false, false, resolverHash, newProxyAddr, execData);

            await hre.network.provider.request({
                method: "hardhat_stopImpersonatingAccount",
                params: [gelatoAddr],
            });
            

            // await activateOzBeaconProxy(newProxyAddr);
            balance = await hre.ethers.provider.getBalance(newProxyAddr);
            assert.equal(formatEther(balance), 0);
        });

        xdescribe('fallback() / ozPayMe', async () => {
            it('should fail when re-calling / initialize()', async () => {
                await assert.rejects(async () => {
                    await sendTx({
                        receiver: newProxyAddr,
                        method: 'initialize',
                        args: [0, nullAddr]
                    });
                }, {
                    name: 'Error',
                    message: "VM Exception while processing transaction: reverted with reason string 'Initializable: contract is already initialized'"
                });
            });

            it('should allow the user to change userToken / changeUserToken()', async () => {
                receipt = await sendTx({
                    receiver: newProxyAddr,
                    method: 'changeUserToken',
                    args: [usdcAddr]
                });
                newUserToken = getEventParam(receipt);
                assert.equal(newUserToken, usdcAddr.toLowerCase());
            });

            it('should not allow an external user to change userToken / changeUserToken()', async () => {
                await assert.rejects(async () => {
                    await sendTx({
                        receiver: newProxyAddr,
                        method: 'changeUserToken',
                        args: [usdcAddr],
                        isSigner2: true
                    });
                }, {
                    name: 'Error',
                    message: "VM Exception while processing transaction: reverted with reason string 'ozPayMe: Not authorized'"
                });
            });

            it('should allow the user to change userSlippage / changeUserSlippage()', async () => {
                receipt = await sendTx({
                    receiver: newProxyAddr,
                    method: 'changeUserSlippage',
                    args: ['200']
                });
                newUserSlippage = getEventParam(receipt);
                assert.equal(arrayify(newUserSlippage), '200');
            });

            it('should not allow an external user to change userSlippage / changeUserSlippage()', async () => {
                await assert.rejects(async () => {
                    await sendTx({
                        receiver: newProxyAddr,
                        method: 'changeUserSlippage',
                        args: ['200'],
                        isSigner2: true
                    });
                }, {
                    name: 'Error',
                    message: "VM Exception while processing transaction: reverted with reason string 'ozPayMe: Not authorized'"
                });
            });



            it('should still send funds with userDetails even if malicious data was passed / sendToArb() - delegate()', async () => {
                // newProxy = await hre.ethers.getContractAt('ozBeaconProxy', newProxyAddr);
                varConfig = [0, 0, 0];
                userDetails = [deadAddr, deadAddr, 0];
                await sendETHv2(newProxyAddr);

                await sendTx({
                    receiver: newProxyAddr,
                    method: 'sendToArb',
                    isSigner2: true,
                    args: [varConfig, userDetails],
                    isEvil: true
                });

                balance = await hre.ethers.provider.getBalance(newProxyAddr);
                assert.equal(balance.toString(), 0);

                await storageBeacon.getUserByProxy(newProxyAddr);

            });



        });


    });

    


    


  

    xit('', async () => {
            
    });



  });