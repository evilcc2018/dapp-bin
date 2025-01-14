pragma solidity 0.4.25;

import "../../library/utils/ds_math.sol";
import "../../library/template.sol";
import "../cdp.sol";
import "../testPI.sol";
import "../fake_btc_issuer.sol";
import "../settlement.sol";
import "./testPrepare.sol";

contract TestBase is Template, DSTest, DSMath {
    TimefliesCDP internal cdp;
    Liquidator internal liquidator;
    TimefliesOracle internal oracle;
    TimefliesOracle internal oracle2;
    FakePAIIssuer internal paiIssuer;
    FakeBTCIssuer internal btcIssuer;
    FakePerson internal admin;
    FakePerson internal p1;
    FakePerson internal p2;
    FakePaiDao internal paiDAO;
    Setting internal setting;
    Finance internal finance;
    Settlement internal settlement;

    uint96 internal ASSET_BTC;
    uint96 internal ASSET_PAI;
    uint96 internal ASSET_PIS;

    function() public payable {

    }

    function setup() public {
        admin = new FakePerson();
        p1 = new FakePerson();
        p2 = new FakePerson();
        paiDAO = FakePaiDao(admin.createPAIDAO("PAIDAO"));
        paiDAO.init();
        ASSET_PIS = paiDAO.PISGlobalId();
        btcIssuer = new FakeBTCIssuer();
        btcIssuer.init("BTC");
        ASSET_BTC = uint96(btcIssuer.getAssetType());

        oracle = new TimefliesOracle("BTCOracle",paiDAO,RAY,ASSET_BTC);
        oracle2  = new TimefliesOracle("BTCOracle",paiDAO,RAY,ASSET_PIS);
        admin.callCreateNewRole(paiDAO,"BTCOracle","ADMIN",3,false);
        admin.callCreateNewRole(paiDAO,"DIRECTORVOTE","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"PISVOTE","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"Settlement@STCoin","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"BTCCDP","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"DirVote@STCoin","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"50%DemPreVote@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,admin,"BTCOracle");
        admin.callAddMember(paiDAO,p1,"BTCOracle");
        admin.callAddMember(paiDAO,p2,"BTCOracle");
        admin.callAddMember(paiDAO,admin,"DIRECTORVOTE");
        admin.callAddMember(paiDAO,admin,"PISVOTE");
        admin.callAddMember(paiDAO,admin,"Settlement@STCoin");
        admin.callAddMember(paiDAO,admin,"DirVote@STCoin");
        admin.callAddMember(paiDAO,admin,"50%DemPreVote@STCoin");
        admin.callModifyEffectivePriceNumber(oracle,3);

        paiIssuer = new FakePAIIssuer("PAIISSUER",paiDAO);
        paiIssuer.init();
        ASSET_PAI = paiIssuer.PAIGlobalId();

        setting = new Setting(paiDAO);
        finance = new Finance(paiDAO,paiIssuer,setting,oracle2);
        admin.callUpdateRatioLimit(setting, ASSET_BTC, RAY * 2);
        liquidator = new Liquidator(paiDAO,oracle, paiIssuer,"BTCCDP",finance,setting);

        cdp = new TimefliesCDP(paiDAO,paiIssuer,oracle,liquidator,setting,finance,100000000000);
        admin.callCreateNewRole(paiDAO,"Minter@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,cdp,"Minter@STCoin");
        admin.callAddMember(paiDAO,cdp,"BTCCDP");

        settlement = new Settlement(paiDAO,oracle,cdp,liquidator);
        admin.callAddMember(paiDAO,settlement,"Settlement@STCoin");

        btcIssuer.mint(1000000000000, p1);
        btcIssuer.mint(1000000000000, p2);
        btcIssuer.mint(1000000000000, this);


    }

    function setupTest() public {
        setup();
        assertEq(oracle.getPrice(), RAY);
        admin.callUpdatePrice(oracle, RAY * 99/100);
        p1.callUpdatePrice(oracle, RAY * 99/100);
        p2.callUpdatePrice(oracle, RAY * 99/100);
        oracle.fly(50);
        admin.callUpdatePrice(oracle, RAY * 99/100);
        assertEq(oracle.getPrice(), RAY * 99/100);

    }
}

contract SettlementTest is TestBase {
    function settlementSetup() public {
        setup();
        admin.callUpdateLiquidationRatio(cdp, RAY * 2);
        admin.callUpdateLiquidationPenalty1(cdp, RAY * 3 / 2);
        admin.callSetDiscount1(liquidator,RAY);
    }

    function testSettlementNormal() public {
        settlementSetup();

        uint idx = cdp.createDepositBorrow.value(2000000000, ASSET_BTC)(500000000,CDP.CDPType.CURRENT);

        bool tempBool = p1.callTerminatePhaseOne(settlement);
        assertTrue(!tempBool);
        tempBool = admin.callTerminatePhaseOne(settlement);
        assertTrue(tempBool);
        assertTrue(!cdp.readyForPhaseTwo());
        cdp.liquidate(idx);

        assertEq(liquidator.totalCollateral(), 500000000);
        assertEq(liquidator.totalDebt(), 500000000);
        assertTrue(cdp.readyForPhaseTwo());
        assertEq(cdp.totalCollateral(), 0);
        assertEq(cdp.totalPrincipal(), 0);

        tempBool = p1.callTerminatePhaseTwo(settlement);
        assertTrue(!tempBool);
        tempBool = admin.callTerminatePhaseTwo(settlement);
        assertTrue(tempBool);
        liquidator.buyCollateral.value(500000000, ASSET_PAI)();
        assertEq(liquidator.totalCollateral(), 0);
        assertEq(liquidator.totalDebt(), 0);
    }

    function testSettlementMultipleCDPOverCollateral() public {
        settlementSetup();

        uint idx = cdp.createDepositBorrow.value(2000000000, ASSET_BTC)(500000000,CDP.CDPType.CURRENT);
        uint idx2 = cdp.createDepositBorrow.value(3000000000, ASSET_BTC)(1000000000,CDP.CDPType.CURRENT);
        uint idx3 = cdp.createDepositBorrow.value(5000000000, ASSET_BTC)(2000000000,CDP.CDPType.CURRENT);
        uint emm = flow.balance(this,ASSET_BTC);

        assertEq(cdp.totalCollateral(), 10000000000);
        assertEq(cdp.totalPrincipal(), 3500000000);

        admin.callModifySensitivityRate(oracle, RAY);
        admin.callUpdatePrice(oracle, RAY * 2);
        p1.callUpdatePrice(oracle, RAY * 2);
        p2.callUpdatePrice(oracle, RAY * 2);
        oracle.fly(50);
        admin.callUpdatePrice(oracle, RAY * 2);
        assertEq(oracle.getPrice(), RAY * 2);

        assertTrue(cdp.safe(idx));
        assertTrue(cdp.safe(idx2));
        assertTrue(cdp.safe(idx3));

        admin.callTerminatePhaseOne(settlement);

        cdp.liquidate(idx2);
        assertEq(liquidator.totalCollateral(), 500000000);
        assertEq(liquidator.totalDebt(), 1000000000);

        assertTrue(!cdp.readyForPhaseTwo());

        cdp.quickLiquidate(2);
        assertEq(liquidator.totalCollateral(), 750000000);
        assertEq(liquidator.totalDebt(), 1500000000);

        assertTrue(!cdp.readyForPhaseTwo());

        cdp.quickLiquidate(3);

        assertEq(liquidator.totalCollateral(), 1750000000);
        assertEq(liquidator.totalDebt(), 3500000000);

        assertTrue(cdp.totalPrincipal() == 0);
        assertEq(flow.balance(this,ASSET_BTC),emm + 1750000000 + 2500000000 + 4000000000);
        assertTrue(cdp.readyForPhaseTwo());

        admin.callTerminatePhaseTwo(settlement);

        liquidator.buyCollateral.value(3500000000, ASSET_PAI)();
        assertEq(liquidator.totalCollateral(), 0);
        assertEq(liquidator.totalDebt(), 0);
    }

    function testSettlementMultipleCDPUnderCollateral() public {
        settlementSetup();

        uint idx = cdp.createDepositBorrow.value(2000000000, ASSET_BTC)(500000000,CDP.CDPType.CURRENT);
        uint idx2 = cdp.createDepositBorrow.value(3000000000, ASSET_BTC)(1000000000,CDP.CDPType.CURRENT);
        uint idx3 = cdp.createDepositBorrow.value(5000000000, ASSET_BTC)(2000000000,CDP.CDPType.CURRENT);
        uint emm = flow.balance(this,ASSET_BTC);

        assertEq(cdp.totalCollateral(), 10000000000);
        assertEq(cdp.totalPrincipal(), 3500000000);

        admin.callModifySensitivityRate(oracle, RAY);
        admin.callUpdatePrice(oracle, RAY / 10);
        p1.callUpdatePrice(oracle, RAY / 10);
        p2.callUpdatePrice(oracle, RAY / 10);
        oracle.fly(50);
        admin.callUpdatePrice(oracle, RAY / 10);
        assertEq(oracle.getPrice(), RAY / 10);

        assertTrue(!cdp.safe(idx));
        assertTrue(!cdp.safe(idx2));
        assertTrue(!cdp.safe(idx3));

        admin.callTerminatePhaseOne(settlement);

        cdp.liquidate(idx2);
        assertEq(liquidator.totalCollateral(), 3000000000);
        assertEq(liquidator.totalDebt(), 1000000000);

        assertTrue(!cdp.readyForPhaseTwo());

        cdp.quickLiquidate(2);
        assertEq(liquidator.totalCollateral(), 5000000000);
        assertEq(liquidator.totalDebt(), 1500000000);

        assertTrue(!cdp.readyForPhaseTwo());

        cdp.quickLiquidate(3);
        assertEq(liquidator.totalCollateral(), 10000000000);
        assertEq(liquidator.totalDebt(), 3500000000);

        assertTrue(cdp.totalPrincipal() == 0);
        assertEq(flow.balance(this,ASSET_BTC),emm);
        assertTrue(cdp.readyForPhaseTwo());

        admin.callTerminatePhaseTwo(settlement);

        liquidator.buyCollateral.value(3500000000, ASSET_PAI)();
        assertEq(liquidator.totalCollateral(), 0);
        assertEq(liquidator.totalDebt(), 0);
    }

    function testSettlementPhaseTwoBuyFromLiquidator() public{
        settlementSetup();

        uint idx = cdp.createDepositBorrow.value(1000000000, ASSET_BTC)(500000000,CDP.CDPType.CURRENT);

        assertTrue(cdp.safe(idx));

        admin.callModifySensitivityRate(oracle, RAY);
        admin.callUpdatePrice(oracle, RAY / 2);
        p1.callUpdatePrice(oracle, RAY / 2);
        p2.callUpdatePrice(oracle, RAY / 2);
        oracle.fly(50);
        admin.callUpdatePrice(oracle, RAY / 2);
        assertEq(oracle.getPrice(), RAY / 2);

        assertTrue(!cdp.safe(idx));
        cdp.liquidate(idx);

        assertEq(liquidator.totalCollateral(), 1000000000);
        assertEq(liquidator.totalDebt(), 500000000);

        liquidator.buyCollateral.value(100000000, ASSET_PAI)();

        assertEq(liquidator.totalCollateral(), 800000000);
        assertEq(liquidator.totalDebt(), 400000000);

        admin.callTerminatePhaseOne(settlement);
        assertTrue(!liquidator.call(abi.encodeWithSelector(liquidator.buyCollateral.selector,1000000,ASSET_PAI)));

        admin.callTerminatePhaseTwo(settlement);
        liquidator.buyCollateral.value(100000000, ASSET_PAI)();
        assertEq(liquidator.totalCollateral(), 600000000);
        assertEq(liquidator.totalDebt(), 300000000);
    }

    function testSettlementFourMethods() public {
        settlementSetup();     

        //test whether there are grammar error!
        admin.callAddMember(paiDAO,admin,"Minter@STCoin");
        admin.callMint(paiIssuer,100000000000,this);
        uint idx = cdp.createDepositBorrow.value(1000000000, ASSET_BTC)(500000000,CDP.CDPType.CURRENT);
        assertTrue(cdp.call.value(1000000000, ASSET_BTC)(abi.encodeWithSelector(cdp.deposit.selector,idx)));
        assertTrue(cdp.call.value(1000000000, ASSET_PAI)(abi.encodeWithSelector(cdp.repay.selector,idx)));

        assertTrue(cdp.call.value(1000000000, ASSET_BTC)(abi.encodeWithSelector(cdp.createDepositBorrow.selector,500000000,CDP.CDPType.CURRENT)));

        //test whether terminatePhaseTwo can be called successfully!

        assertTrue(!admin.callTerminatePhaseTwo(settlement));
        
        admin.callTerminatePhaseOne(settlement);
        //test whether these four method can be called successfully!
        assertTrue(!cdp.call.value(1000000000, ASSET_BTC)(abi.encodeWithSelector(cdp.createDepositBorrow.selector,500000000,CDP.CDPType.CURRENT)));
        assertTrue(!cdp.call.value(1000000000, ASSET_BTC)(abi.encodeWithSelector(cdp.deposit.selector,idx)));
        assertTrue(!cdp.call.value(1000000000, ASSET_PAI)(abi.encodeWithSelector(cdp.repay.selector,idx)));
    }

    function testPhaseTwoReady() public {
        settlementSetup();

        uint idx = cdp.createDepositBorrow.value(2000000000, ASSET_BTC)(500000000,CDP.CDPType.CURRENT);

        admin.callTerminatePhaseOne(settlement);
        assertTrue(!admin.callTerminatePhaseTwo(settlement));

        cdp.liquidate(idx);

        assertTrue(admin.callTerminatePhaseTwo(settlement));
    }

    function testSettlementUpdateOracle() public {
        settlementSetup();     

        assertTrue(p1.callUpdatePrice(oracle, RAY / 2));

        admin.callTerminatePhaseOne(settlement);
        assertTrue(!p1.callUpdatePrice(oracle, RAY / 2));
    }
}
