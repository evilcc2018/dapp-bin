pragma solidity 0.4.25;

import "github.com/evilcc2018/dapp-bin/library/template.sol";
import "github.com/evilcc2018/dapp-bin/library/acl_slave.sol";

contract Setting is Template, ACLSlave {
    uint public lendingInterestRate; // in RAY
    uint public depositInterestRate; // in RAY
    mapping(uint96 => uint) public mintPaiRatioLimit; //in RAY
    bool public globalOpen;
    constructor(address paiMainContract) public {
        master = ACLMaster(paiMainContract);
        globalOpen = true;
    }

    function updateLendingRate(uint newRate) public auth("DIRECTORVOTE") {
        lendingInterestRate = newRate;
    }

    function updateDepositRate(uint newRate) public auth("DIRECTORVOTE") {
        depositInterestRate = newRate;
    }

    function updateRatioLimit(uint96 assetGlobalId, uint ratio) public auth("DIRECTORVOTE") {
        mintPaiRatioLimit[assetGlobalId] = ratio;
    }

    function globalShutDown() public auth("DIRECTORVOTE") {
        globalOpen = false;
    }

    function globalReopen() public auth("DIRECTORVOTE") {
        globalOpen = true;
    }
}