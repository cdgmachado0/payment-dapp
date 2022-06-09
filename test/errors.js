


function err(n) {
    return {
        alreadyInitialized: "VM Exception while processing transaction: reverted with reason string 'Initializable: contract is already initialized'",
        onlyOps: "VM Exception while processing transaction: reverted with reason string 'ozPayMe: onlyOps'",
        notAuthorized: n !== 1 ? "VM Exception while processing transaction: reverted with reason string 'ozPayMe: Not authorized'" : 'Transaction reverted without a reason string',
        notProxy: "VM Exception while processing transaction: reverted with custom error 'NotProxy()'",
        notOwner: "VM Exception while processing transaction: reverted with reason string 'Ownable: caller is not the owner'",
        zeroAddress: `VM Exception while processing transaction: reverted with custom error 'CantBeZero("address")'`,
        zeroSlippage: `VM Exception while processing transaction: reverted with custom error 'CantBeZero("slippage")'`,
        tokenNotFound: `VM Exception while processing transaction: reverted with custom error 'NotFoundInDatabase("token")'`
    };


} 


module.exports = {
    err
};