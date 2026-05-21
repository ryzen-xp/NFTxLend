// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFTxLendRouter.sol";
import "../src/Vault.sol";
import "../src/OracleVerifier.sol";
import "@openzeppelin/token/ERC721/ERC721.sol";

contract MockNFTR is ERC721 {
    uint256 private _id;
    constructor() ERC721("M", "M") {}
    function mint(address to) external returns (uint256) { uint256 i = _id++; _mint(to, i); return i; }
}

contract NFTxLendRouterTest is Test {
    NFTxLendRouter public router;
    NFTVault public vault;
    OracleVerifier public oracle;
    MockNFTR public nft;

    address public deployer = makeAddr("deployer");
    address public relayer = makeAddr("relayer");
    uint256 public oracleKey = 0xA11CE;
    address public oracleSigner;
    address public user = makeAddr("user");
    bytes32 public stellar = bytes32(uint256(0xCAFE));

    function setUp() public {
        oracleSigner = vm.addr(oracleKey);
        vm.startPrank(deployer);
        oracle = new OracleVerifier(oracleSigner);
        vault = new NFTVault(relayer);
        router = new NFTxLendRouter(address(vault), address(oracle));
        nft = new MockNFTR();
        router.setCollectionSupport(address(nft), true);
        vm.stopPrank();
    }

    function test_depositNFT_success() public {
        vm.startPrank(user);
        uint256 tid = nft.mint(user);
        nft.approve(address(vault), tid);
        uint256 pid = router.depositNFT(address(nft), tid, stellar, 0);
        vm.stopPrank();
        assertTrue(vault.isPositionActive(pid));
    }

    function test_depositNFT_revertsUnsupported() public {
        address fake = makeAddr("fake");
        vm.prank(user);
        vm.expectRevert(NFTxLendRouter.CollectionNotSupported.selector);
        router.depositNFT(fake, 0, stellar, 0);
    }

    function test_setCollectionSupport() public {
        address c = makeAddr("col");
        vm.prank(deployer);
        router.setCollectionSupport(c, true);
        assertTrue(router.isCollectionSupported(c));
        vm.prank(deployer);
        router.setCollectionSupport(c, false);
        assertFalse(router.isCollectionSupported(c));
    }

    function test_batchSetCollectionSupport() public {
        address[] memory cols = new address[](2);
        cols[0] = makeAddr("a");
        cols[1] = makeAddr("b");
        bool[] memory flags = new bool[](2);
        flags[0] = true;
        flags[1] = true;
        vm.prank(deployer);
        router.batchSetCollectionSupport(cols, flags);
        assertTrue(router.isCollectionSupported(cols[0]));
        assertTrue(router.isCollectionSupported(cols[1]));
    }

    function test_pause_blocks() public {
        vm.prank(deployer);
        router.pause();
        vm.startPrank(user);
        uint256 tid = nft.mint(user);
        nft.approve(address(vault), tid);
        vm.expectRevert();
        router.depositNFT(address(nft), tid, stellar, 0);
        vm.stopPrank();
    }

    function test_setContracts() public {
        vm.startPrank(deployer);
        NFTVault v2 = new NFTVault(relayer);
        OracleVerifier o2 = new OracleVerifier(oracleSigner);
        router.setContracts(address(v2), address(o2));
        vm.stopPrank();
        assertEq(address(router.vault()), address(v2));
        assertEq(address(router.oracleVerifier()), address(o2));
    }
}
