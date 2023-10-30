// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract Marketplace is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _nftsSold;
    Counters.Counter private _listingIds;
    Counters.Counter private _delistedListings;

    uint256 _platformFee = 500; // 100 = 1%
    uint256 _mintingFee = 0.001 ether;

    struct Listing {
        uint listingId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        uint256 price;
        bool onSale;
    }

    mapping(uint256 => Listing) private idToListing;

    event ListingCreated (
        uint indexed listingId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 price,
        bool onSale
    );

    event ListingCanceled (
        uint indexed listingId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );

    event NFTBought(
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );


    function createListing(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        require(price > 0, "Price cannot be zero");
        _listingIds.increment();
        uint256 listingId = _listingIds.current();
        idToListing[listingId] = Listing(listingId, nftContract, tokenId, payable(msg.sender), price, true);
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        emit ListingCreated(listingId, nftContract, tokenId, msg.sender, price, true);
    }

    function cancelListing(uint256 listingId) public nonReentrant {
        require(idToListing[listingId].seller == msg.sender, "You are not the owner");
        IERC721(idToListing[listingId].nftContract).transferFrom(address(this), msg.sender, idToListing[listingId].tokenId);
        
        Listing memory _listing = idToListing[listingId];
        emit ListingCanceled(_listing.listingId, _listing.nftContract, _listing.tokenId, msg.sender, _listing.price);
        delete idToListing[listingId];
        _delistedListings.increment();
    }

    function buyNFT(uint256 listingId) public payable nonReentrant {
        uint price = idToListing[listingId].price;
        uint tokenId = idToListing[listingId].tokenId;
        require(msg.value == price, "Not enough balance to complete transaction");

        (uint256 platformFee, uint256 royaltiesAmount, uint256 netSaleAmt, address artist) = calculateFees(price, idToListing[listingId].nftContract, tokenId);
        idToListing[listingId].seller.transfer(netSaleAmt);
        if (royaltiesAmount > 0) {
            payable(artist).transfer(royaltiesAmount);
        }

        IERC721(idToListing[listingId].nftContract).transferFrom(address(this), msg.sender, tokenId);
        emit NFTBought(idToListing[listingId].nftContract, tokenId, idToListing[listingId].seller, price);
        delete idToListing[listingId];
        _nftsSold.increment();
    }



    // ----------- ROYALTY -------------

    function _checkRoyalties(address _contract) internal view returns (bool) {
        (bool success) = IERC2981(_contract).supportsInterface(0x2a55205a);
        return success;
    }

    // ----------- Platform Fees -------------

    function calculateFees(
        uint256 _saleAmt, 
        address _nftcontract, 
        uint256 tokenId
    ) public view 
    returns (
        uint256 platformFee, 
        uint256 royaltiesAmount, 
        uint256 netSaleAmount,
        address artist
    ){
        platformFee = _saleAmt * (_platformFee / 10000);

        if(_checkRoyalties(_nftcontract)){
            (address _artist , uint256 _royaltiesAmount) = IERC2981(_nftcontract).royaltyInfo(tokenId, _saleAmt);
            artist = _artist;
            royaltiesAmount = _royaltiesAmount;
        }
        else {
            royaltiesAmount = 0;
            artist = address(0);
        }

        netSaleAmount = _saleAmt - (platformFee + royaltiesAmount);
    }

    function getPlatformFee() external view returns (uint256) {
        return _platformFee;
    }

    function setPlatformFee(uint256 _fee) public onlyOwner {
        _platformFee = _fee;
    }

    function getMintingFee() external view returns (uint256) {
        return _mintingFee;
    }

    function setMintingFee(uint256 _fee) public onlyOwner {
        _mintingFee = _fee;
    }


    // ============ WITHDRAW =================

    function withdraw(address _address) public payable onlyOwner() {
        require(payable(_address).send(address(this).balance), "Marketplace: withdraw transaction failed.");
    }


    // ========================================


    function getListedNft() public view returns (Listing[] memory) {
        uint itemCount = _listingIds.current();
        uint unsoldItemCount = _listingIds.current() - (_nftsSold.current() + _delistedListings.current());
        uint currentIndex = 0;

        Listing[] memory listings = new Listing[](unsoldItemCount);
        for (uint i = 0; i < itemCount; i++) {
            if (idToListing[i + 1].onSale) {
                uint currentId = i + 1;
                Listing storage currentItem = idToListing[currentId];
                listings[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return listings;
    }

    function getMyListedNft() public view returns (Listing[] memory) {
        uint totalItemCount = _listingIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToListing[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        Listing[] memory listings = new Listing[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (idToListing[i + 1].seller == msg.sender) {
                uint currentId = i + 1;
                Listing storage currentItem = idToListing[currentId];
                listings[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        
        return listings;
    }
}