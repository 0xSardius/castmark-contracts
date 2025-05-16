// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/CastmarkRegistry.sol";

contract CastmarkRegistryTest is Test {
    CastmarkRegistry public registry;
    address public owner;
    address public user1;
    address public user2;

    // Test collection data
    string public collectionId = "test-collection";
    string public name = "Test Collection";
    string public url = "https://example.com/test";

    // Updated collection data
    string public newName = "Updated Collection";
    string public newUrl = "https://example.com/updated";

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // Deploy the registry
        registry = new CastmarkRegistry();

        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testRegisterCollection() public {
        vm.startPrank(user1);
        registry.registerCollection(collectionId, name, url);
        vm.stopPrank();

        // Assert collection is registered
        assertTrue(registry.isRegistered(collectionId));

        // Assert collection data is correct
        CastmarkRegistry.CollectionData memory data = registry.getCollectionData(collectionId);
        assertEq(data.name, name);
        assertEq(data.url, url);
        assertEq(data.owner, user1);
        assertTrue(data.exists);
    }

    function testCannotRegisterSameCollectionTwice() public {
        vm.startPrank(user1);
        registry.registerCollection(collectionId, name, url);

        // Try to register again
        vm.expectRevert("Collection already registered");
        registry.registerCollection(collectionId, name, url);
        vm.stopPrank();
    }

    function testUpdateCollection() public {
        // Register
        vm.startPrank(user1);
        registry.registerCollection(collectionId, name, url);

        // Update
        registry.updateCollection(collectionId, newName, newUrl);
        vm.stopPrank();

        // Assert updated data
        CastmarkRegistry.CollectionData memory data = registry.getCollectionData(collectionId);
        assertEq(data.name, newName);
        assertEq(data.url, newUrl);
    }

    function testOnlyOwnerCanUpdateCollection() public {
        // Register as user1
        vm.prank(user1);
        registry.registerCollection(collectionId, name, url);

        // Try to update as user2
        vm.startPrank(user2);
        vm.expectRevert("Not collection owner");
        registry.updateCollection(collectionId, newName, newUrl);
        vm.stopPrank();
    }

    function testTransferCollectionOwnership() public {
        // Register as user1
        vm.prank(user1);
        registry.registerCollection(collectionId, name, url);

        // Transfer to user2
        vm.prank(user1);
        registry.transferCollectionOwnership(collectionId, user2);

        // Assert new owner
        CastmarkRegistry.CollectionData memory data = registry.getCollectionData(collectionId);
        assertEq(data.owner, user2);

        // Now user2 can update
        vm.prank(user2);
        registry.updateCollection(collectionId, newName, newUrl);
    }

    function testRemoveCollection() public {
        // Register
        vm.prank(user1);
        registry.registerCollection(collectionId, name, url);

        // Remove
        vm.prank(user1);
        registry.removeCollection(collectionId);

        // Still registered but marked as removed
        assertTrue(registry.isRegistered(collectionId));

        // Cannot get data for removed collection
        vm.expectRevert("Collection has been removed");
        registry.getCollectionData(collectionId);
    }

    function testPauseUnpause() public {
        // Pause the contract
        registry.pause();

        // Try to register while paused
        vm.startPrank(user1);
        vm.expectRevert("Pausable: paused");
        registry.registerCollection(collectionId, name, url);
        vm.stopPrank();

        // Unpause
        registry.unpause();

        // Now can register
        vm.prank(user1);
        registry.registerCollection(collectionId, name, url);
    }

    function testBatchRegister() public {
        string[] memory ids = new string[](3);
        string[] memory names = new string[](3);
        string[] memory urls = new string[](3);

        ids[0] = "collection-1";
        ids[1] = "collection-2";
        ids[2] = "collection-3";

        names[0] = "Collection 1";
        names[1] = "Collection 2";
        names[2] = "Collection 3";

        urls[0] = "https://example.com/1";
        urls[1] = "https://example.com/2";
        urls[2] = "https://example.com/3";

        vm.prank(user1);
        registry.batchRegisterCollections(ids, names, urls);

        // Check all are registered
        assertTrue(registry.isRegistered(ids[0]));
        assertTrue(registry.isRegistered(ids[1]));
        assertTrue(registry.isRegistered(ids[2]));
    }

    function testStringValidation() public {
        // Create oversized string
        string memory longString = "";
        for (uint256 i = 0; i < 65; i++) {
            longString = string.concat(longString, "a");
        }

        // Try to register with too long collection ID
        vm.startPrank(user1);
        vm.expectRevert("String exceeds maximum length");
        registry.registerCollection(longString, name, url);
        vm.stopPrank();
    }
}
