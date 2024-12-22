// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract EthanNft is ERC721 {
    error EthanNft__TokenUriNotFound();

    mapping(uint256 => string ) private s_tokenIdToUri;
    uint256 private s_tokenCounter;
    string private i_tokenUri;

    constructor(string memory tokenUri) ERC721("Ethan", "EA") {
        s_tokenCounter = 0;
        i_tokenUri = tokenUri;
    }

    // 
    function mintNft(address to) public {
        s_tokenIdToUri[s_tokenCounter] = i_tokenUri;
        _safeMint(to, s_tokenCounter);
        s_tokenCounter++;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert EthanNft__TokenUriNotFound();
        }
        return s_tokenIdToUri[tokenId];
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}
