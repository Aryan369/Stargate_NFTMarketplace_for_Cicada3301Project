// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../access/Ownable.sol";
import '../interfaces/IMarketplace.sol';
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract StandardNFT is ERC721URIStorage, Ownable, ERC2981 {

    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;

    address marketplaceContractAddress;

    constructor(address marketContract) ERC721("Stargate", "STARGATE") {
        marketplaceContractAddress = marketContract;
        _setDefaultRoyalty(address(this), 0);
    }

    function setMarketplaceContract (address marketContract) public onlyOwner{
        marketplaceContractAddress = marketContract;
    }

    function mintNFT(
        string memory tokenURI,
        uint96 _royalty //1 = 0.01% (basis points)
    ) public payable returns(uint) {
        require(msg.value == IMarketplace(marketplaceContractAddress).getMintingFee(), "StandardNFT: Enough ether not sent.");
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(msg.sender, newTokenId);
        _setTokenRoyalty(newTokenId, msg.sender, _royalty);
        _setTokenURI(newTokenId, tokenURI);
        setApprovalForAll(marketplaceContractAddress, true);
        return newTokenId;
    }

    function withdraw(address _address) public payable onlyOwner() {
        require(payable(_address).send(address(this).balance), "StandardNFT: withdraw transaction failed.");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}