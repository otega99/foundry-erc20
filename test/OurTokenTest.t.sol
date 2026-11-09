// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {OurToken} from "../src/OurToken.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract OurTokenTest is Test {
    OurToken public ourToken;
    DeployOurToken public deployer;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    uint256 public constant STARTING_BALANCE = 100 ether;

    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();

        vm.prank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }
    function testBobBalance() public {
        assertEq(STARTING_BALANCE, ourToken.balanceOf(bob));
    }

    function testTokenMetadataAndSupply() public {
        assertEq(ourToken.name(), "OurToken");
        assertEq(ourToken.symbol(), "OTK");
        assertEq(ourToken.decimals(), 18);
        assertEq(ourToken.totalSupply(), deployer.INITIAL_SUPPLY());
    }

    function testTransferEmitsEventAndUpdatesBalances() public {
        uint256 transferAmount = 10 ether;

        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(bob, alice, transferAmount);

        vm.prank(bob);
        assertTrue(ourToken.transfer(alice, transferAmount));

        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(ourToken.balanceOf(alice), transferAmount);
    }

    function testAllowanceWorks() public {
        uint256 initialAllowance = 1000;
        // Bob approves alice to spend tokens on his behalf
        vm.expectEmit(true, true, false, true);
        emit IERC20.Approval(bob, alice, initialAllowance);
        vm.prank(bob);
        assertTrue(ourToken.approve(alice, initialAllowance));

        uint256 transferAmount = 500;
        vm.prank(alice);
        assertTrue(ourToken.transferFrom(bob, alice, transferAmount));

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(
            ourToken.allowance(bob, alice),
            initialAllowance - transferAmount
        );
    }

    function testInfiniteAllowanceIsNotDecremented() public {
        vm.prank(bob);
        ourToken.approve(alice, type(uint256).max);

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, 1 ether);

        assertEq(ourToken.allowance(bob, alice), type(uint256).max);
        assertEq(ourToken.balanceOf(alice), 1 ether);
    }

    function testTransferRevertsForInsufficientBalance() public {
        uint256 transferAmount = STARTING_BALANCE + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                bob,
                STARTING_BALANCE,
                transferAmount
            )
        );
        vm.prank(bob);
        ourToken.transfer(alice, transferAmount);
    }

    function testTransferRevertsForZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InvalidReceiver.selector,
                address(0)
            )
        );
        vm.prank(bob);
        ourToken.transfer(address(0), 1);
    }

    function testApproveRevertsForZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InvalidSpender.selector,
                address(0)
            )
        );
        vm.prank(bob);
        ourToken.approve(address(0), 1);
    }

    function testTransferFromRevertsForInsufficientAllowance() public {
        uint256 allowanceAmount = 100;
        uint256 transferAmount = allowanceAmount + 1;

        vm.prank(bob);
        ourToken.approve(alice, allowanceAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                alice,
                allowanceAmount,
                transferAmount
            )
        );
        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);
    }
}
