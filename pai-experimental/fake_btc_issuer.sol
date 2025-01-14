pragma solidity 0.4.25;

import "../library/template.sol";
import "../library/utils/ds_math.sol";
import "./registry.sol";

contract FakeBTCIssuer is Template, DSMath {
    string private name = "Fake_BTC_ISSUER";
    uint32 private orgnizationID;
    uint32 private assetIndex;
    uint32 private assetType;
    uint256 private ASSET_BTC;
    
    uint private totalSupply = 0;
    Registry registry;

    bool private firstTry;
    address private hole = 0x660000000000000000000000000000000000000000;

    function() public payable {
        require(msg.assettype == ASSET_BTC);
    }

    function init(string _name) public {
        name = _name;
        /// TODO organization registration should be done in DAO
        registry = Registry(0x630000000000000000000000000000000000000065);
        orgnizationID = registry.registerOrganization(name, "Fake-Template-Name-For-Test");
        assetIndex = 1;
        assetType = 0;
        uint64 assetId = uint64(assetType) << 32 | uint64(orgnizationID);
        uint96 asset = uint96(assetId) << 32 | uint96(assetIndex);
        ASSET_BTC = asset;
        firstTry = true;
    }

    function mint(uint amount, address dest) public {
        if(firstTry) {
            firstTry = false;
            //flow.createAsset(assetType, assetIndex, amount);
            registry.newAsset("FBTC", "FBTC", "Fake BTC Pegging Coin", assetType, assetIndex,amount);
            flow.mintAsset(assetIndex, amount);
        } else {
            flow.mintAsset(assetIndex, amount);
        }
        dest.transfer(amount, ASSET_BTC);
        totalSupply = add(totalSupply, amount);
    }

    function burn() public payable {
        require(msg.assettype == ASSET_BTC);
        hole.transfer(msg.value, msg.assettype);
        totalSupply = sub(totalSupply, msg.value);
    }

    function getAssetType() public view returns (uint256) {
        return ASSET_BTC;
    }

    function getAssetInfo(uint32 index)
        public
        view 
        returns (bool, string, string, string, uint32, uint)
    {
        return (true, "FBTC", "FBTC", "Fake BTC Pegging Coin", 0, totalSupply);
    }
}