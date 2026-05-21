// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OracleVerifier.sol";

contract OracleVerifierTest is Test {
    OracleVerifier public verifier;
    uint256 public oraclePrivateKey = 0xA11CE;
    address public oracleSigner;
    address public deployer = makeAddr("deployer");
    address public nftAddr = makeAddr("azuki");

    function setUp() public {
        oracleSigner = vm.addr(oraclePrivateKey);
        vm.prank(deployer);
        verifier = new OracleVerifier(oracleSigner);
    }

    function _makeAtt(uint256 tid) internal view returns (IOracleVerifier.PriceAttestation memory) {
        return IOracleVerifier.PriceAttestation({
            nftContract: nftAddr, tokenId: tid,
            floorPriceWei: 5 ether, ethUsdPrice: 250000000000,
            collateralValue: 625000000000, maxBorrowAmount: 500000000000,
            timestamp: block.timestamp, expiresAt: block.timestamp + 5 minutes
        });
    }

    function _signAtt(IOracleVerifier.PriceAttestation memory a) internal view returns (bytes memory) {
        bytes32 h = keccak256(abi.encode(a.nftContract, a.tokenId, a.floorPriceWei, a.ethUsdPrice, a.collateralValue, a.maxBorrowAmount, a.timestamp, a.expiresAt));
        bytes32 eh = MessageHashUtils.toEthSignedMessageHash(h);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, eh);
        return abi.encodePacked(r, s, v);
    }

    function test_verify_valid() public {
        IOracleVerifier.PriceAttestation memory a = _makeAtt(1);
        assertTrue(verifier.verifyAttestation(a, _signAtt(a)));
    }

    function test_verify_invalidSig() public {
        IOracleVerifier.PriceAttestation memory a = _makeAtt(1);
        bytes32 h = keccak256(abi.encode(a.nftContract, a.tokenId, a.floorPriceWei, a.ethUsdPrice, a.collateralValue, a.maxBorrowAmount, a.timestamp, a.expiresAt));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBAD, MessageHashUtils.toEthSignedMessageHash(h));
        vm.expectRevert(OracleVerifier.InvalidSignature.selector);
        verifier.verifyAttestation(a, abi.encodePacked(r, s, v));
    }

    function test_verify_expired() public {
        IOracleVerifier.PriceAttestation memory a = _makeAtt(1);
        bytes memory sig = _signAtt(a);
        vm.warp(block.timestamp + 10 minutes);
        vm.expectRevert(OracleVerifier.AttestationExpired.selector);
        verifier.verifyAttestation(a, sig);
    }

    function test_verify_replay() public {
        IOracleVerifier.PriceAttestation memory a = _makeAtt(1);
        bytes memory sig = _signAtt(a);
        verifier.verifyAttestation(a, sig);
        vm.expectRevert(OracleVerifier.AttestationAlreadyUsed.selector);
        verifier.verifyAttestation(a, sig);
    }

    function test_getLatest() public {
        IOracleVerifier.PriceAttestation memory a = _makeAtt(1);
        verifier.verifyAttestation(a, _signAtt(a));
        assertEq(verifier.getLatestAttestation(nftAddr, 1).floorPriceWei, 5 ether);
    }

    function test_validity_beforeAndAfterExpiry() public {
        IOracleVerifier.PriceAttestation memory a = _makeAtt(1);
        verifier.verifyAttestation(a, _signAtt(a));
        assertTrue(verifier.isAttestationValid(nftAddr, 1));
        vm.warp(block.timestamp + 10 minutes);
        assertFalse(verifier.isAttestationValid(nftAddr, 1));
    }

    function test_setSigner() public {
        address ns = makeAddr("new");
        vm.prank(deployer);
        verifier.setOracleSigner(ns);
        assertEq(verifier.oracleSigner(), ns);
    }

    function test_setSigner_revertsZero() public {
        vm.prank(deployer);
        vm.expectRevert(OracleVerifier.InvalidOracleSigner.selector);
        verifier.setOracleSigner(address(0));
    }

    function test_collateralCalc() public view {
        (uint256 c, uint256 m) = verifier.calculateCollateralValues(12500e8);
        assertEq(c, 6250e8);
        assertEq(m, 2500e8);
    }
}
