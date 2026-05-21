// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title INFTVault
 * @notice Interface for the NFT Vault contract that handles NFT collateral locking/unlocking.
 * @dev Users deposit ERC-721 NFTs to create collateral positions.
 *      The backend oracle detects deposit events, fetches floor prices,
 *      and relays collateral proofs to the Stellar lending contract.
 */
interface INFTVault {
    // ─────────────────────────────────────────────────────────────
    //  Structs
    // ─────────────────────────────────────────────────────────────

    /// @notice Represents a single NFT collateral position
    struct Position {
        address owner;           // Wallet that deposited the NFT
        address nftContract;     // ERC-721 collection address
        uint256 tokenId;         // Token ID within the collection
        bytes32 stellarAddress;  // Borrower's Stellar address (raw 32-byte public key)
        bool active;             // Whether the position is still locked
        uint64 lockedAt;         // Timestamp when NFT was deposited
        uint64 expiresAt;        // Expiry timestamp (0 = no expiry)
    }

    // ─────────────────────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────────────────────

    /// @notice Emitted when an NFT is deposited into the vault
    event NFTDeposited(
        uint256 indexed positionId,
        address indexed owner,
        address indexed nftContract,
        uint256 tokenId,
        bytes32 stellarAddress,
        uint64 lockedAt,
        uint64 expiresAt
    );

    /// @notice Emitted when an NFT is released back to the owner
    event NFTWithdrawn(
        uint256 indexed positionId,
        address indexed owner,
        address indexed nftContract,
        uint256 tokenId
    );

    /// @notice Emitted when the backend oracle marks a position as repayment-eligible
    event PositionUnlocked(uint256 indexed positionId);

    // ─────────────────────────────────────────────────────────────
    //  Core Functions
    // ─────────────────────────────────────────────────────────────

    /// @notice Deposit an NFT into the vault to create a collateral position
    /// @param nftContract Address of the ERC-721 collection
    /// @param tokenId Token ID to deposit
    /// @param stellarAddress Borrower's Stellar public key (32 bytes)
    /// @param lockDuration Duration in seconds to lock the NFT (0 = indefinite)
    /// @return positionId The ID of the newly created position
    function depositNFT(
        address nftContract,
        uint256 tokenId,
        bytes32 stellarAddress,
        uint256 lockDuration
    ) external returns (uint256 positionId);

    /// @notice Withdraw an NFT after the loan has been repaid and position unlocked
    /// @param positionId The ID of the position to withdraw from
    function withdrawNFT(uint256 positionId) external;

    /// @notice Mark a position as eligible for withdrawal (called by authorized oracle/relayer)
    /// @param positionId The ID of the position to unlock
    function unlockPosition(uint256 positionId) external;

    // ─────────────────────────────────────────────────────────────
    //  View Functions
    // ─────────────────────────────────────────────────────────────

    /// @notice Get details of a specific position
    /// @param positionId The ID of the position
    /// @return position The full Position struct
    function getPosition(uint256 positionId) external view returns (Position memory position);

    /// @notice Get all position IDs owned by an address
    /// @param owner The address to query
    /// @return positionIds Array of position IDs
    function getPositionsByOwner(address owner) external view returns (uint256[] memory positionIds);

    /// @notice Get the total number of positions created
    /// @return count Total position count
    function totalPositions() external view returns (uint256 count);

    /// @notice Check if a position is currently active (locked)
    /// @param positionId The ID of the position
    /// @return isActive True if the NFT is still locked
    function isPositionActive(uint256 positionId) external view returns (bool isActive);
}
