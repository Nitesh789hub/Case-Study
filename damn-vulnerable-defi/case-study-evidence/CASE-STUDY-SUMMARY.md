# HeistProof.AI Security Case Study

## Target
Damn Vulnerable DeFi v4 - Unstoppable Vault

## Vulnerability
Denial of Service through an unexpected ERC20 token donation.

## Root Cause
The original flash-loan implementation required the
vault's token balance to match its accounting-derived
expected balance exactly.

A direct token donation could break this invariant
without updating the vault's share accounting.

## Exploit Reproduction
Original vulnerable implementation:
- test_unstoppable: PASS
- Flash loan functionality disrupted
- Monitor pauses the vault

## Remediation
Removed the strict balance equality check and added
a check that the requested loan amount does not
exceed the vault's available token balance.

## Patch Verification
- Original exploit no longer achieves its objective
- FlashLoanStatus: expected=false, got=true
- Six targeted regression tests passed

## Environment
- Solidity 0.8.25
- Foundry
- Damn Vulnerable DeFi v4
- Local test environment

## Conclusion
The local proof of concept demonstrates the
denial-of-service vulnerability in the original
implementation and the effectiveness of the
proposed patch against this specific attack.
