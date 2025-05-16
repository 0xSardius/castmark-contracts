// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title CastmarkRegistry
 * @dev A registry for collections with ownership tracking and administrative functions
 * @author sardius
 * @notice This contract allows users to register and manage collection metadata
 */
contract CastmarkRegistry is Ownable(msg.sender), Pausable, ReentrancyGuard {
    // Version for tracking upgrades
    string public constant VERSION = "1.0.0";

    // Max length constraints
    uint256 public constant MAX_ID_LENGTH = 64;
    uint256 public constant MAX_NAME_LENGTH = 128;
    uint256 public constant MAX_URL_LENGTH = 256;

    // Mapping of collection IDs to their registration status
    mapping(bytes32 => bool) public registeredCollections;

    // Mapping of collection IDs to metadata
    mapping(bytes32 => CollectionData) public collectionData;

    // Struct for collection data
    struct CollectionData {
        string name;
        string url;
        address owner;
        uint256 timestamp;
        bool exists;
    }

    // Events
    event CollectionRegistered(
        bytes32 indexed collectionIdHash,
        string collectionId,
        string name,
        string url,
        address indexed registeredBy,
        uint256 timestamp
    );

    event CollectionUpdated(
        bytes32 indexed collectionIdHash, string name, string url, address indexed updatedBy, uint256 timestamp
    );

    event CollectionTransferred(
        bytes32 indexed collectionIdHash, address indexed previousOwner, address indexed newOwner, uint256 timestamp
    );

    event CollectionRemoved(bytes32 indexed collectionIdHash, address indexed removedBy, uint256 timestamp);

    /**
     * @dev Constructor sets the deployer as the owner
     */
    constructor() {
        _transferOwnership(msg.sender);
    }

    /**
     * @dev Hash a collection ID string to bytes32 for storage efficiency
     * @param collectionId The collection ID to hash
     * @return The keccak256 hash of the collection ID
     */
    function _hashCollectionId(string calldata collectionId) internal pure returns (bytes32) {
        return keccak256(bytes(collectionId));
    }

    /**
     * @dev Validate string length
     * @param str The string to validate
     * @param maxLength The maximum allowed length
     */
    function _validateStringLength(string calldata str, uint256 maxLength) internal pure {
        require(bytes(str).length > 0, "String cannot be empty");
        require(bytes(str).length <= maxLength, "String exceeds maximum length");
    }

    /**
     * @dev Register a new collection
     * @param collectionId Unique identifier for the collection
     * @param name The name of the collection
     * @param url The URL associated with the collection
     */
    function registerCollection(string calldata collectionId, string calldata name, string calldata url)
        external
        whenNotPaused
        nonReentrant
    {
        _validateStringLength(collectionId, MAX_ID_LENGTH);
        _validateStringLength(name, MAX_NAME_LENGTH);
        _validateStringLength(url, MAX_URL_LENGTH);

        bytes32 collectionIdHash = _hashCollectionId(collectionId);
        require(!registeredCollections[collectionIdHash], "Collection already registered");

        // Store registration status
        registeredCollections[collectionIdHash] = true;

        // Store collection data
        collectionData[collectionIdHash] =
            CollectionData({name: name, url: url, owner: msg.sender, timestamp: block.timestamp, exists: true});

        // Emit event
        emit CollectionRegistered(collectionIdHash, collectionId, name, url, msg.sender, block.timestamp);
    }

    /**
     * @dev Update an existing collection's metadata
     * @param collectionId The collection ID to update
     * @param name The new name
     * @param url The new URL
     */
    function updateCollection(string calldata collectionId, string calldata name, string calldata url)
        external
        whenNotPaused
        nonReentrant
    {
        _validateStringLength(name, MAX_NAME_LENGTH);
        _validateStringLength(url, MAX_URL_LENGTH);

        bytes32 collectionIdHash = _hashCollectionId(collectionId);
        require(registeredCollections[collectionIdHash], "Collection not registered");
        require(collectionData[collectionIdHash].owner == msg.sender, "Not collection owner");

        // Update collection data
        collectionData[collectionIdHash].name = name;
        collectionData[collectionIdHash].url = url;
        collectionData[collectionIdHash].timestamp = block.timestamp;

        // Emit event
        emit CollectionUpdated(collectionIdHash, name, url, msg.sender, block.timestamp);
    }

    /**
     * @dev Transfer ownership of a collection to another address
     * @param collectionId The collection ID to transfer
     * @param newOwner The address of the new owner
     */
    function transferCollectionOwnership(string calldata collectionId, address newOwner)
        external
        whenNotPaused
        nonReentrant
    {
        require(newOwner != address(0), "New owner cannot be zero address");

        bytes32 collectionIdHash = _hashCollectionId(collectionId);
        require(registeredCollections[collectionIdHash], "Collection not registered");
        require(collectionData[collectionIdHash].owner == msg.sender, "Not collection owner");

        address previousOwner = collectionData[collectionIdHash].owner;
        collectionData[collectionIdHash].owner = newOwner;

        emit CollectionTransferred(collectionIdHash, previousOwner, newOwner, block.timestamp);
    }

    /**
     * @dev Remove a collection from the registry
     * @param collectionId The collection ID to remove
     */
    function removeCollection(string calldata collectionId) external nonReentrant {
        bytes32 collectionIdHash = _hashCollectionId(collectionId);
        require(registeredCollections[collectionIdHash], "Collection not registered");

        CollectionData storage data = collectionData[collectionIdHash];
        require(data.owner == msg.sender || owner() == msg.sender, "Not authorized");

        registeredCollections[collectionIdHash] = false;
        data.exists = false;

        emit CollectionRemoved(collectionIdHash, msg.sender, block.timestamp);
    }

    /**
     * @dev Check if a collection is registered
     * @param collectionId The collection ID to check
     * @return bool Registration status
     */
    function isRegistered(string calldata collectionId) external view returns (bool) {
        bytes32 collectionIdHash = _hashCollectionId(collectionId);
        return registeredCollections[collectionIdHash];
    }

    /**
     * @dev Get collection data
     * @param collectionId The collection ID to query
     * @return CollectionData The collection metadata
     */
    function getCollectionData(string calldata collectionId) external view returns (CollectionData memory) {
        bytes32 collectionIdHash = _hashCollectionId(collectionId);
        require(registeredCollections[collectionIdHash], "Collection not registered");
        require(collectionData[collectionIdHash].exists, "Collection has been removed");
        return collectionData[collectionIdHash];
    }

    /**
     * @dev Batch register multiple collections (gas optimization)
     * @param collectionIds Array of collection IDs
     * @param names Array of collection names
     * @param urls Array of collection URLs
     */
    function batchRegisterCollections(string[] calldata collectionIds, string[] calldata names, string[] calldata urls)
        external
        whenNotPaused
        nonReentrant
    {
        require(collectionIds.length == names.length && names.length == urls.length, "Array lengths must match");

        for (uint256 i = 0; i < collectionIds.length; i++) {
            _validateStringLength(collectionIds[i], MAX_ID_LENGTH);
            _validateStringLength(names[i], MAX_NAME_LENGTH);
            _validateStringLength(urls[i], MAX_URL_LENGTH);

            bytes32 collectionIdHash = _hashCollectionId(collectionIds[i]);
            require(!registeredCollections[collectionIdHash], "Collection already registered");

            // Store registration status
            registeredCollections[collectionIdHash] = true;

            // Store collection data
            collectionData[collectionIdHash] = CollectionData({
                name: names[i],
                url: urls[i],
                owner: msg.sender,
                timestamp: block.timestamp,
                exists: true
            });

            // Emit event
            emit CollectionRegistered(
                collectionIdHash, collectionIds[i], names[i], urls[i], msg.sender, block.timestamp
            );
        }
    }

    /**
     * @dev Pause the contract in case of emergency
     * @notice Only the owner can call this function
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     * @notice Only the owner can call this function
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
