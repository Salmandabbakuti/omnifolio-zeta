// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/OnlySystem.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract OmniFolio is zContract, ERC721, OnlySystem {
    SystemContract public systemContract;
    error CallerNotOwnerNotApproved();
    uint256 constant BITCOIN = 18332;
    uint256 currentTokenId = 1;

    struct Profile {
        uint256 tokenId;
        string name;
        string handle;
        string bio;
        string avatar;
        address owner;
        string[] linkKeys;
        mapping(string => string) links;
    }

    mapping(uint256 => uint256) public tokenAmounts;
    mapping(uint256 => uint256) public tokenChains;
    mapping(uint256 tokenId => Profile profile) public profiles;
    mapping(string handle => uint256 tokenId) public handleToTokenId;
    mapping(string handle => bool isExists) public profileExists;
    mapping(address user => uint256 tokenId) public tokenIdOfUser;

    event ProfileCreated(
        uint256 indexed tokenId,
        string name,
        string handle,
        string bio,
        string avatar,
        address owner,
        string[] linkKeys,
        string[] links
    );

    event ProfileUpdated(
        uint256 indexed tokenId,
        string name,
        string handle,
        string bio,
        string avatar,
        address owner,
        string[] linkKeys,
        string[] links
    );

    event ProfileDeleted(uint256 indexed tokenId, string handle);

    constructor(address systemContractAddress) ERC721("OmniFolio", "OMF") {
        systemContract = SystemContract(systemContractAddress);
    }

    modifier onlyProfileOwner(uint256 _tokenId) {
        require(
            _ownerOf(_tokenId) != address(0),
            "OmniFolio: Token doesnot exist"
        );
        require(
            _ownerOf(_tokenId) == msg.sender,
            "OmniFolio: only profile owner can perform this action"
        );
        _;
    }

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override onlySystem(systemContract) {
        address recipient;

        if (context.chainID == BITCOIN) {
            recipient = BytesHelperLib.bytesToAddress(message, 0);
        } else {
            recipient = abi.decode(message, (address));
        }

        // TODO: Create profile
        // should not have nft minted to recipient already
        require(
            balanceOf(recipient) == 0,
            "OmniFolio: Profile NFT already exists"
        );
        _mintNFT(recipient, context.chainID, amount);
    }

    function _mintNFT(
        address recipient,
        uint256 chainId,
        uint256 amount
    ) private {
        uint256 tokenId = currentTokenId;
        _safeMint(recipient, tokenId);
        tokenIdOfUser[recipient] = tokenId;
        tokenChains[tokenId] = chainId;
        tokenAmounts[tokenId] = amount;
        currentTokenId++;
    }

    function createProfile(
        string memory _name,
        string memory _handle,
        string memory _bio,
        string memory _avatar,
        string[] memory _linkKeys,
        string[] memory _links
    ) external {
        require(
            _linkKeys.length == _links.length,
            "OmniFolio: links and linkKeys length must match"
        );
        require(!profileExists[_handle], "OmniFolio: handle is taken");
        require(bytes(_handle).length > 0, "OmniFolio: handle cannot be empty");
        require(bytes(_name).length > 0, "OmniFolio: name cannot be empty");
        uint256 userTokenId = tokenIdOfUser[msg.sender];
        // if owner doesnt match, it means token doesnt exist
        require(
            _ownerOf(tokenId) == msg.sender,
            "OmniFolio: Profile NFT does not exist"
        );

        profileExists[_handle] = true;
        handleToTokenId[_handle] = userTokenId;

        Profile storage newProfile = profiles[userTokenId];
        newProfile.tokenId = userTokenId;
        newProfile.name = _name;
        newProfile.handle = _handle;
        newProfile.bio = _bio;
        newProfile.avatar = _avatar;
        newProfile.linkKeys = _linkKeys;
        newProfile.owner = msg.sender;

        for (uint256 i = 0; i < _linkKeys.length; i++) {
            newProfile.links[_linkKeys[i]] = _links[i];
        }
        emit ProfileCreated(
            userTokenId,
            _name,
            _handle,
            _bio,
            _avatar,
            msg.sender,
            _linkKeys,
            _links
        );
    }

    function updateProfile(
        uint256 _tokenId,
        string memory _name,
        string memory _bio,
        string memory _avatar,
        string[] memory _linkKeys,
        string[] memory _links
    ) external onlyProfileOwner(_tokenId) {
        require(
            _linkKeys.length == _links.length,
            "OmniFolio: links and linkKeys length must match"
        );

        Profile storage profile = profiles[_tokenId];
        profile.name = _name;
        profile.bio = _bio;
        profile.avatar = _avatar;
        profile.linkKeys = _linkKeys;

        for (uint256 i = 0; i < _linkKeys.length; i++) {
            profile.links[_linkKeys[i]] = _links[i];
        }
        emit ProfileUpdated(
            _tokenId,
            _name,
            profile.handle,
            _bio,
            _avatar,
            msg.sender,
            _linkKeys,
            _links
        );
    }

    function _deleteProfile(
        uint256 _tokenId
    ) internal onlyProfileOwner(_tokenId) {
        Profile storage profile = profiles[_tokenId];
        string memory handle = profile.handle;
        // profileExists[handle] = false;
        delete tokenIdOfUser[profile.owner];
        delete profileExists[handle];
        delete handleToTokenId[handle];
        delete profiles[_tokenId];
        _burn(_tokenId);
        emit ProfileDeleted(_tokenId, handle);
    }

    function deleteProfile(uint256 tokenId, bytes memory recipient) public {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) {
            revert CallerNotOwnerNotApproved();
        }
        address zrc20 = systemContract.gasCoinZRC20ByChainId(
            tokenChains[tokenId]
        );

        (, uint256 gasFee) = IZRC20(zrc20).withdrawGasFee();

        IZRC20(zrc20).approve(zrc20, gasFee);
        IZRC20(zrc20).withdraw(recipient, tokenAmounts[tokenId] - gasFee);

        _deleteProfile(tokenId);
        delete tokenAmounts[tokenId];
        delete tokenChains[tokenId];
    }

    // override to prevent transfers
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        require(
            from == address(0) || to == address(0),
            "OmniFolio: Profile is non-transferable"
        );
        return super._update(to, tokenId, auth);
    }

    function getProfileByHandle(
        string memory _handle
    )
        public
        view
        returns (
            uint256 tokenId,
            string memory name,
            string memory handle,
            string memory bio,
            string memory avatar,
            address owner,
            string[] memory linkKeys,
            string[] memory links
        )
    {
        tokenId = handleToTokenId[_handle];
        require(
            _ownerOf(tokenId) != address(0),
            "OmniFolio: Profile not found by handle"
        );
        Profile storage profile = profiles[tokenId];
        linkKeys = profile.linkKeys;
        //  get links from mapping
        links = new string[](linkKeys.length);
        for (uint256 i = 0; i < linkKeys.length; i++) {
            links[i] = profile.links[linkKeys[i]];
        }

        return (
            tokenId,
            profile.name,
            profile.handle,
            profile.bio,
            profile.avatar,
            profile.owner,
            linkKeys,
            links
        );
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(
            _ownerOf(tokenId) != address(0),
            "OmniFolio: URI query for nonexistent token"
        );
        return _getTokenURI(tokenId);
    }

    function _getTokenURI(
        uint256 tokenId
    ) internal view returns (string memory) {
        Profile storage profile = profiles[tokenId];

        // Initialize attributes array with fixed attributes
        bytes[] memory attributesArray = new bytes[](
            profile.linkKeys.length + 4
        );
        attributesArray[0] = abi.encodePacked(
            '{"trait_type":"name", "value":"',
            profile.name,
            '"}'
        );
        attributesArray[1] = abi.encodePacked(
            '{"trait_type":"handle", "value":"',
            profile.handle,
            '"}'
        );
        attributesArray[2] = abi.encodePacked(
            '{"trait_type":"bio", "value":"',
            profile.bio,
            '"}'
        );
        attributesArray[3] = abi.encodePacked(
            '{"trait_type":"tokenId", "value":"',
            tokenId.toString(),
            '"}'
        );

        // Add links as additional attributes to the attributes array
        for (uint256 i = 0; i < profile.linkKeys.length; i++) {
            string memory key = profile.linkKeys[i];
            string memory value = profile.links[key];
            if (bytes(value).length > 0) {
                bytes memory linkAttribute = abi.encodePacked(
                    '{"trait_type":"',
                    key,
                    '", "value":"',
                    value,
                    '"}'
                );
                attributesArray[i + 4] = linkAttribute;
            }
        }

        // Convert attributes array to JSON format
        bytes memory attributesJson = abi.encodePacked(
            "[",
            bytesJoin(attributesArray, ","),
            "]"
        );

        // Construct the entire JSON
        bytes memory json = abi.encodePacked(
            '{"name":"',
            profile.name,
            '", "description":"',
            profile.bio,
            '", "image":"',
            profile.avatar,
            '", "external_url":"",',
            '"attributes":',
            attributesJson,
            "}"
        );

        // Concatenate Base64 with data URI
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(json)
                )
            );
    }

    // Helper function to join bytes in an array with a delimiter
    function bytesJoin(
        bytes[] memory parts,
        bytes memory delimiter
    ) internal pure returns (bytes memory) {
        if (parts.length == 0) return "";
        bytes memory output = parts[0];
        for (uint256 i = 1; i < parts.length; i++) {
            output = abi.encodePacked(output, delimiter, parts[i]);
        }
        return output;
    }
}
