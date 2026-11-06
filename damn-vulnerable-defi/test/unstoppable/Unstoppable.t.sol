
 // SPDX-License-Identifier: MIT
 // Damn Vulnerable DeFi v4
 // https://damnvulnerabledefi.xyz
 pragma solidity =0.8.25;

 import {Test, console} from "forge-std/Test.sol";
 import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
 import {UnstoppableVault, Owned} from "../../src/unstoppable/UnstoppableVault.sol";
 import {UnstoppableMonitor} from "../../src/unstoppable/UnstoppableMonitor.sol";

 contract UnstoppableChallenge is Test {
     address deployer = makeAddr("deployer");
     address player = makeAddr("player");

     uint256 constant TOKENS_IN_VAULT = 1_000_000e18;
     uint256 constant INITIAL_PLAYER_TOKEN_BALANCE = 10e18;

     DamnValuableToken public token;
     UnstoppableVault public vault;
     UnstoppableMonitor public monitorContract;

     modifier checkSolvedByPlayer() {
         vm.startPrank(player, player);
         _;
         vm.stopPrank();
         _isSolved();
     }

     /**
      * ORIGINAL CHALLENGE SETUP
      * DO NOT MODIFY
      */
     function setUp() public {
         startHoax(deployer);

         token = new DamnValuableToken();

         vault = new UnstoppableVault({
             _token: token,
             _owner: deployer,
             _feeRecipient: deployer
         });

         token.approve(
             address(vault),
             TOKENS_IN_VAULT
         );

         vault.deposit(
             TOKENS_IN_VAULT,
             address(deployer)
         );

         token.transfer(
             player,
             INITIAL_PLAYER_TOKEN_BALANCE
         );

         monitorContract = new UnstoppableMonitor(
             address(vault)
         );

         vault.transferOwnership(
             address(monitorContract)
         );

         vm.expectEmit();
         emit UnstoppableMonitor.FlashLoanStatus(true);

         monitorContract.checkFlashLoan(100e18);

         vm.stopPrank();
     }

     /**
      * TEST 01
      * Validate initial vault conditions
      */
     function test_assertInitialState() public {
         assertEq(
             token.balanceOf(address(vault)),
             TOKENS_IN_VAULT
         );

         assertEq(
             token.balanceOf(player),
             INITIAL_PLAYER_TOKEN_BALANCE
         );

         assertEq(monitorContract.owner(), deployer);

         assertEq(
             address(vault.asset()),
             address(token)
         );

         assertEq(
             vault.totalAssets(),
             TOKENS_IN_VAULT
         );

         assertEq(
             vault.totalSupply(),
             TOKENS_IN_VAULT
         );

         assertEq(
             vault.maxFlashLoan(address(token)),
             TOKENS_IN_VAULT
         );

         assertEq(
             vault.flashFee(
                 address(token),
                 TOKENS_IN_VAULT - 1
             ),
             0
         );

         assertEq(
             vault.flashFee(
                 address(token),
                 TOKENS_IN_VAULT
             ),
             50000e18
         );

         assertEq(
             vault.owner(),
             address(monitorContract)
         );

         assertFalse(vault.paused());

         vm.expectRevert("UNAUTHORIZED");
         vault.setPause(true);

         vm.expectRevert("UNAUTHORIZED");
         monitorContract.checkFlashLoan(100e18);
     }

     /**
      * TEST 02
      * ORIGINAL MANUAL EXPLOIT PROOF OF CONCEPT
      *
      * Vulnerability:
      * A direct token donation changes the vault's
      * token balance without minting vault shares.
      *
      * Expected results:
      * Vulnerable contract: PASS
      * Modified contract: FAIL
      *
      * The original challenge checks that flash
      * loans become unavailable.
      */
    function test_unstoppable()
    public
    checkSolvedByPlayer
{
    // Manual exploit PoC:
    // Send 1 wei directly to the vault.
    token.transfer(address(vault), 1);
}

     /**
      * TEST 03
      * SECURITY REGRESSION TEST
      *
      * Verify flash loans continue working
      * after a direct 1-wei token donation.
      */
     function test_flashLoanWorksAfterDonation() public {
         vm.prank(player);

         token.transfer(
             address(vault),
             1
         );

         assertEq(
             token.balanceOf(address(vault)),
             TOKENS_IN_VAULT + 1
         );

         vm.prank(deployer);

         vm.expectEmit();
         emit UnstoppableMonitor.FlashLoanStatus(true);

         monitorContract.checkFlashLoan(100e18);

         assertFalse(
             vault.paused(),
             "Vault should remain active"
         );

         assertEq(
             vault.owner(),
             address(monitorContract),
             "Vault ownership should remain unchanged"
         );
     }

     /**
      * TEST 04
      * BALANCE INTEGRITY VALIDATION
      *
      * Verify that the flash loan does not
      * unexpectedly change the vault balance.
      */
     function test_flashLoanPreservesBalanceAfterDonation()
         public
     {
         vm.prank(player);

         token.transfer(
             address(vault),
             1
         );

         uint256 balanceBefore =
             token.balanceOf(address(vault));

         vm.prank(deployer);

         monitorContract.checkFlashLoan(100e18);

         uint256 balanceAfter =
             token.balanceOf(address(vault));

         assertEq(
             balanceAfter,
             balanceBefore,
             "Flash loan unexpectedly changed vault balance"
         );

         assertFalse(vault.paused());
     }

     /**
      * TEST 05
      * EXCESSIVE FLASH LOAN VALIDATION
      *
      * Verify the vault rejects a loan amount
      * greater than the available assets.
      */
     function test_flashLoanRejectsExcessiveAmount()
         public
     {
         uint256 excessiveAmount =
             vault.totalAssets() + 1;

         vm.expectRevert(
             abi.encodeWithSelector(
                 UnstoppableVault.InvalidAmount.selector,
                 excessiveAmount
             )
         );

         vault.flashLoan(
             monitorContract,
             address(token),
             excessiveAmount,
             ""
         );
     }

     /**
      * TEST 06
      * ACCESS CONTROL VALIDATION
      *
      * Verify token donations cannot change
      * vault ownership or pause permissions.
      */
     function test_donationDoesNotChangePermissions()
         public
     {
         vm.prank(player);

         token.transfer(
             address(vault),
             1
         );

         assertFalse(vault.paused());

         assertEq(
             vault.owner(),
             address(monitorContract)
         );

         vm.prank(player);

         vm.expectRevert("UNAUTHORIZED");

         vault.setPause(true);
     }

function test_securityFixPreventsDonationDoS() public {
    // Attacker donates 1 wei directly to the vault
    vm.prank(player);
    token.transfer(address(vault), 1);

    // Confirm the donation reached the vault
    assertEq(
        token.balanceOf(address(vault)),
        TOKENS_IN_VAULT + 1
    );

    // Confirm flash loans remain operational
    vm.prank(deployer);

    vm.expectEmit();
    emit UnstoppableMonitor.FlashLoanStatus(true);

    monitorContract.checkFlashLoan(100e18);

    // Confirm the vault was not paused
    assertFalse(vault.paused());

    // Confirm ownership remains with the monitor
    assertEq(
        vault.owner(),
        address(monitorContract)
    );
}
     /**
      * ORIGINAL CHALLENGE SUCCESS CONDITIONS
      * DO NOT MODIFY
      */
     function _isSolved() private {
         vm.prank(deployer);

         vm.expectEmit();
         emit UnstoppableMonitor.FlashLoanStatus(false);

         monitorContract.checkFlashLoan(100e18);

         assertTrue(
             vault.paused(),
             "Vault is not paused"
         );

         assertEq(
             vault.owner(),
             deployer,
             "Vault did not change owner"
         );
     }
 }
