pragma solidity 0.4.25;

import "./testPrepare.sol";

contract TestBase is Template, DSTest, DSMath {
    TimefliesTDC internal tdc;
    TimefliesCDP internal cdp;
    Liquidator internal liquidator;
    TimefliesOracle internal oracle;
    TimefliesOracle internal PISOracle;
    FakePAIIssuer internal paiIssuer;
    FakeBTCIssuer internal btcIssuer;
    FakePerson internal admin;
    FakePerson internal p1;
    FakePerson internal p2;
    FakePaiDao internal paiDAO;
    Setting internal setting;
    TimefliesFinance internal finance;

    uint96 internal ASSET_BTC;
    uint96 internal ASSET_PAI;
    uint96 internal ASSET_PIS;

    function() public payable {}

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

        oracle = new TimefliesOracle("BTCOracle", paiDAO, RAY * 10, ASSET_BTC);
        PISOracle = new TimefliesOracle("PISOracle", paiDAO, RAY * 10, ASSET_PIS);
        admin.callCreateNewRole(paiDAO,"BTCOracle","ADMIN",3,false);
        admin.callCreateNewRole(paiDAO,"DIRECTORVOTE","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"PISVOTE","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"SettlementContract","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"BTCCDP","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"100%Demonstration@STCoin","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"50%Demonstration@STCoin","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"DirPisVote","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"DirPisVote@STCoin","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"DirVote@STCoin","ADMIN",0,false);
        admin.callCreateNewRole(paiDAO,"50%DemPreVote@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,admin,"BTCOracle");
        admin.callAddMember(paiDAO,p1,"BTCOracle");
        admin.callAddMember(paiDAO,p2,"BTCOracle");
        admin.callAddMember(paiDAO,admin,"DIRECTORVOTE");
        admin.callAddMember(paiDAO,admin,"PISVOTE");
        admin.callAddMember(paiDAO,admin,"SettlementContract");
        admin.callAddMember(paiDAO,admin,"BTCCDP");
        admin.callAddMember(paiDAO,admin,"100%Demonstration@STCoin");
        admin.callAddMember(paiDAO,admin,"50%Demonstration@STCoin");
        admin.callAddMember(paiDAO,admin,"DirPisVote");
        admin.callAddMember(paiDAO,admin,"DirPisVote@STCoin");
        admin.callAddMember(paiDAO,admin,"DirVote@STCoin");
        admin.callAddMember(paiDAO,admin,"50%DemPreVote@STCoin");
        admin.callModifyEffectivePriceNumber(oracle,3);

        paiIssuer = new FakePAIIssuer("PAIISSUER",paiDAO);
        paiIssuer.init();
        ASSET_PAI = paiIssuer.PAIGlobalId();

        setting = new Setting(paiDAO);
        finance = new TimefliesFinance(paiDAO,paiIssuer,setting,PISOracle);
        liquidator = new Liquidator(paiDAO,oracle, paiIssuer,"BTCCDP",finance,setting);
        admin.callUpdateRatioLimit(setting, ASSET_BTC, RAY * 2);

        admin.callCreateNewRole(paiDAO,"Minter@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,admin,"Minter@STCoin");

        tdc = new TimefliesTDC(paiDAO,setting,paiIssuer,finance);
        admin.callSetTDC(finance, tdc);

        cdp = new TimefliesCDP(paiDAO,paiIssuer,oracle,liquidator,setting,finance,100000000000);
        admin.callCreateNewRole(paiDAO,"Minter@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,cdp,"Minter@STCoin");
        admin.callAddMember(paiDAO,cdp,"BTCCDP");
        admin.callUpdateLendingRate(setting, RAY * 202 / 1000);
        cdp.updateBaseInterestRate();

        btcIssuer.mint(200000000000, p1);
        p1.callCreateDepositBorrow(cdp,10000000000,0,20000000000,ASSET_BTC);
        cdp.fly(2 years);
        p1.callRepay(cdp,1,10000000000,ASSET_PAI);
        //assertEq(flow.balance(finance,ASSET_PAI),4400000000);
        btcIssuer.mint(200000000000, p2);
    }
}

contract SettingTest is TestBase {

    function testSetSetting() public {
        setup();
        assertEq(finance.setting(), setting);
        Setting setting2 = new Setting(paiDAO);

        bool tempBool = p1.callSetSetting(finance, setting2);
        assertTrue(!tempBool);
        tempBool = admin.callSetSetting(finance, setting2);
        assertTrue(tempBool);
        assertEq(finance.setting(), setting2);
    }

    function testSetTDC() public {
        setup();
        assertEq(finance.tdc(), tdc);

        bool tempBool = p1.callSetTDC(finance, p2);
        assertTrue(!tempBool);
        tempBool = admin.callSetTDC(finance, p2);
        assertTrue(tempBool);
        assertEq(finance.tdc(), p2);
    }

    function testSetOracle() public {
        setup();
        assertEq(finance.priceOracle(),PISOracle);
        TimefliesOracle oracle2 = new TimefliesOracle("BTCOracle",paiDAO,RAY,ASSET_PIS);
        TimefliesOracle oracle3 = new TimefliesOracle("BTCOracle",paiDAO,RAY,uint96(123));
        bool tempBool = p1.callSetOracle(finance,oracle2);
        assertTrue(!tempBool);
        tempBool = admin.callSetOracle(finance,oracle2);
        assertTrue(tempBool);
        assertEq(finance.priceOracle(),oracle2);
        tempBool = admin.callSetOracle(finance,oracle3);
        assertTrue(!tempBool);
    }

    function testSetPISseller() public {
        setup();
        assertEq(finance.PISseller(),0x0);
        bool tempBool = p1.callSetPISseller(finance,p2);
        assertTrue(!tempBool);
        tempBool = admin.callSetPISseller(finance,p2);
        assertEq(finance.PISseller(),p2);
    }

    function testIncreaseOperationCashLimit() public {
        setup();
        assertEq(finance.operationCashLimit(),0);
        bool tempBool = p1.callIncreaseOperationCashLimit(finance,1000);
        assertTrue(!tempBool);
        tempBool = admin.callIncreaseOperationCashLimit(finance,1000);
        assertTrue(tempBool);
        assertEq(finance.operationCashLimit(),1000);
        tempBool = admin.callIncreaseOperationCashLimit(finance,1000);
        assertTrue(tempBool);
        assertEq(finance.operationCashLimit(),2000);
    }

    function testSetSafePad() public {
        setup();
        assertEq(finance.safePad(),0);
        bool tempBool = p1.callSetSafePad(finance,1000);
        assertTrue(!tempBool);
        tempBool = admin.callSetSafePad(finance,1000);
        assertTrue(tempBool);
        assertEq(finance.safePad(),1000);
        tempBool = admin.callSetSafePad(finance,1500);
        assertTrue(tempBool);
        assertEq(finance.safePad(),1500);
    }

    function testSetPISmintRate() public {
        setup();
        assertEq(finance.PISmintRate(),0);
        bool tempBool = p1.callSetPISmintRate(finance,1000);
        assertTrue(!tempBool);
        tempBool = admin.callSetPISmintRate(finance,1000);
        assertTrue(tempBool);
        assertEq(finance.PISmintRate(),1000);
        tempBool = admin.callSetPISmintRate(finance,1500);
        assertTrue(tempBool);
        assertEq(finance.PISmintRate(),1500);
    }


}

contract FunctionTest is TestBase {
    function testPayForInterest() public {
        setup();
        bool tempBool = p1.callPayForInterest(finance, 100, p2);
        assertTrue(!tempBool);
        tempBool = admin.callPayForInterest(finance, 100, p2);
        assertTrue(!tempBool);
        admin.callCreateNewRole(paiDAO,"TDC@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,admin,"TDC@STCoin");
        tempBool = admin.callPayForInterest(finance, 100, p2);
        assertTrue(tempBool);
        assertEq(flow.balance(p2,ASSET_PAI), 100);
    }

    function testPayForDebt() public {
        setup();
        bool tempBool = p1.callPayForDebt(finance, 400000000);
        assertTrue(!tempBool);
        tempBool = admin.callPayForDebt(finance, 400000000);
        assertTrue(!tempBool);
        admin.callCreateNewRole(paiDAO,"Liqudator@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,admin,"Liqudator@STCoin");
        tempBool = admin.callPayForDebt(finance, 400000000);
        assertTrue(tempBool);
        assertEq(flow.balance(admin,ASSET_PAI), 400000000);
        tempBool = admin.callPayForDebt(finance, 5000000000);
        assertTrue(tempBool);
        assertEq(flow.balance(admin,ASSET_PAI), 4400000000);
    }

    function testPayForDividends() public {
        setup();
        FakePerson p3 = new FakePerson();
        DividendsSample dd = new DividendsSample(p1,p2,p3,finance);
        bool tempBool = p1.callGetMoney(dd);
        assertTrue(!tempBool);
        admin.callCreateNewRole(paiDAO,"Dividends@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,dd,"Dividends@STCoin");
        tempBool = p1.callGetMoney(dd);
        assertTrue(tempBool);
        tempBool = p2.callGetMoney(dd);
        assertTrue(tempBool);
        tempBool = p3.callGetMoney(dd);
        assertTrue(tempBool);
        assertEq(flow.balance(p1,ASSET_PAI), 10000);
        assertEq(flow.balance(p2,ASSET_PAI), 20000);
        assertEq(flow.balance(p3,ASSET_PAI), 30000);
    }

    function testAirDrop() public {
        setup();
        assertEq(finance.applyAmount(),0);
        bool tempBool = p1.callApplyForAirDropCashOut(finance,1000);
        assertTrue(!tempBool);
        tempBool = p2.callCreateDepositBorrow(cdp,10000000000,0,20000000000,ASSET_BTC);
        assertTrue(tempBool);
        admin.callCreateNewRole(paiDAO,"AirDrop@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,p1,"AirDrop@STCoin");
        tempBool = p1.callApplyForAirDropCashOut(finance,1000);
        assertTrue(tempBool);
        assertEq(finance.applyAmount(),1000);
        assertEq(finance.applyNonce(),1);
        assertEq(finance.applyAddr(),p1);
        assertEq(finance.applyTime(),block.timestamp);

        //10000000000 * 0.2 * 1 days / 365 days = 5479452
        tempBool = p1.callApplyForAirDropCashOut(finance,5479452);
        assertTrue(tempBool);
        assertEq(finance.applyAmount(),5479452);
        assertEq(finance.applyNonce(),2);
        assertEq(finance.applyAddr(),p1);
        assertEq(finance.applyTime(),block.timestamp);

        //overAsk
        tempBool = p1.callApplyForAirDropCashOut(finance,10000000);
        assertTrue(tempBool);
        assertEq(finance.applyAmount(),5479452);
        assertEq(finance.applyNonce(),3);
        assertEq(finance.applyAddr(),p1);
        assertEq(finance.applyTime(),block.timestamp);

        //approval
        assertEq(finance.lastAirDropCashOut(),0);
        tempBool = p2.callApprovalAirDropCashOut(finance,3,true);
        admin.callCreateNewRole(paiDAO,"CFO@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,p2,"CFO@STCoin");
        tempBool = p2.callApprovalAirDropCashOut(finance,3,true);
        assertEq(finance.applyAmount(),0);
        assertEq(finance.lastAirDropCashOut(),block.timestamp);
        assertEq(flow.balance(p1,ASSET_PAI),5479452);

        //ask again
        tempBool = p1.callApplyForAirDropCashOut(finance,100);
        assertTrue(tempBool);
        assertEq(finance.applyAmount(),0);
        assertEq(finance.applyNonce(),4);
        assertEq(finance.applyAddr(),p1);
        assertEq(finance.applyTime(),block.timestamp);

        //reject
        finance.fly(1 days);
        tempBool = p1.callApplyForAirDropCashOut(finance,100);
        assertTrue(tempBool);
        assertEq(finance.applyAmount(),100);
        assertEq(finance.applyNonce(),5);
        assertEq(finance.applyAddr(),p1);
        assertEq(finance.applyTime(),block.timestamp + 1 days);
        tempBool = p2.callApprovalAirDropCashOut(finance,5,false);
        assertTrue(tempBool);
        assertEq(finance.applyAmount(),0);

        //not reach limit
        tempBool = p1.callApplyForAirDropCashOut(finance,100);
        assertTrue(tempBool);
        assertEq(finance.applyAmount(),100);
        assertEq(finance.applyNonce(),6);
        assertEq(finance.applyAddr(),p1);
        assertEq(finance.applyTime(),block.timestamp + 1 days);
        tempBool = p2.callApprovalAirDropCashOut(finance,6,true);
        assertTrue(tempBool);
        assertEq(finance.applyAmount(),0);
        assertEq(flow.balance(p1,ASSET_PAI),5479452 + 100);
        tempBool = p1.callApplyForAirDropCashOut(finance,100);
        assertTrue(tempBool);
        assertEq(finance.applyAmount(),0);

        //wrong index
        finance.fly(1 days);
        tempBool = p1.callApplyForAirDropCashOut(finance,1000);
        assertTrue(tempBool);
        assertEq(finance.applyAmount(),1000);
        assertEq(finance.applyNonce(),8);
        assertEq(finance.applyAddr(),p1);
        assertEq(finance.applyTime(),block.timestamp + 2 days);
        tempBool = p2.callApprovalAirDropCashOut(finance,7,true);
        assertTrue(!tempBool);
    }

    function testCashOut() public {
        setup();
        assertEq(flow.balance(finance,ASSET_PAI),4400000000);
        bool tempBool = p1.callCashOut(finance,400000000,p2);
        assertTrue(!tempBool);
        tempBool = admin.callCashOut(finance,400000000,p2);
        assertTrue(tempBool);
        assertEq(flow.balance(finance,ASSET_PAI),4000000000);
    }

    function testOperationCashOut() public {
        setup();
        assertEq(flow.balance(finance,ASSET_PAI),4400000000);
        bool tempBool = p1.callOperationCashOut(finance,400000000,p2);
        assertTrue(!tempBool);
        tempBool = p2.callOperationCashOut(finance,400000000,p2);
        assertTrue(!tempBool);

        admin.callCreateNewRole(paiDAO,"CFO@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,p2,"CFO@STCoin");
        assertEq(finance.operationCashLimit(),0);
        admin.callIncreaseOperationCashLimit(finance,400000000);
        assertEq(finance.operationCashLimit(),400000000);
        tempBool = p2.callOperationCashOut(finance,400000000,p2);
        assertTrue(tempBool);
        assertEq(flow.balance(finance,ASSET_PAI),4000000000);
        assertEq(finance.operationCashLimit(),0);
    }

    function testAutoMintPIS() public {
        setup();
        bool tempBool = p1.callMintPIS(finance);
        assertTrue(!tempBool);
        tempBool = admin.callSetPISseller(finance,p2);
        assertTrue(tempBool);
        tempBool = admin.callSetPISmintRate(finance,RAY * 2);
        admin.callSetPISseller(finance,p2);
        assertTrue(tempBool);
        tempBool = p1.callMintPIS(finance);
        assertTrue(!tempBool);
        admin.callSetSafePad(finance,4400000010);
        tempBool = p1.callMintPIS(finance);
        assertTrue(!tempBool);
        admin.callCreateNewRole(paiDAO,"FinanceContract","ADMIN",0,false);
        admin.callAddMember(paiDAO,finance,"FinanceContract");
        tempBool = p1.callMintPIS(finance);
        assertTrue(tempBool);
        assertEq(flow.balance(p2,ASSET_PIS),880000002);
    }
}