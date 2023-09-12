// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract GotasNFTMarketplace is Ownable, ReentrancyGuard, Pausable {
    struct Listing {
        address nftContractAddress;
        uint256 nftId;
        address seller;
        uint256 price;
        uint256 deadline;
    }

    uint256[] public activeListingIds;
    uint256 public royaltyPercentage;
    uint256 public platformFeePercentage;

    address public royaltyAddress;
    address public platformFeeAddress;

    mapping(uint256 => Listing) public listings;

    uint256 public nextListingId = 1;

    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContractAddress, uint256 nftId, uint256 price, uint256 deadline);
    event NFTSold(uint256 indexed listingId, address indexed seller, address indexed buyer, uint256 price);
    event NFTDelisted(uint256 indexed listingId);

    constructor(uint256 _royaltyPercentage, uint256 _platformFeePercentage, address _royaltyAddress, address _platformFeeAddress) {
        require(_royaltyAddress != address(0) && _platformFeeAddress != address(0), "Addresses cannot be zero");
        royaltyPercentage = _royaltyPercentage;
        platformFeePercentage = _platformFeePercentage;
        royaltyAddress = _royaltyAddress;
        platformFeeAddress = _platformFeeAddress;
    }

    function listNFT(address nftContractAddress, uint256 nftId, uint256 price, uint256 deadline) external whenNotPaused nonReentrant {
        require(price > 0, "Price must be greater than zero.");
        require(deadline > 0, "Deadline must be greater than zero.");

        IERC721 nftContract = IERC721(nftContractAddress);
        require(nftContract.ownerOf(nftId) == msg.sender, "You must own the NFT to list it.");

        listings[nextListingId] = Listing({
            nftContractAddress: nftContractAddress,
            nftId: nftId,
            seller: msg.sender,
            price: price,
            deadline: block.timestamp + deadline
        });

        activeListingIds.push(nextListingId);

        emit NFTListed(nextListingId, msg.sender, nftContractAddress, nftId, price, block.timestamp + deadline);
        nextListingId++;
    }

    function buyNFT(uint256 listingId) external payable whenNotPaused nonReentrant {
        address seller;

        require(msg.value > 0, "Sent value must be greater than zero.");

        Listing storage listing = listings[listingId];
        require(listing.seller != address(0), "Listing does not exist.");
        require(block.timestamp <= listing.deadline, "This listing has expired.");
        require(msg.value == listing.price, "Sent value must be equal to the listing price.");

        uint256 royaltyAmount = (royaltyPercentage * listing.price) / 10000;
        uint256 platformFee = (platformFeePercentage * listing.price) / 10000;
        uint256 sellerAmount = listing.price - royaltyAmount - platformFee;

        seller = listing.seller;

        IERC721 nftContract = IERC721(listing.nftContractAddress);
        require(nftContract.ownerOf(listing.nftId) == seller, "Seller no longer owns the NFT.");

        // Check-Effects-Interactions pattern
        delete listings[listingId];
        
        nftContract.safeTransferFrom(seller, msg.sender, listing.nftId);

        payable(seller).transfer(sellerAmount);
        payable(royaltyAddress).transfer(royaltyAmount);
        payable(platformFeeAddress).transfer(platformFee);

        emit NFTSold(listingId, listing.seller, msg.sender, listing.price);
    }

    function pause() external onlyOwner nonReentrant {
        _pause();
    }

    function unpause() external onlyOwner nonReentrant {
        _unpause();
    }

    function updateFeeAddresses(address newRoyaltyAddress, address newPlatformFeeAddress) external onlyOwner nonReentrant {
        require(newRoyaltyAddress != address(0) && newPlatformFeeAddress != address(0), "Addresses cannot be zero");
        require(newRoyaltyAddress != msg.sender && newPlatformFeeAddress != msg.sender, "Addresses cannot be the contract owner");
        royaltyAddress = newRoyaltyAddress;
        platformFeeAddress = newPlatformFeeAddress;
    }

    function updateFeePercentages(uint256 newRoyaltyPercentage, uint256 newPlatformFeePercentage) external onlyOwner nonReentrant {
        royaltyPercentage = newRoyaltyPercentage;
        platformFeePercentage = newPlatformFeePercentage;
    }
}
