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
    uint256 currentTokenId = 0;

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
    }
}
