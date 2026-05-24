// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOracleVerifier
 * @notice Interface for the Oracle Verifier contract that validates price attestations.
 * @dev The backend oracle signs collateral valuation payloads off-chain.
 *      This contract verifies those signatures on-chain before allowing
 *      any collateral value to be trusted by the system.
 *
 *      Oracle Calculation (from arch.md):
 *        Floor Price → Apply Safety Haircut → Calculate Borrow Limit → Sign Payload
 */
interface IOracleVerifier {
    // ─────────────────────────────────────────────────────────────
    //  Structs
    // ─────────────────────────────────────────────────────────────

    /// @notice Signed price attestation from the backend oracle
    struct PriceAttestation {
        address nftContract; // ERC-721 collection address
        uint256 tokenId; // Token ID
        uint256 floorPriceWei; // Floor price in wei (ETH)
        uint256 ethUsdPrice; // ETH/USD price (8 decimals)
        uint256 collateralValue; // Calculated collateral value in USD (after haircut)
        uint256 maxBorrowAmount; // Maximum borrow amount in USD
        uint256 timestamp; // When the attestation was created
        uint256 expiresAt; // When the attestation expires
    }

    // ─────────────────────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────────────────────

    /// @notice Emitted when the oracle signer address is updated
    event OracleSignerUpdated(address indexed oldSigner, address indexed newSigner);

    /// @notice Emitted when a price attestation is verified and stored
    event AttestationVerified(
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 collateralValue,
        uint256 maxBorrowAmount,
        uint256 timestamp
    );

    // ─────────────────────────────────────────────────────────────
    //  Core Functions
    // ─────────────────────────────────────────────────────────────

    /// @notice Verify an oracle-signed price attestation
    /// @param attestation The price attestation data
    /// @param signature The ECDSA signature from the oracle
    /// @return valid True if the signature is valid and not expired
    function verifyAttestation(PriceAttestation calldata attestation, bytes calldata signature)
        external
        returns (bool valid);

    /// @notice Update the trusted oracle signer address (admin only)
    /// @param newSigner The new oracle signer address
    function setOracleSigner(address newSigner) external;

    // ─────────────────────────────────────────────────────────────
    //  View Functions
    // ─────────────────────────────────────────────────────────────

    /// @notice Get the current trusted oracle signer
    /// @return signer The oracle signer address
    function oracleSigner() external view returns (address signer);

    /// @notice Get the latest verified attestation for an NFT
    /// @param nftContract The collection address
    /// @param tokenId The token ID
    /// @return attestation The latest PriceAttestation
    function getLatestAttestation(address nftContract, uint256 tokenId)
        external
        view
        returns (PriceAttestation memory attestation);

    /// @notice Check if an attestation is still valid (not expired)
    /// @param nftContract The collection address
    /// @param tokenId The token ID
    /// @return valid True if the latest attestation has not expired
    function isAttestationValid(address nftContract, uint256 tokenId) external view returns (bool valid);
}
