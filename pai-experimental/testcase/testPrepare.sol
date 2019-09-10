pragma solidity 0.4.25;

import "github.com/evilcc2018/dapp-bin/library/template.sol";
import "github.com/evilcc2018/dapp-bin/pai-experimental/pai_main.sol";
import "github.com/evilcc2018/dapp-bin/pai-experimental/pai_issuer.sol";

contract FakePerson is Template {
    function() public payable {}

    function createPAIDAO(string _str) public returns (address) {
        return (new FakePaiDao(_str));
    }

    function createPAIDAONoGovernance(string _str) public returns (address) {
        return (new FakePaiDaoNoGovernance(_str));
    }

    function callInit(address paidao) public returns (bool) {
        bytes4 methodId = bytes4(keccak256("init()"));
        bool result = PAIDAO(paidao).call(methodId);
        return result;
    }

    function callCreateNewRole(address paidao, string newRole, string superior, uint32 limit) public returns (bool) {
        bytes4 methodId = bytes4(keccak256("createNewRole(bytes,bytes,uint32)"));
        bool result = PAIDAO(paidao).call(abi.encodeWithSelector(methodId,bytes(newRole),bytes(superior),limit));
        return result;
    }

    function callAddMember(address paidao, address _address, string role) public returns (bool) {
        bytes4 methodId = bytes4(keccak256("addMember(address,bytes)"));
        bool result = PAIDAO(paidao).call(abi.encodeWithSelector(methodId,_address,bytes(role)));
        return result;
    }

    function callRemoveMember(address paidao, address _address, string role) public returns (bool) {
        bytes4 methodId = bytes4(keccak256("removeMember(address,bytes)"));
        bool result = PAIDAO(paidao).call(abi.encodeWithSelector(methodId,_address,bytes(role)));
        return result;
    }

    function callMint(address paidao, uint amount, address dest) public returns (bool) {
        bytes4 methodId = bytes4(keccak256("mint(uint256,address)"));
        bool result = PAIDAO(paidao).call(abi.encodeWithSelector(methodId,amount,dest));
        return result;
    }

    function callBurn(address paidao, uint amount, uint96 id) public returns (bool) {
        bytes4 methodId = bytes4(keccak256("burn()"));
        bool result = PAIDAO(paidao).call.value(amount,id)(abi.encodeWithSelector(methodId));
        return result;
    }

    function callResetMembers(address paidao, address[] _members, string role) public returns (bool) {
        bytes4 methodId = bytes4(keccak256("resetMembers(address[],bytes)"));
        bool result = PAIDAO(paidao).call(abi.encodeWithSelector(methodId, _members, bytes(role)));
        return result;
    }

    function callChangeSuperior(address paidao, string role, string newSuperior) public returns (bool) {
        bytes4 methodId = bytes4(keccak256("changeSuperior(bytes,bytes)"));
        bool result = PAIDAO(paidao).call(abi.encodeWithSelector(methodId, bytes(role),bytes(newSuperior)));
        return result;
    }

    function callChangeMemberLimit(address paidao, string role, uint32 limit) public returns (bool) {
        bytes4 methodId = bytes4(keccak256("changeMemberLimit(bytes,uint32)"));
        bool result = PAIDAO(paidao).call(abi.encodeWithSelector(methodId, bytes(role),limit));
        return result;
    }
}

contract FakePAIIssuer is PAIIssuer {
    constructor(string _organizationName, address paiMainContract)
        PAIIssuer(_organizationName,paiMainContract)
    public {
        templateName = "Fake-Template-Name-For-Test-pai_issuer";
    }
}

contract FakePaiDao is PAIDAO {
    constructor(string _organizationName)
        PAIDAO(_organizationName)
        public
    {
        templateName = "Fake-Template-Name-For-Test-pai_main";
    }
}

contract FakePaiDaoNoGovernance is PAIDAO {
    constructor(string _organizationName)
        PAIDAO(_organizationName)
        public
    {
        templateName = "Fake-Template-Name-For-Test-pai_main2";
    }

    function canPerform(string role, address _addr) public view returns (bool) {
        return true;
    }

    function canPerform(bytes role, address _addr) public view returns (bool) {
        return true;
    }
}