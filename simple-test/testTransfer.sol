pragma solidity 0.4.25;

import "../library/template.sol";

contract TestMultipleTransfer is Template {
    uint total;

    function() public payable {
        total = total + msg.value;
    }

    function test(uint x) public {
        if(x == 1) {
            msg.sender.transfer(100000000, 0);
            total = total - 100000000;
        } else {
            msg.sender.transfer(100000000, 0);
            msg.sender.transfer(100000000, 0);
            total = total - 200000000;
        }
    }

    function getTotal() public view returns (uint){
        return total;
    }
 }