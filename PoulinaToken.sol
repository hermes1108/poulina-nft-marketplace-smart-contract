// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PoulinaToken is ERC1155Supply, ERC1155Holder, Ownable {

    uint256 public totalMinted;
    mapping(uint256 => string) tokenURIs;
    mapping(uint256 => uint256) fractionPrices;
    mapping(uint256 => uint256) maxSupplys;
    mapping(uint256 => address) creators;
    mapping(address => uint256[]) tokenIdByUser;
    mapping(address => mapping(uint256 => uint256)) posOfTokenIdByUser;
    mapping(address => uint256[]) tokenAmountByUser;

    address marketAddress = 0x1234567890123456789012345678901234567890;

    mapping(bytes4 => bool) private _supportedInterfaces;

    event CreateNFT(    
        uint256 tokenId,
        string tokenURI,
        uint256 airdropAmount,
        uint256 maxSupply,
        uint256 fractionPrice,
        address creator
    );
    event Minted(uint256 tokenId, uint256 amount, address minter);

    constructor() ERC1155("Poulina") {
      _supportedInterfaces[0xd9b67a26] = true;        // _INTERFACE_ID_ERC1155
    }

    modifier exist(uint256 tokenId) {
        require(exists(tokenId) == true, "The Token does not exist");
        _;
    }

    modifier onlyMarket() {
        require(msg.sender == marketAddress, "Only marketplace can use me.");
        _;
    }

    function setMarketAddress(address _newMarketAddress) external onlyOwner {
        marketAddress = _newMarketAddress;
    }

    function create(
        string memory tokenURI,
        uint256 airdropAmount,
        uint256 mxSpl,
        uint256 frcPrice
    ) external {
        require(mxSpl > 0, "Max Supply Must be bigger than 0");         
        tokenURIs[++totalMinted] = tokenURI;
        fractionPrices[totalMinted] = frcPrice;
        maxSupplys[totalMinted] = mxSpl;
        creators[totalMinted] = msg.sender;
        if (airdropAmount > 0) {
            _mint(msg.sender, totalMinted, airdropAmount, "0x0000");
        }
        emit CreateNFT(
            totalMinted,
            tokenURI,
            airdropAmount,
            mxSpl,
            frcPrice,
            msg.sender
        );
    }

    function mint(uint256 tokenId, uint256 amount) external payable {
        require(exists(tokenId) == true, "The Token does not exist");
        require(amount > 0, "Minting 0 is not allowed");
        require(
            totalSupply(tokenId) + amount <= maxSupplys[tokenId],
            "Exceeds Max Supply"
        );

        uint256  price = fractionPrices[tokenId] * amount;
        if(totalSupply(tokenId) % 100000 == 0){
            uint256 times = totalSupply(tokenId) / 100000;
            for(uint256 i = 1; i <= times; ++i) {
                price = price * 201 /200;
            }
        }
            
        require(
            msg.value >= price,
            "Insufficient funds"
        );
        _mint(msg.sender, tokenId, amount, "0x0000");
        payable(creators[tokenId]).transfer(msg.value);
        emit Minted(tokenId, amount, msg.sender);
    }

    function proxyTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyMarket {
        
        _safeTransferFrom(from, to, id, amount, data);
    }

    // -------------------- getter --------------------

    function tokenURI(uint256 tokenId) public view exist(tokenId) returns (string memory) {
        return tokenURIs[tokenId];
    }
    
    function fractionPrice(uint256 tokenId) external view exist(tokenId) returns (uint256) {
        return fractionPrices[tokenId];
    }

    function maxSupply(uint256 tokenId) external view exist(tokenId) returns (uint256) {
        return maxSupplys[tokenId];
    }

    function creator(uint256 tokenId) external view exist(tokenId) returns (address) {
        return creators[tokenId];
    }

    function getTotalMinted() external view returns (uint256) {
        return totalMinted;
    }

    // -------------------- setter --------------------

    function setFractionPrice(uint256 tokenId, uint256 price) external exist(tokenId) onlyMarket {
        fractionPrices[tokenId] =  price;
    }

    function setMaxSupply(uint256 tokenId, uint256 supply) external exist(tokenId) onlyMarket {
        maxSupplys[tokenId] =  supply;
    }

    function setCreator(uint256 tokenId, address creator) external exist(tokenId) onlyMarket {
        creators[tokenId] =  creator;
    }

    function setTokenURI(uint256 tokenId, string memory uri) external exist(tokenId) onlyMarket {
        tokenURIs[tokenId] = uri;
    }

    function setTotalMinted(uint256 _newTotalMinted) external onlyMarket {
        totalMinted = _newTotalMinted;
    }
    
    // -------------------- override --------------------
        /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i<ids.length; ++i){
            uint256 id = ids[i];
            uint256 amt = amounts[i];
            uint256 pos_from = posOfTokenIdByUser[from][id];
            uint256 pos_to = posOfTokenIdByUser[to][id];
            uint256 fromIdNum = tokenIdByUser[from].length;

            if (to != address(0)) {
                if (pos_to != 0){
                    tokenAmountByUser[to][pos_to-1] += amt;
                } else {
                    posOfTokenIdByUser[to][id] = tokenIdByUser[to].length+1;
                    tokenIdByUser[to].push(id);
                    tokenAmountByUser[to].push(amt);
                }
            }

            if (from != address(0)) {
                if (pos_from != 0){
                    require(tokenAmountByUser[from][pos_from-1] >= amt, "amount cannot be greater than original amount");
                    tokenAmountByUser[from][pos_from-1] -= amt;
                    if (tokenAmountByUser[from][pos_from-1] == 0){
                        tokenIdByUser[from][pos_from-1] = tokenIdByUser[from][fromIdNum - 1];
                        tokenIdByUser[from].pop();
                        tokenAmountByUser[from][pos_from-1] = tokenAmountByUser[from][fromIdNum - 1];
                        tokenAmountByUser[from].pop();
                    }
                } else {
                    posOfTokenIdByUser[from][id] = fromIdNum+1;
                    tokenIdByUser[from].push(id);
                    tokenAmountByUser[from].push(amt);
                }
            }
        }
    }

    function getTokenIdByUser (address _addr) external view returns (uint256[] memory) {
        return tokenIdByUser[_addr];
    }

    function getTokenAmountByUser (address _addr) external view returns (uint256[] memory) {
        return tokenAmountByUser[_addr];
    }

    /////////////////////////////////////////// ERC165 //////////////////////////////////////////////

    bytes4 private constant INTERFACE_SIGNATURE_ERC165 = 0x01ffc9a7;
    bytes4 private constant INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;

    function supportsInterface(bytes4 _interfaceId) public view override(ERC1155, ERC1155Receiver) returns (bool) {
        if (
            _interfaceId == INTERFACE_SIGNATURE_ERC165 ||
            _interfaceId == INTERFACE_SIGNATURE_ERC1155
        ) {
            return true;
        }

        return false;
    }
}