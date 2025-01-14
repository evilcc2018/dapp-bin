pragma solidity 0.4.25;

import "../../library/template.sol";
import "../price_oracle.sol";
import "../testPI.sol";
import "./testPrepare.sol";

contract GlobalSettingTest is Template, DSTest, DSMath {
    
    function testAll() public {
        FakePaiDao paiDAO;
        FakePerson admin = new FakePerson();
        FakePerson p1 = new FakePerson();
        FakePerson p2 = new FakePerson();

        paiDAO = FakePaiDao(admin.createPAIDAO("PAIDAO"));
        paiDAO.init();
        admin.callCreateNewRole(paiDAO,"50%Demonstration@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,p1,"50%Demonstration@STCoin");
        admin.callCreateNewRole(paiDAO,"DirVote@STCoin","ADMIN",0,false);
        admin.callAddMember(paiDAO,p1,"DirVote@STCoin");
        admin.callCreateNewRole(paiDAO,"DirPisVote","ADMIN",0,false);
        admin.callAddMember(paiDAO,p1,"DirPisVote");
        Setting setting = new Setting(paiDAO);

        bool tempBool = p2.callUpdateLendingRate(setting, RAY / 10);
        assertTrue(!tempBool);
        assertEq(setting.lendingInterestRate(),RAY / 5);
        tempBool = p1.callUpdateLendingRate(setting, RAY / 10);
        assertTrue(tempBool);
        assertEq(setting.lendingInterestRate(),RAY / 10);

        tempBool = p2.callUpdateDepositRate(setting, RAY / 10);
        assertTrue(!tempBool);
        assertEq(setting.currentDepositRate(),RAY / 5);
        tempBool = p1.callUpdateDepositRate(setting, RAY / 10);
        assertTrue(tempBool);
        assertEq(setting.depositInterestRate(),RAY / 10);

        tempBool = p2.callUpdateRatioLimit(setting, uint96(123), RAY / 10);
        assertTrue(!tempBool);
        assertEq(setting.mintPaiRatioLimit(uint96(123)), 0);
        tempBool = p1.callUpdateRatioLimit(setting, uint96(123), RAY / 10);
        assertTrue(tempBool);
        assertEq(setting.mintPaiRatioLimit(uint96(123)), RAY / 10);

        assertTrue(setting.globalOpen());
        tempBool = p2.callGlobalShutDown(setting);
        assertTrue(!tempBool);
        assertTrue(setting.globalOpen());
        tempBool = p1.callGlobalShutDown(setting);
        assertTrue(tempBool);
        assertTrue(!setting.globalOpen());
        tempBool = p2.callGlobalReopen(setting);
        assertTrue(!tempBool);
        assertTrue(!setting.globalOpen());
        tempBool = p1.callGlobalReopen(setting);
        assertTrue(tempBool);
        assertTrue(setting.globalOpen());

    }
}