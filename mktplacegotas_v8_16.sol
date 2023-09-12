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

    mapping(address => bool) public isWhitelisted;

    mapping(uint256 => Listing) public listings;

    uint256 public nextListingId = 1;

    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 nftId, uint256 price, uint256 deadline);
    event NFTSold(uint256 indexed listingId, address indexed seller, address indexed buyer, uint256 price);
    event NFTDelisted(uint256 indexed listingId);

    constructor(uint256 _royaltyPercentage, uint256 _platformFeePercentage, address _royaltyAddress, address _platformFeeAddress) {
        require(_royaltyAddress != address(0) && _platformFeeAddress != address(0), "Addresses cannot be zero");
        royaltyPercentage = _royaltyPercentage;
        platformFeePercentage = _platformFeePercentage;
        royaltyAddress = _royaltyAddress;
        platformFeeAddress = _platformFeeAddress;

        isWhitelisted[_royaltyAddress] = true;
        isWhitelisted[_platformFeeAddress] = true;
    }

    function addToWhitelist(address _address) external onlyOwner {
        isWhitelisted[_address] = true;
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        isWhitelisted[_address] = false;
    }

    function listNFT(address _nftContractAddress, uint256 _nftId, uint256 _price, uint256 _deadline) external whenNotPaused nonReentrant {
        require(_price > 0, "Price must be greater than zero.");
        require(_deadline > 0, "Deadline must be greater than zero.");

        IERC721 nftContract = IERC721(_nftContractAddress);
        require(nftContract.ownerOf(_nftId) == msg.sender, "You must own the NFT to list it.");

        listings[nextListingId] = Listing({
            nftContractAddress: _nftContractAddress,
            nftId: _nftId,
            seller: msg.sender,
            price: _price,
            deadline: block.timestamp + _deadline
        });

        activeListingIds.push(nextListingId);

        emit NFTListed(nextListingId, msg.sender, _nftContractAddress, _nftId, _price, block.timestamp + _deadline);
        nextListingId++;
    }

    function buyNFT(uint256 _listingId) external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "Sent value must be greater than zero.");

        Listing storage listing = listings[_listingId];
        require(listing.seller != address(0), "Listing does not exist.");
        require(block.timestamp <= listing.deadline, "This listing has expired.");
        require(msg.value == listing.price, "Sent value must be equal to the listing price.");

        require(isWhitelisted[royaltyAddress], "Royalty address is not whitelisted");
        require(isWhitelisted[platformFeeAddress], "Platform fee address is not whitelisted");

        uint256 royaltyAmount = royaltyPercentage / 10000 * listing.price;
        uint256 platformFee = platformFeePercentage / 10000 * listing.price;
        uint256 sellerAmount = listing.price - royaltyAmount - platformFee;

        address seller = listing.seller;

        IERC721 nftContract = IERC721(listing.nftContractAddress);
        require(nftContract.ownerOf(listing.nftId) == seller, "Seller no longer owns the NFT.");

        nftContract.safeTransferFrom(seller, msg.sender, listing.nftId);

        payable(seller).transfer(sellerAmount);
        payable(royaltyAddress).transfer(royaltyAmount);
        payable(platformFeeAddress).transfer(platformFee);

        emit NFTSold(_listingId, listing.seller, msg.sender, listing.price);

        delete listings[_listingId];
    }

    function pause() external onlyOwner nonReentrant {
        _pause();
    }

    function unpause() external onlyOwner nonReentrant {
        _unpause();
    }

    function updateFeeAddresses(address _newRoyaltyAddress, address _newPlatformFeeAddress) external onlyOwner nonReentrant {
        require(_newRoyaltyAddress != address(0) && _newPlatformFeeAddress != address(0), "Addresses cannot be zero");
        royaltyAddress = _newRoyaltyAddress;
        platformFeeAddress = _newPlatformFeeAddress;
    }

    function updateFeePercentages(uint256 _newRoyaltyPercentage, uint256 _newPlatformFeePercentage) external onlyOwner nonReentrant {
        royaltyPercentage = _newRoyaltyPercentage;
        platformFeePercentage = _newPlatformFeePercentage;
    }
}
