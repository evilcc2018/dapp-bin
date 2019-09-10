pragma solidity 0.4.25;

import "github.com/evilcc2018/dapp-bin/pai-experimental/3rd/math.sol";

contract ACLMaster is DSMath {
    mapping(uint => bytes) roles;
    mapping(bytes => PermissionGroup) groups;
    struct PermissionGroup {
        bool exist;
        uint32 memberLimit; //when =0 represents no limit
        bytes superior;
        address[] members;
    }
    uint public indexForACL;
    string constant ADMIN = "ADMIN";

    constructor() public {
        indexForACL = 1;
        roles[indexForACL] = bytes(ADMIN);
        groups[bytes(ADMIN)].exist = true;
        groups[bytes(ADMIN)].superior = bytes(ADMIN);
        groups[bytes(ADMIN)].members.push(msg.sender);
    }
    
    function createNewRole(bytes newRole, bytes superior, uint32 limit) public auth(ADMIN) {
        require(!groups[newRole].exist);
        require(groups[superior].exist)
        indexForACL = add(indexForACL,1);
        roles[indexForACL] = newRole;
        groups[newRole].exist = true;
        groups[newRole].superior = superior;
        groups[newRole].memberLimit = limit;
    }

    function addMember(address _addr, bytes role) public {
        require(groups[role].exist);
        require(canPerform(groups[role].superior, msg.sender));
        require(!addressExist(role,_addr));
        require(0 == groups[role].memberLimit || groups[role].members.length < groups[role].memberLimit);
        groups[role].members.push(_addr);
    }

    function removeMember(address _addr, bytes role) public {
        require(groups[role].exist);
        require(canPerform(groups[role].superior, msg.sender));
        uint len = groups[role].members.length;
        if(0 == len) {
            return;
        }
        for(uint i = 0; i < len; i++) {
            if(_addr == groups[role].members[i]) {
                if(i != len - 1) {
                    groups[role].members[i] = groups[role].members[len - 1];
                }
                // delete groups[role].members[len - 1];
                groups[role].members.length--;
                return;
            }
        }
    }

    function resetMembers(address[] _members, bytes role) public {
        require(groups[role].exist);
        require(canPerform(groups[role].superior, msg.sender));
        require(0 == groups[role].memberLimit||_members.length <= groups[role].memberLimit);
        groups[role].members.length = 0;
        if (_members.length > 0) {
            for (uint i = 0; i < _members.length; i++) {
                groups[role].members.push(_members[i]);
            }
        }
    }

    function changeSuperior(bytes role, bytes newSuperior) public {
        require(groups[role].exist);
        require(canPerform(groups[groups[role].superior].superior, msg.sender));
        require(groups[newSuperior].exist);
        groups[role].superior = newSuperior;
    }

    function changeMemberLimit(bytes role, uint32 newlimit) public {
        require(groups[role].exist);
        require(canPerform(groups[groups[role].superior].superior, msg.sender));
        require(groups[newSuperior].exist);
        groups[role].memberLimit = newlimit;
    }

    function addressExist(bytes role, address _addr) public view returns (bool) {
        for(uint i = 0; i < groups[role].members.length; i++) {
            if(_addr == groups[role].members[i]) {
                return true;
            }
        }
        return false;
    }

    function getSuperior(bytes role) public view returns (string) {
        return string(groups[role].superior);
    }

    function getMembers(bytes role) public view returns (address[]) {
        return groups[role].members;
    }

    function canPerform(string role, address _addr) public view returns (bool) {
        return addressExist(bytes(role), _addr);
    }

    function canPerform(bytes role, address _addr) public view returns (bool) {
        return addressExist(role, _addr);
    }

    modifier auth(string role) {
        require(canPerform(role, msg.sender));
        _;
    }
}