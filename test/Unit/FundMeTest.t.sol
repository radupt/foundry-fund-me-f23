// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    // We want to test that Fund Me contract is doing what we want to do

    FundMe fundMe; // the variable fundMe of type FundMe

    address USER = makeAddr("user"); // from "forge-std"
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        // here we deploy our contract
        // us -> FundMe Test -> FundMe
        //fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run(); // run retun a fundMe contract
        vm.deal(USER, STARTING_BALANCE); // give balance to fake user
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        console.log(fundMe.getOwner());
        console.log(msg.sender); // to run "forge test -vv"
        assertEq(fundMe.getOwner(), msg.sender); // because in setup
    }

    // What can we do to work with addresses outside our system?
    //1. Unit
    //  - Testing a specific part of our code
    //2. Integration
    //  - Testing how our code works with other parts of our code
    //3. Forked
    //  - Testink our code on a simulated real environment  "forge test --match-test testPriceFeedVersionIsAccurate -vvv --fork-url $SEPOLIA_RPC_URL"
    // Coverage: forge coverage --fork-url $SEPOLIA_RPC_URL
    //4. Staging
    //  -Testing our code in a real environment that is not prod

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);

        // to run single test "forge test --match-test testPriceFeedVersionIsAccurate"
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // function from foudry: means that the next line should revert
        fundMe.fund(); // the test is succesful because this line fails
    }

    function testFundUpdatesFundedDataStructure() public {
        // We can creae a fake new address to send all of our transactions, to know ho is sending it
        // prank: Sets msg.sender to the specified address for the next call
        vm.prank(USER);

        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0); // now should be USER
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithDrawwithASingleFunder() public funded {
        // Arrange
        uint256 startigOwnerBalance = fundMe.getOwner().balance;
        uint256 startigFundMeBalance = address(fundMe).balance;

        // Account
        //uint256 gasStart = gasleft(); // tells you how much gas is left in you transaction call

        //vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner()); // make sure we are the owner
        fundMe.withdraw();

        //uint256 gasEnd = gasleft();
        //uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        //console.log(gasUsed);

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startigFundMeBalance + startigOwnerBalance,
            endingOwnerBalance
        );
    }

    // snapshot for gas: forge snapshot --match-test
    function testWithdrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1; // some time 0 reverts

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // hoax: Sets up a prank from an address that have some ether(combine prank and deal)
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startigOwnerBalance = fundMe.getOwner().balance;
        uint256 startigFundMeBalance = address(fundMe).balance;

        // Act
        vm.txGasPrice(GAS_PRICE);
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(
            startigFundMeBalance + startigOwnerBalance ==
                fundMe.getOwner().balance
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1; // some time 0 reverts

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // hoax: Sets up a prank from an address that have some ether(combine prank and deal)
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startigOwnerBalance = fundMe.getOwner().balance;
        uint256 startigFundMeBalance = address(fundMe).balance;

        // Act
        vm.txGasPrice(GAS_PRICE);
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(
            startigFundMeBalance + startigOwnerBalance ==
                fundMe.getOwner().balance
        );
    }

    // Chisel: Allows us to write solidity in terminal end execute it.
}
