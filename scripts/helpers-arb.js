const diamond = require('diamond-util');
const assert = require('assert');
const { getSelectors } = require('./libraries/diamond.js');
const { defaultAbiCoder: abiCoder, formatEther, keccak256, toUtf8Bytes } = ethers.utils;
const { MaxUint256 } = ethers.constants;

const {
    wethAddr,
    tricryptoAddr,
    usdtAddrArb,
    crvTricrypto,
    wbtcAddr,
    renBtcAddr,
    renPoolAddr,
    usdcAddr,
    mimAddr,
    fraxAddr,
    mimPoolAddr,
    crv2PoolAddr,
    yTricryptoPoolAddr,
    fraxPoolAddr,
    ETH,
    dappFee,
    tokenName,
    tokenSymbol,
    defaultSlippage,
    nullAddr,
    chainlinkAggregatorAddr,
    swapRouterUniAddr,
    poolFeeUni,
    revenueAmounts,
    diamondABI,
    usxAddr
} = require('./state-vars.js');


let deployedDiamond;
let ozlFacet;
let OZLDiamond;


async function getVarsForHelpers(diamond, ozl) { 
    deployedDiamond = diamond;
    ozlFacet = ozl;
    OZLDiamond = await hre.ethers.getContractAt(diamondABI, diamond.address);
}


async function enableWithdrawals(state) {
    await OZLDiamond.enableWithdrawals(state);
}


async function balanceOfOZL(user) {
    return Number(formatEther(await OZLDiamond.balanceOf(user)));
}

async function transferOZL(recipient, amount, signerIndex = 0) { 
    const signers = await hre.ethers.getSigners();
    const signer = signers[signerIndex];
    const tx = await OZLDiamond.connect(signer).transfer(recipient, amount);
    const receipt = await tx.wait();
    return receipt;
}

async function withdrawShareOZL(userDetails, receiverAddr, balanceOZL, signerIndex = 0) {  
    const signers = await hre.ethers.getSigners();
    const signer = signers[signerIndex ? 0 : signerIndex];
    await OZLDiamond.connect(signer).withdrawUserShare(userDetails, receiverAddr, balanceOZL);
} 


//Sends ETH to contracts (simulates ETH bridging) **** MAIN FUNCTION ****
async function sendETH(userDetails, signerIndex = 0) {
    const signers = await hre.ethers.getSigners();
    const signer = signers[signerIndex ? 0 : signerIndex];
    const value = ethers.utils.parseEther(signerIndex === 'no value' ? '0' : '100');
    const tx = await OZLDiamond.connect(signer).exchangeToUserToken(userDetails, { value });
    const receipt = await tx.wait();
    return receipt;
}


async function getOzelIndex() {
    const tx = await OZLDiamond.getOzelIndex();
    const receipt = await tx.wait();
    const { data } = receipt.logs[0];
    [ decodedData ] = abiCoder.decode(['uint256'], data);
    return decodedData;
}

async function addTokenToDatabase(tokenSwap, signerIndex = 0) {
    const signers = await hre.ethers.getSigners();
    const signer = signers[signerIndex];
    await OZLDiamond.connect(signer).addTokenToDatabase(tokenSwap);
}


async function getCalldata(method, params) {
    const signatures = {
        exchangeToUserToken: 'function exchangeToUserToken(tuple(address user, address userToken, uint userSlippage) userDetails_)',
        sendToArb: 'function sendToArb(tuple(address user, address userToken, uint userSlippage) userDetails_, uint256 _callvalue) returns (uint256)'
    };
    const abi = [];
    abi.push(signatures[method]);
    const iface = new ethers.utils.Interface(abi);
    const data = iface.encodeFunctionData(method, params);
    return data;
} 

async function getRegulatorCounter() {
    const tx = await OZLDiamond.getRegulatorCounter();
    const receipt = await tx.wait();
    const { data } = receipt.logs[0];
    [ decodedData ] = abiCoder.decode(['uint256'], data);
    return decodedData;
}


