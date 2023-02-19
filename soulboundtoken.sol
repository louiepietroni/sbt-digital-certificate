// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// Import contract standards from openzeppelin
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

// The 5485 interface
interface IERC5484 {
    /// A guideline to standardlize burn-authorization's number coding
    enum BurnAuth {
        IssuerOnly,
        OwnerOnly,
        Both,
        Neither
    }

    /// @notice Emitted when a soulbound token is issued.
    /// @dev This emit is an add-on to nft's transfer emit in order to distinguish sbt
    /// from vanilla nft while providing backward compatibility.
    /// @param from The issuer
    /// @param to The receiver
    /// @param tokenId The id of the issued token
    event Issued(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        BurnAuth burnAuth
    );

    /// @notice provides burn authorization of the token id.
    /// @dev unassigned tokenIds are invalid, and queries do throw
    /// @param tokenId The identifier for a token.
    function burnAuth(uint256 tokenId) external view returns (BurnAuth);
}

contract SoulBoundToken is ERC721, ERC721URIStorage, ERC721Enumerable, IERC5484 {
    // Setup a counter for the tokenID
    using Counters for Counters.Counter;
    Counters.Counter private tokenIdCounter;

    // Define the extra mappings from tokenId to extra data
    mapping(uint256 => BurnAuth) private burnAuths;
    mapping(uint256 => address) private issuers;

    // Define a struct to represent an offer
    struct Offer {
        address issuer;
        string offerURI;
        BurnAuth burnAuth;
    }

    // Define the mapping for offers
    mapping(address => Offer[]) private offers;

    // The constructor for the contract to give it name, symbol
    constructor() ERC721("SoulBoundToken", "SBT") {}

    /// @notice Creates an offer of a certificate which can be accepted or declined by the receiver
    /// @dev Throws if the provided burn auth is invalid
    /// @param to The address to offer the certificate to
    /// @param offerURI URI to the IPFS file of the certificate
    /// @param burnAuthIndex 0-3 Representing the burn auth of this token
    function offer(
        address to,
        string memory offerURI,
        uint8 burnAuthIndex
    ) public {
        // The burn auth passed in is 0 - 3 corresponding to the auths. We need to convert it to burnauth enum
        BurnAuth _burnAuth;
        if (burnAuthIndex == 0) {
            _burnAuth = BurnAuth.IssuerOnly;
        } else if (burnAuthIndex == 1) {
            _burnAuth = BurnAuth.OwnerOnly;
        } else if (burnAuthIndex == 2) {
            _burnAuth = BurnAuth.Both;
        } else if (burnAuthIndex == 3) {
            _burnAuth = BurnAuth.Neither;
        } else {
            revert("Burn Auth index must be between 0 and 3");
        }
        // Create a new offer and record it by adding to the address to offers mapping
        offers[to].push(Offer(msg.sender, offerURI, _burnAuth));
    }
    
    /// @notice Deletes an offer
    /// @dev Throws if there is no offer at the given index
    /// @param index The index of the offer to accept
    function deleteOfferByIndex(uint256 index) internal {
        // Check that an offer exists at this index
        require(index < offers[msg.sender].length, "Invalid offer index, does not exist");
        // Deleting from dynamic array doesn't shorten array, we overwrite the element with the last item, then truncate the array
        // Copy the last element into the index to delete from
        offers[msg.sender][index] = offers[msg.sender][offers[msg.sender].length - 1];
        // Remove the last element and shorten the array
        offers[msg.sender].pop();
    }

    /// @notice Rejects an offer
    /// @dev Throws if there is no offer at the given index
    /// @param index The index of the offer to accept
    function reject (uint256 index) public {
        // Check an offer exists at the index
        require(index < offers[msg.sender].length, "Invalid offer index, does not exist");
        // Delete the offer at index, using function to ensure that the array gets resized
        deleteOfferByIndex(index);
    }

    /// @notice Gets the number of offers for the sender's address
    /// @dev -
    function getNumberOfOffers () public view returns (uint256) {
        // Returns the length of the offer list
        return offers[msg.sender].length;
    }

    /// @notice Gets an offer at an index
    /// @dev Throws if there is no offer at the given index
    /// @param index The index of the offer to accept
    function getOfferByIndex (uint256 index) public view returns (Offer memory) {
        // Check an offer exists at the index
        require(index < offers[msg.sender].length, "Invalid offer index, does not exist");
        // Delete the offer at index, using function to ensure array resized correctly
        return offers[msg.sender][index];
    }


    /// @notice Accepts an offer
    /// @dev Throws if there is no offer at the given index
    /// @param index The index of the offer to accept
    function accept (uint256 index) public {
        // Check an offer exists at the index
        require(index < offers[msg.sender].length, "Invalid offer index, does not exist");

        // Get the tokenID of this token and increment
        uint256 tokenId = tokenIdCounter.current();
        tokenIdCounter.increment();

        // Get the offer which we are going to mint
        Offer memory offerToMint = offers[msg.sender][index];

        // Mint the token
        _safeMint(msg.sender, tokenId);

        // Store the URI, burnAuth and issuer in the respective mappings
        _setTokenURI(tokenId, offerToMint.offerURI);
        burnAuths[tokenId] = offerToMint.burnAuth;
        issuers[tokenId] = offerToMint.issuer;

        // Delete the offer at the index, using function to ensure resized correcly
        deleteOfferByIndex(index);

        // Emit the issued event in line with interface 5484 requirements to make clear that this is an SBT
        emit Issued(offerToMint.issuer, msg.sender, tokenId, offerToMint.burnAuth);
    }

    /// @notice Burns the specified token if caller has authority
    /// @dev Throws if the caller doesn't have authority for this token
    /// @param tokenId The identifier for a token
    function burn(uint256 tokenId) external {
        // Get the addresses of issuer and owner for this token
        address _issuer = issuers[tokenId];
        address owner = ownerOf(tokenId);

        // Get the burn auth of this token
        BurnAuth _burnAuth = burnAuths[tokenId];

        // Check that the burn auth is valid for this token
        require(
            (_burnAuth == BurnAuth.Both &&
                (msg.sender == _issuer || msg.sender == owner)) ||
                (_burnAuth == BurnAuth.IssuerOnly && msg.sender == _issuer) ||
                (_burnAuth == BurnAuth.OwnerOnly && msg.sender == owner),
            "The set burnAuth doesn't allow you to burn this token"
        );

        // Delete the instances in the mapping
        delete issuers[tokenId];
        delete burnAuths[tokenId];
        // Burn the token
        _burn(tokenId);
    }


    // // This hooks in before a transfer and only allows it to go through for mint or burn
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override(ERC721, ERC721Enumerable) {
        // We only allow transfer if from 0 address (mint) or to 0 address (burn)
        require(from == address(0) || to == address(0), "SBT can't be transferred");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }


    /// @notice provides burn authorization of the token id.
    /// @dev unassigned tokenIds are invalid, and queries do throw
    /// @param tokenId The identifier for a token.
    function burnAuth(uint256 tokenId) external view override returns (BurnAuth) {
        return burnAuths[tokenId];
    }

    /// @notice Calls the super burn
    /// @dev -
    /// @param tokenId The identifier for a token.
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /// @notice Gets the owner of a token
    /// @dev unassigned tokenIds are invalid, and queries do throw
    /// @param tokenId The identifier for a token.
    function ownerOf(uint256 tokenId) public view override(ERC721) returns (address) {
        return super.ownerOf(tokenId);
    }

    /// @notice provides URI of the token id - where the certificate metadata is stored
    /// @dev unassigned tokenIds are invalid, and queries do throw
    /// @param tokenId The identifier for a token.
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /// @notice provides issuer of the token id.
    /// @dev unassigned tokenIds are invalid, and queries do throw
    /// @param tokenId The identifier for a token.
    function issuer(uint256 tokenId) external view returns (address) {
        return issuers[tokenId];
    }

    /// @notice Necessary function override to show this contract is enumerable
    /// @dev -
    /// @param interfaceId The interface
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}