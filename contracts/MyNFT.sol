// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MyNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    // contract inherits from ERC721, ERC721Enumerable, ERC721URIStorage and Ownable contracts
    using Counters for Counters.Counter;

    struct ListedNFT {
        // struct to store NFT details for sale
        address seller; // seller address
        uint256 price; // sale price
        string url; // NFT URI
    }

    mapping(uint256 => ListedNFT) private _activeItem; // map NFT tokenId to ListedNFT struct, _activeItem store array of item listed into marketplace

    Counters.Counter private _tokenIdCounter; // counter to generate unique token ids

    constructor() ERC721("MyNFT", "MNFT") {} // constructor to initialize the contract with name "MyNFT" and symbol "MNFT"

    event NftListingCancelled(uint256 indexed tokenId, address indexed caller); // event emitted when an NFT listing is cancelled
    event NftListed(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    ); // event emitted when an NFT is listed for sale
    event NftListingUpdated(
        uint256 indexed tokenId,
        address indexed caller,
        uint256 newPrice
    ); // event emitted when an NFT listing is updated
    event NftBought(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    ); // event emitted when an NFT is bought

    modifier notListed(uint256 tokenId) {
        // modifier to check if an NFT is not listed for sale
        ListedNFT memory listing = _activeItem[tokenId];

        if (listing.price > 0) {
            revert("Already listed");
        }
        _;
    }

    modifier isListed(uint256 tokenId) {
        // modifier to check if an NFT is listed for sale
        ListedNFT memory listing = _activeItem[tokenId];

        if (listing.price <= 0) {
            revert("Not listed");
        }
        _;
    }

    modifier isOwner(uint256 tokenId, address spender) {
        // modifier to check if the caller is the owner of the NFT
        address owner = ownerOf(tokenId);
        if (spender != owner) {
            revert("You are not the owner");
        }
        _;
    }

    function createNft(address to, string memory uri) public {
        // function to create a new NFT
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId); // mint a new NFT and assign it to the given address
        _setTokenURI(tokenId, uri); // set the URI of the NFT
    }

    function listNft(
        uint256 tokenId,
        uint256 price
    ) public notListed(tokenId) isOwner(tokenId, msg.sender) {
        // function to list NFT into the marketplace
        require(_exists(tokenId), "Token does not exist"); // check nft exist

        string memory _url = tokenURI(tokenId);
        _activeItem[tokenId] = ListedNFT(msg.sender, price, _url); // push item into the array that store listedItem

        emit NftListed(tokenId, msg.sender, price);
    }

    function cancelListing(
        uint256 tokenId
    ) public isListed(tokenId) isOwner(tokenId, msg.sender) {
        // function to delete item in the array
        // in front-end, we can check bacause _activeItem[tokenId].seller is "0x000000000000000000000000000000000000000"
        delete _activeItem[tokenId];

        emit NftListingCancelled(tokenId, msg.sender);
    }

    function updateListing(
        uint256 tokenId,
        uint256 newPrice
    ) public isListed(tokenId) isOwner(tokenId, msg.sender) {
        // function to update price of NFT

        _activeItem[tokenId].price = newPrice;

        emit NftListingUpdated(
            _activeItem[tokenId].price,
            msg.sender,
            newPrice
        );
    }

    function buyNft(uint256 tokenId) public payable isListed(tokenId) {
        // function to transfer NFT ownership when someone buy it

        require(_activeItem[tokenId].seller != address(0), "Token not listed");
        require(
            msg.sender != _activeItem[tokenId].seller,
            "Can Not buy your own NFT"
        );

        require(msg.value >= _activeItem[tokenId].price, "Not enough money!");

        ListedNFT memory listedItem = _activeItem[tokenId];

        delete _activeItem[tokenId]; // when buy successfully, the new owner need to list again that it could be in the marketplace
        _transfer(listedItem.seller, msg.sender, tokenId);

        // Send the correct amount of wei to the seller
        (bool success, ) = payable(listedItem.seller).call{value: msg.value}(
            ""
        );
        require(success, "Payment failed");

        emit NftBought(tokenId, listedItem.seller, msg.sender, msg.value);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        // function go get URI of created NFT
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getActiveItem(
        uint256 tokenId
    ) public view returns (ListedNFT memory) {
        // function to get the array that store item that listed
        return _activeItem[tokenId];
    }
}