function getTestingNumber(receipt, isSecond = false) {
    const testNum = isSecond ? 24 : 23;
    topics = receipt.logs.map(log => log.topics);

    for (let i=0; i < topics.length; i++) { 
        num = topics[i].filter(hash => {
            val = Number(abiCoder.decode(['uint'], hash));
            if (val === testNum) return val;
        });
        if (Number(num) === testNum) return Number(num);
    }
}


async function replaceForModVersion(contractName, checkUSDTbalance, selector, userDetails, checkERC = false, isIndex = false) {
    function whichERC20() {
        switch(checkERC) {
            case true:
                return WETH;
            case false:
                return USDT;
            case 2:
                return WBTC;
            case 3:
                return renBTC;
            case 4:
                return MIM;
            case 5:
                return FRAX;
        }
    }
    const USDT = await hre.ethers.getContractAt('IERC20', usdtAddrArb);
    const WETH = await hre.ethers.getContractAt('IERC20', wethAddr);
    const WBTC = await hre.ethers.getContractAt('IERC20', wbtcAddr);
    const renBTC = await hre.ethers.getContractAt('IERC20', renBtcAddr);
    const MIM = await hre.ethers.getContractAt('IERC20', mimAddr);
    const FRAX = await hre.ethers.getContractAt('IERC20', fraxAddr);
    const [callerAddr] = await hre.ethers.provider.listAccounts();
    let stringToHash;

    const USDC = await hre.ethers.getContractAt('IERC20', usdcAddr);

    modContract = typeof contractName === 'string' ? await deployFacet(contractName) : contractName;
       
    if (contractName === 'ComputeRevenueV1' || contractName === 'ComputeRevenueV2' || contractName === 'ComputeRevenueV3') {
        const iface = new ethers.utils.Interface(diamondABI);
        const selectorTESTVAR = iface.getSighash('setTESTVAR2');

        if (contractName === 'ComputeRevenueV1') {
            await OZLDiamond.diamondCut(
                [[ modContract.address, 0, [selectorTESTVAR] ]],
                nullAddr,
                '0x'
            );
        }

        if (contractName === 'ComputeRevenueV1') {
            stringToHash = 'testvar2.position';
        } else if (contractName === 'ComputeRevenueV2') {
            stringToHash = 'testvar2.second.position';
        } else if (contractName === 'ComputeRevenueV3') {
            stringToHash = 'testvar2.third.position';
        }

        let position = keccak256(toUtf8Bytes(stringToHash)); 
        await OZLDiamond.setTESTVAR2(1, position);
    }
    
    faceCutArgs = [[ modContract.address, 1, [selector] ]]; 
    
    if (checkUSDTbalance) {
        balance = await USDT.balanceOf(callerAddr);
        assert.equal(balance, 0);
    };

    await OZLDiamond.diamondCut(faceCutArgs, nullAddr, '0x');

    if (!isIndex) {
        receipt = await sendETH(userDetails); 
        testingNum = getTestingNumber(receipt);
        balance = await (whichERC20()).balanceOf(callerAddr);

        return {
            testingNum,
            balance,
            receipt,
            modContract
        };        
    }
}


async function queryTokenDatabase(token) {
    return await OZLDiamond.queryTokenDatabase(token);
}


//------ From deploy.js ---------

async function deployFacet(facetName) { 
    const Contract = await hre.ethers.getContractFactory(facetName);
    const contract = await Contract.deploy();
    await contract.deployed();
    console.log(`${facetName} deployed to: `, contract.address);
    return contract;
}



