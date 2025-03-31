// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract myERC is ERC20, Test {
    address public owner = vm.addr(1);

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(owner, 1000);
    }

    function myTransferA(address recipient, uint256 amount) public {
        uint256 beforeTransferGas = gasleft();
        transfer(recipient, amount);
        uint256 gasUsed = beforeTransferGas - gasleft();
        console2.log("Gas used using direct transfer A: %s", gasUsed); // same as transferB
    }

    function myTransferB(address recipient, uint256 amount) public {
        uint256 beforeTransferGas = gasleft();
        super.transfer(recipient, amount);
        uint256 gasUsed = beforeTransferGas - gasleft();
        console2.log("Gas used using direct transfer A: %s", gasUsed); // same as transferA
    }
}

contract TestGas is Test {
    TestContract testcontract;
    myERC testERC20;

    address public owner = vm.addr(1);

    function setUp() public {
        testcontract = new TestContract();
        testERC20 = new myERC("Test", "TST");
    }

    // Not possible to call locally a function with calldata parameter
    /* function test_CalldataLocal() public view {
        testcontract.CalldataLocal();
    } */

    function test_MemoryLocal() public view {
        // [PASS] test_MemoryLocal() (gas: 8804)
        testcontract.MemoryLocal();
    }

    function test_CalldataThis() public view {
        // [PASS] test_CalldataThis() (gas: 10099)
        testcontract.CalldataThis();
    }

    function test_MemoryThis() public view {
        // [PASS] test_MemoryThis() (gas: 10270)
        testcontract.MemoryThis();
    }

    function test_myTransferA() public {
        vm.prank(owner);
        vm.breakpoint("a");
        testERC20.myTransferA(address(this), 100);
    }

    function test_myTransferB() public {
        vm.prank(owner);
        vm.breakpoint("a");
        testERC20.myTransferB(address(this), 100);
    }
}

contract TestContract {
    function printCalldataParam(bytes calldata myParam) public pure {
        console2.logBytes(myParam);
    }

    function printMemoryParam(bytes memory myParam) public pure {
        console2.logBytes(myParam);
    }

    function CalldataThis() public view {
        this.printCalldataParam("0x1");
    }

    function CalldataLocal() public pure {
        console2.log("Cannot call printCalldataParam with local call as expects calldata, only possible with a call");
    }

    function MemoryThis() public view {
        this.printMemoryParam("0x3");
    }

    function MemoryLocal() public pure {
        printMemoryParam("0x4");
    }
}
