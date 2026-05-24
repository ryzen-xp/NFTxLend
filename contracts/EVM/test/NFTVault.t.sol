// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "@openzeppelin/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 private _nextTokenId;
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        return tokenId;
    }
}

contract NFTVaultTest is Test {
    NFTVault public vault;
    MockERC721 public mockNFT;

    address public deployer = makeAddr("deployer");
    address public relayer = makeAddr("relayer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    bytes32 public stellarAddr = bytes32(uint256(0xCAFE));

    function setUp() public {
        vm.startPrank(deployer);
        vault = new NFTVault(relayer);
        mockNFT = new MockERC721();
        vm.stopPrank();
    }

    // ─── Deposit Tests ──────────────────────────────────────────

    function test_depositNFT_success() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        uint256 positionId = vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);
        vm.stopPrank();

        INFTVault.Position memory pos = vault.getPosition(positionId);
        assertEq(pos.owner, user1);
        assertEq(pos.nftContract, address(mockNFT));
        assertEq(pos.tokenId, tokenId);
        assertTrue(pos.active);
        assertEq(mockNFT.ownerOf(tokenId), address(vault));
    }

    function test_depositNFT_emitsEvent() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);

        vm.expectEmit(true, true, true, false);
        emit INFTVault.NFTDeposited(1, user1, address(mockNFT), tokenId, stellarAddr, 0, 0);
        vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);
        vm.stopPrank();
    }

    function test_depositNFT_revertsIfAlreadyDeposited() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);

        vm.expectRevert(NFTVault.NFTAlreadyDeposited.selector);
        vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);
        vm.stopPrank();
    }

    function test_depositNFT_revertsIfInvalidCollection() public {
        vm.prank(user1);
        vm.expectRevert(NFTVault.InvalidNFTContract.selector);
        vault.depositNFT(address(0), 0, stellarAddr, 0);
    }

    function test_depositNFT_revertsIfInvalidStellarAddress() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        vm.expectRevert(NFTVault.InvalidStellarAddress.selector);
        vault.depositNFT(address(mockNFT), tokenId, bytes32(0), 0);
        vm.stopPrank();
    }

    // ─── Withdraw Tests ─────────────────────────────────────────

    function test_withdrawNFT_success() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        uint256 positionId = vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);
        vm.stopPrank();

        vm.prank(relayer);
        vault.unlockPosition(positionId);

        vm.prank(user1);
        vault.withdrawNFT(positionId);

        assertEq(mockNFT.ownerOf(tokenId), user1);
        assertFalse(vault.isPositionActive(positionId));
    }

    function test_withdrawNFT_revertsIfNotOwner() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        uint256 positionId = vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);
        vm.stopPrank();

        vm.prank(relayer);
        vault.unlockPosition(positionId);

        vm.prank(user2);
        vm.expectRevert(NFTVault.NotPositionOwner.selector);
        vault.withdrawNFT(positionId);
    }

    function test_withdrawNFT_revertsIfNotUnlocked() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        uint256 positionId = vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(NFTVault.PositionNotUnlocked.selector);
        vault.withdrawNFT(positionId);
    }

    function test_withdrawNFT_revertsIfStillLocked() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        uint256 positionId = vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 1 days);
        vm.stopPrank();

        vm.prank(relayer);
        vault.unlockPosition(positionId);

        vm.prank(user1);
        vm.expectRevert(NFTVault.PositionStillLocked.selector);
        vault.withdrawNFT(positionId);
    }

    // ─── Unlock Tests ───────────────────────────────────────────

    function test_unlockPosition_success() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        uint256 positionId = vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);
        vm.stopPrank();

        vm.prank(relayer);
        vault.unlockPosition(positionId);
        assertTrue(vault.isPositionUnlocked(positionId));
    }

    function test_unlockPosition_revertsIfNotRelayer() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        uint256 positionId = vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(NFTVault.NotAuthorizedRelayer.selector);
        vault.unlockPosition(positionId);
    }

    // ─── View Tests ─────────────────────────────────────────────

    function test_getPositionsByOwner_returnsAll() public {
        vm.startPrank(user1);
        uint256 t1 = mockNFT.mint(user1);
        uint256 t2 = mockNFT.mint(user1);
        mockNFT.approve(address(vault), t1);
        mockNFT.approve(address(vault), t2);
        vault.depositNFT(address(mockNFT), t1, stellarAddr, 0);
        vault.depositNFT(address(mockNFT), t2, stellarAddr, 0);
        vm.stopPrank();

        uint256[] memory ids = vault.getPositionsByOwner(user1);
        assertEq(ids.length, 2);
    }

    function test_totalPositions_incrementsCorrectly() public {
        assertEq(vault.totalPositions(), 0);

        vm.startPrank(user1);
        uint256 t1 = mockNFT.mint(user1);
        mockNFT.approve(address(vault), t1);
        vault.depositNFT(address(mockNFT), t1, stellarAddr, 0);
        vm.stopPrank();

        assertEq(vault.totalPositions(), 1);
    }

    // ─── Admin Tests ────────────────────────────────────────────

    function test_setRelayer_updatesAddress() public {
        address newRelayer = makeAddr("newRelayer");
        vm.prank(deployer);
        vault.setRelayer(newRelayer);
        assertEq(vault.relayer(), newRelayer);
    }

    function test_pause_blocksDeposits() public {
        vm.prank(deployer);
        vault.pause();

        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        vm.expectRevert();
        vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);
        vm.stopPrank();
    }

    function test_emergencyWithdraw_rescuesNFT() public {
        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        vault.depositNFT(address(mockNFT), tokenId, stellarAddr, 0);
        vm.stopPrank();

        vm.prank(deployer);
        vault.emergencyWithdraw(address(mockNFT), tokenId, deployer);
        assertEq(mockNFT.ownerOf(tokenId), deployer);
    }

    // ─── Fuzz Tests ─────────────────────────────────────────────

    function testFuzz_depositNFT_variousLockDurations(uint256 lockDuration) public {
        lockDuration = bound(lockDuration, 0, 365 days);

        vm.startPrank(user1);
        uint256 tokenId = mockNFT.mint(user1);
        mockNFT.approve(address(vault), tokenId);
        uint256 positionId = vault.depositNFT(address(mockNFT), tokenId, stellarAddr, lockDuration);
        vm.stopPrank();

        INFTVault.Position memory pos = vault.getPosition(positionId);
        if (lockDuration > 0) {
            assertEq(pos.expiresAt, pos.lockedAt + uint64(lockDuration));
        } else {
            assertEq(pos.expiresAt, 0);
        }
    }
}
