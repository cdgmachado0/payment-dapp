


function err(n = 0) { 
    return {
        alreadyInitialized: "VM Exception while processing transaction: reverted with reason string 'Initializable: contract is already initialized'",
        onlyOps: "VM Exception while processing transaction: reverted with reason string 'ozPayMe: onlyOps'",
        notAuthorized: (function (m) {
            switch(m) {
                case 0:
                    return "VM Exception while processing transaction: reverted with custom error 'NotAuthorized()'";
                case 1:
                    return 'Transaction reverted without a reason string';
                case 2:
                    return "VM Exception while processing transaction: reverted with reason string 'LibDiamond: Must be contract owner'";
            }
        })(n),
        notProxy: "VM Exception while processing transaction: reverted with custom error 'NotProxy()'",
        notOwner: "VM Exception while processing transaction: reverted with reason string 'Ownable: caller is not the owner'",
        zeroAddress: `VM Exception while processing transaction: reverted with custom error 'CantBeZero("address")'`,
        zeroSlippage: `VM Exception while processing transaction: reverted with custom error 'CantBeZero("slippage")'`,
        tokenNotFound: `VM Exception while processing transaction: reverted with custom error 'NotFoundInDatabase("token")'`,
        zeroMsgValue: `VM Exception while processing transaction: reverted with custom error 'CantBeZero("msg.value")'`,
        zeroShares: `VM Exception while processing transaction: reverted with custom error 'CantBeZero("shares")'`
    };
    
} 


module.exports = {
    err
};