//Deploys contracts in Arbitrum
async function deploy(n = 0) { 
    const [callerAddr, caller2Addr] = await hre.ethers.provider.listAccounts();
    console.log('--');
    console.log('Caller 1: ', callerAddr);
    console.log('Caller 2: ', caller2Addr);
    console.log('--');

    const WETH = await hre.ethers.getContractAt('IERC20', wethAddr);
    const USDT = await hre.ethers.getContractAt('IERC20', usdtAddrArb);
    const WBTC = await hre.ethers.getContractAt('IERC20', wbtcAddr);
    const renBTC = await hre.ethers.getContractAt('IERC20', renBtcAddr);
    const USDC = await hre.ethers.getContractAt('IERC20', usdcAddr);
    const MIM = await hre.ethers.getContractAt('IERC20', mimAddr);
    const crvTri = await hre.ethers.getContractAt('IERC20', crvTricrypto);
    const yvCrvTri = await hre.ethers.getContractAt('IYtri', yTricryptoPoolAddr);
    const FRAX = await hre.ethers.getContractAt('IERC20', fraxAddr);
    const USX = await hre.ethers.getContractAt('IERC20', usxAddr);


    //Facets
    const diamondCutFacet = await deployFacet('DiamondCutFacet');
    const diamondLoupeFacet = await deployFacet('DiamondLoupeFacet'); 
    const ozlFacet = await deployFacet('OZLFacet');
    const gettersFacet = await deployFacet('GettersFacet');
    const executorFacet = await deployFacet('ExecutorFacet');
    const oz4626 = await deployFacet('oz4626Facet');
    const oz20 = await deployFacet('oz20Facet');
    const ownershipFacet = await deployFacet('OwnershipFacet'); 
    const revenueFacet = await deployFacet('RevenueFacet');

    const contractsAddr = [
        ozlFacet.address,
        tricryptoAddr,
        crvTricrypto,
        gettersFacet.address,
        renPoolAddr,
        mimPoolAddr,
        crv2PoolAddr,
        yTricryptoPoolAddr,
        fraxPoolAddr,
        executorFacet.address,
        oz4626.address,
        oz20.address,
        chainlinkAggregatorAddr,
        swapRouterUniAddr,
        revenueFacet.address
    ];

    const erc20sAddr = [
        usdtAddrArb,
        wbtcAddr,
        renBtcAddr,
        usdcAddr,
        mimAddr,
        wethAddr,
        fraxAddr,
    ];

    const tokensDatabase = [
        usdtAddrArb,
        usdcAddr,
        fraxAddr,
        wbtcAddr,
        mimAddr,
        renBtcAddr
    ];

    const appVars = [
        dappFee,
        defaultSlippage,
        poolFeeUni
    ];

    const ozlVars = [tokenName, tokenSymbol];

    const nonRevenueFacets = [ 
        diamondCutFacet.address,
        diamondLoupeFacet.address,
        ownershipFacet.address,
        revenueFacet.address
    ];

    if (n === 1) revenueAmounts[0] = 250;

    //Data structs for init()
    const VarsAndAddrStruct = [
        contractsAddr,
        erc20sAddr,
        tokensDatabase,
        appVars,
        ozlVars,
        ETH,
        revenueAmounts
    ];

    //Deploy DiamondInit
    const DiamondInit = await hre.ethers.getContractFactory('DiamondInit');
    const diamondInit = await DiamondInit.deploy();
    await diamondInit.deployed(); 
    const functionCall = diamondInit.interface.encodeFunctionData('init', [VarsAndAddrStruct]);

    //Deploys diamond
    const deployedDiamond = await diamond.deploy({
        diamondName: 'Diamond',
        facets: [
            ['DiamondCutFacet', diamondCutFacet],
            ['DiamondLoupeFacet', diamondLoupeFacet],
            ['OZLFacet', ozlFacet],
            ['GettersFacet', gettersFacet],
            ['ExecutorFacet', executorFacet],
            ['oz4626Facet', oz4626],
            ['oz20Facet', oz20],
            ['OwnershipFacet', ownershipFacet],
            ['ReveneuFacet', revenueFacet]
        ],
        args: '',
        overrides: {
            callerAddr, functionCall, diamondInit: diamondInit.address, nonRevenueFacets
        }
    });
    console.log('Diamond deployed to: ', deployedDiamond.address);

    return {
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
        yvCrvTri,
        USX
    };

}




module.exports = {
    balanceOfOZL,
    transferOZL,
    withdrawShareOZL,
    getVarsForHelpers,
    sendETH,
    getCalldata,
    enableWithdrawals,
    deploy,
    getOzelIndex,
    addTokenToDatabase,
    getRegulatorCounter,
    getTestingNumber,
    deployFacet,
    replaceForModVersion,
    queryTokenDatabase
};