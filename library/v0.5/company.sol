pragma solidity 0.4.25;

import "./organization.sol";
import "./SafeMath.sol";

/// @dev The purpose of this contract is to set a standard on how to manage various assets for an organization
///  the abstract of asset on Flow is defined in AssetInfo struct, which contains basic information, asset properties and others
///  an organization can create new assets and mint existing assets; and an asset owner can redeem or transfer an asset
///  the asset issuer (the organization) can determine whether an asset can be transferred depending on the asset properties (asset type, whitelist, tag, etc)
contract Company is Organization {
    using SafeMath for uint256;
    
    bytes32 constant BYTES32_FLAG = 0x0000000000000000000000000000000000000000000000000000000000000000;
    
    /// @dev We define a voucher as an element of an indivisible asset
    ///  a hash is kept to validate the integrity for off chain data
    struct Voucher {
        bytes32 voucherHash;
        bool existed;
    }
    
    /// @dev full information of an asset
    struct AssetInfo {
        /// basic information
        string name;
        string symbol;
        string description;

        /// properties of an asset
        /// asset type contains DIVISIBLE + ANONYMOUS + RESTRICTED
        uint32 assetType;

        /// whitelist control, which is the default RISTRICTION type
        bool isTxinRestrictedToWhitelist;
        bool isTxoutRestrictedToWhitelist;
        mapping (address => bool) whitelist;
        

        /// tag: field for each issuer to engrave extra information
        bytes32 tag;

        /// total amount issued on a divisible asset OR total count issued on an indivisible asset
        uint totalIssued;
        /// all vouchers issued on an indivisible asset
        /// voucher id => voucher object
        mapping (uint => Voucher) issuedVouchers;

        bool existed;
    }
    
    /// all assets issued by the organization
    uint32[] issuedIndexes;
    /// assetIndex -> AssetInfo
    mapping (uint32 => AssetInfo) issuedAssets;
    
    /// @dev constructor of the contract
    ///  initial acl settings are configured in the constructor
    constructor(string organizationName) Organization(organizationName) public {
    }
    
    function registryCompany() public {
        register();
    }
    
    /// @dev create an asset
    /// @param name asset name
    /// @param symbol asset symbol
    /// @param description asset description
    /// @param assetType asset properties, divisible, anonymous and restricted circulation
    /// @param assetIndex asset index in the organization
    /// @param amountOrVoucherId amount or voucherId of asset to create
    ///     (or the unique voucher id for an indivisible asset)
    /// @param isTxinRestrictedToWhitelist whether the whitelist restriction applies to txin
    /// @param isTxoutRestrictedToWhitelist whether the whitelist restriction applies to txout
    /// @param tag extra properteis special to an asset
    /// @param voucherHash hash of an indivisible asset properties to check integrity
    function create(string name, string symbol, string description, uint32 assetType, uint32 assetIndex,
        uint256 amountOrVoucherId, bool isTxinRestrictedToWhitelist, bool isTxoutRestrictedToWhitelist, 
        bytes32 tag, bytes32 voucherHash)
        public
    {
        AssetInfo storage assetInfo = issuedAssets[assetIndex];
        require(!assetInfo.existed, "asset already existed");
        
        /// check the scope of assetType if match isTxinRestrictedToWhitelist and isTxoutRestrictedToWhitelist
        require(2 == getRestrictedBit(assetType));
        if (0 == getScopeBits(assetType)) {
            require(isTxinRestrictedToWhitelist && isTxoutRestrictedToWhitelist);
        }
        if (4 == getScopeBits(assetType)) {
            require(isTxoutRestrictedToWhitelist);
        }
        if (8 == getScopeBits(assetType)) {
            require(isTxinRestrictedToWhitelist);
        }
        if (12 == getScopeBits(assetType)) {
            require(isTxinRestrictedToWhitelist || isTxoutRestrictedToWhitelist);
        }
        
        /// create asset to utxo
        /// create operation is success or not, will affect execution of the f0llowing code
        create(assetType, assetIndex, amountOrVoucherId);

        assetInfo.name = name;
        assetInfo.symbol = symbol;
        assetInfo.description = description;
        assetInfo.assetType = assetType;
        assetInfo.isTxinRestrictedToWhitelist = isTxinRestrictedToWhitelist;
        assetInfo.isTxoutRestrictedToWhitelist = isTxoutRestrictedToWhitelist;
        assetInfo.tag = tag;
        
        if (0 == getDivisibleBit(assetType)) {
            assetInfo.totalIssued = amountOrVoucherId; 
        } else if (1 == getDivisibleBit(assetType)) {
            assetInfo.totalIssued = 1;
            Voucher storage voucher = assetInfo.issuedVouchers[amountOrVoucherId];
            voucher.voucherHash = voucherHash;
            voucher.existed = true;
        }
        assetInfo.existed = true;
        issuedIndexes.push(assetIndex);
    }

    /// @dev mint an asset
    /// @param assetIndex asset index in the organization
    /// @param amountOrVoucherId amount or voucherId of asset to mint 
    ///     (or the unique voucher id for an indivisible asset)    
    function mint(uint32 assetIndex, uint256 amountOrVoucherId, bytes32 tag, bytes32 voucherHash)
        public
    {
        AssetInfo storage assetInfo = issuedAssets[assetIndex];
        require(assetInfo.existed, "asset not exist");
        
        /// mint an asset
        /// mint operation is success or not, will affect execution of the f0llowing code
        mint(assetIndex, amountOrVoucherId);
        
        uint32 isDivisible = getDivisibleBit(assetInfo.assetType);
        if (0 == isDivisible) {
            assetInfo.totalIssued = SafeMath.add(assetInfo.totalIssued, amountOrVoucherId);
        } else if (1 == isDivisible) {
            assetInfo.totalIssued++;
            Voucher storage voucher = assetInfo.issuedVouchers[amountOrVoucherId];
            voucher.voucherHash = voucherHash;
            voucher.existed = true;
        }
    }
    
    function transferAsset(address to, bytes12 asset, uint amount) public {
        transfer(to, asset, amount);
    }
    
    /// @dev whether an asset can be transferred or not, called when RISTRICTED bit is set
    /// @dev this function can be called by chain code or internal "transfer" implementation
    /// @param transferAddress in or out address
    /// @param assetIndex asset index
    /// @return success
    function canTransfer(address transferAddress, uint32 assetIndex)
        public
        view
        returns(bool)
    {
        AssetInfo storage assetInfo = issuedAssets[assetIndex];
        if (!assetInfo.existed) {
            return false;
        }
        
        bool result;
        if (2 != getRestrictedBit(assetInfo.assetType)) {
            result = true;
        }
        /// restricted asset
        if (2 == getRestrictedBit(assetInfo.assetType)) {
            /// address must be in whitelist
            if (!assetInfo.whitelist[transferAddress]) {
                return false;
            }
            
            bool isTxinRestricted = assetInfo.isTxinRestrictedToWhitelist;
            bool isTxoutRestricted = assetInfo.isTxoutRestrictedToWhitelist;
            /// get scope
            uint32 scope = getScopeBits(assetInfo.assetType);
            if (0 == scope) {
                result = (isTxinRestricted && isTxoutRestricted);
            }
            if (4 == scope) {
                result = isTxoutRestricted && !isTxinRestricted;
            }
            if (8 == scope) {
                result = isTxinRestricted && !isTxoutRestricted;
            }
            if (12 == scope) {
                result = (isTxinRestricted || isTxoutRestricted);
            }
        }
        return result;
    }
    
    /// @dev add an address to whitelist
    /// @dev should be ACLed
    /// @param assetIndex asset index 
    /// @param newAddress the address to add
    function addAddressToWhitelist(uint32 assetIndex, address newAddress)
        public
        returns (bool)
    {
        AssetInfo storage assetInfo = issuedAssets[assetIndex];
        if (!assetInfo.existed) {
            return false;
        }

        if (!assetInfo.whitelist[newAddress]) {
            assetInfo.whitelist[newAddress] = true;
        }
        return true;
    }

    /// @dev remove an address from whitelist
    /// @dev should be ACLed
    /// @param assetIndex asset index 
    /// @param existingAddress the address to remove   
    function removeAddressFromWhitelist(uint32 assetIndex, address existingAddress)
        public
        returns (bool)
    {
        AssetInfo storage assetInfo = issuedAssets[assetIndex];
        require(assetInfo.existed, "asset not exist");
        
        if (assetInfo.whitelist[existingAddress]) {
            delete assetInfo.whitelist[existingAddress];
        }
        return true;
    }
    
    /// @dev get asset name by asset index
    /// @param assetIndex asset index 
    function getAssetInfo(uint32 assetIndex) public view returns (bool, string, string, string) {
        AssetInfo storage assetInfo = issuedAssets[assetIndex];
        if (!assetInfo.existed) {
            return (false, "", "", "");
        }
        
        return (true, assetInfo.name, assetInfo.symbol, assetInfo.description);
    }
    
    /// @dev get asset type by asset index
    /// @param assetIndex asset index 
    function getAssetType(uint32 assetIndex) public view returns (bool, uint32) {
        AssetInfo storage assetInfo = issuedAssets[assetIndex];
        if (!assetInfo.existed) {
            return (false, 0);
        }
        
        return (true, assetInfo.assetType);
    }

    /// @dev get total amount/count issued on an asset
    /// @param assetIndex asset index 
    function getTotalIssued(uint32 assetIndex) public view returns (bool, uint) {
        AssetInfo storage assetInfo = issuedAssets[assetIndex];
        if (!assetInfo.existed) {
            return (false, 0);
        }
        
        return (true, assetInfo.totalIssued);
    }

    /// @dev get voucher hash by asset index and voucher id
    /// @param assetIndex asset index 
    /// @param voucherId voucher id
    function getVoucherHash(uint32 assetIndex, uint voucherId) public view returns (bool, bytes32) {
        AssetInfo storage assetInfo = issuedAssets[assetIndex];
        if (!assetInfo.existed) {
            return (false, BYTES32_FLAG);
        }
        
        Voucher storage voucher = assetInfo.issuedVouchers[voucherId];
        if (!voucher.existed) {
            return (false, BYTES32_FLAG);
        }
        
        return (true, voucher.voucherHash);
    }

    /// @dev internal method: get property of isDivisible from assetType
    function getDivisibleBit(uint32 assetType) internal pure returns(uint32) {
        uint32 lastFourBits = assetType & 15;
        return lastFourBits & 1;
    }
    
    /// @dev internal method: get property of isRestricted from assetType
    function getRestrictedBit(uint32 assetType) internal pure returns(uint32) {
        uint32 lastFourBits = assetType & 15;
        return lastFourBits & 2;
    }
    
    /// @dev internal method: get property of a\scope from assetType
    function getScopeBits(uint32 assetType) internal pure returns(uint32) {
        uint32 lastFourBits = assetType & 15;
        return lastFourBits & 12;
    }
    
}
