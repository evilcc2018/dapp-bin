pragma solidity 0.4.25;

import "../../library/template.sol";
import "../../library/utils/ds_math.sol";
import "../testPI.sol";
import "../pai_main.sol";
import "./testPrepare.sol";

contract TestPaiMain is Template, DSTest, DSMath {
    function() public payable {}

    uint96 ASSET_PIS;
    string ADMIN = "ADMIN";
    string DirPisVote = "DirPisVote";
    string TESTLIMITATION = "TESTLIMITATION";

    function testInit() public {
        FakePaiDaoNoGovernance paiDAO;

        FakePerson p1 = new FakePerson();
        FakePerson p2 = new FakePerson();

        paiDAO = FakePaiDaoNoGovernance(p1.createPAIDAONoGovernance("PAIDAO"));
        assertTrue(paiDAO.addressExist(bytes(ADMIN),p1)); //0

        //test whether governance function is shielded
        assertTrue(paiDAO.canPerform(ADMIN,p1)); //1
        assertTrue(paiDAO.canPerform(ADMIN,p2)); //2

        bool tempBool = p2.callInit(paiDAO);
        assertTrue(tempBool);//3
        tempBool = p2.callInit(paiDAO);
        assertTrue(!tempBool);//4
        tempBool = p1.callInit(paiDAO);
        assertTrue(!tempBool);//5

        ASSET_PIS = paiDAO.PISGlobalId();
        paiDAO.mint(100000000,p2);//6
        assertEq(100000000,flow.balance(p2,ASSET_PIS));
    }

    function testAssetRelated() public {
        FakePaiDaoNoGovernance paiDAO;
        paiDAO = new FakePaiDaoNoGovernance("PAIDAO");
        paiDAO.init();
        ASSET_PIS = paiDAO.PISGlobalId();
        FakePerson p1 = new FakePerson();
        p1.callMint(paiDAO,100000000,p1);
        Registry registry = Registry(0x630000000000000000000000000000000000000065);
        (bool exist, string memory name, string memory symbol, string memory description, uint totalSupply,) =
            registry.getAssetInfoByAssetId(paiDAO.organizationId(),0);
        assertTrue(exist);//0
        assertEq(name,"PIS");//1
        assertEq(symbol,"PIS");//2
        assertEq(description,"Share of PAIDAO");//3
        assertEq(totalSupply,100000000);//4

        paiDAO.mint(100000000,p1);
        totalSupply = paiDAO.totalSupply();
        assertEq(totalSupply,200000000);//5
        bool tempBool = p1.callBurn(paiDAO,50000000,ASSET_PIS);
        assertTrue(tempBool);//6
        totalSupply = paiDAO.totalSupply();
        assertEq(totalSupply,150000000);//7
    }

    function testGovernance() public {
        FakePaiDao paiDAO;
        FakePerson p1 = new FakePerson();
        FakePerson p2 = new FakePerson();
        FakePerson p3 = new FakePerson();
        FakePerson p4 = new FakePerson();
        FakePerson p5 = new FakePerson();

        paiDAO = FakePaiDao(p1.createPAIDAO("PAIDAO"));
        paiDAO.init();
        ASSET_PIS = paiDAO.PISGlobalId();

        p1.callCreateNewRole(paiDAO,"DirPisVote","ADMIN",0,false);
        p1.callAddMember(paiDAO,p1,"DirPisVote");

        assertTrue(paiDAO.addressExist(bytes(DirPisVote),p1));//0


        bool tempBool = p1.callMint(paiDAO,100000000,p1);
        assertTrue(tempBool);//1
        tempBool = p2.callMint(paiDAO,100000000,p2);
        assertTrue(!tempBool);//2
        tempBool = p1.callAddMember(paiDAO,p2,"DirPisVote");
        assertTrue(tempBool);//3
        tempBool = p2.callMint(paiDAO,100000000,p2);
        assertTrue(tempBool);//4
        tempBool = p1.callRemoveMember(paiDAO,p2,"DirPisVote");
        assertTrue(tempBool);//5
        tempBool = p2.callMint(paiDAO,100000000,p2);
        assertTrue(!tempBool);//6


        tempBool = p1.callCreateNewRole(paiDAO,"DIRECTOR","ADMIN",0,false);
        assertTrue(tempBool);//7
        tempBool = p1.callCreateNewRole(paiDAO,"CASHIER","DIRECTOR",0,false);
        assertTrue(tempBool);//8
        tempBool = p1.callAddMember(paiDAO,p3,"DIRECTOR");
        assertTrue(tempBool);//9
        tempBool = p1.callAddMember(paiDAO,p4,"CASHIER");
        assertTrue(!tempBool);//10
        tempBool = p3.callAddMember(paiDAO,p4,"CASHIER");
        assertTrue(tempBool);//11
        tempBool = p1.callRemoveMember(paiDAO,p3,"DIRECTOR");
        assertTrue(tempBool);//12
        tempBool = p3.callAddMember(paiDAO,p5,"CASHIER");
        assertTrue(!tempBool);//13

        tempBool = p1.callCreateNewRole(paiDAO,"DIRECTOR2","ADMIN",0,false);
        assertTrue(tempBool);//14
        tempBool = p1.callCreateNewRole(paiDAO,"CASHIER2","DIRECTOR2",0,false);
        assertTrue(tempBool);//15
        tempBool = p1.callAddMember(paiDAO,p4,"CASHIER2");
        assertTrue(!tempBool);//16
        tempBool = p1.callAddMember(paiDAO,p1,"DIRECTOR2");
        assertTrue(tempBool);//17
        tempBool = p1.callAddMember(paiDAO,p2,"DIRECTOR2");
        assertTrue(tempBool);//18
        tempBool = p1.callAddMember(paiDAO,p3,"DIRECTOR2");
        assertTrue(tempBool);//19
        tempBool = p1.callRemoveMember(paiDAO,p1,"DIRECTOR2");
        assertTrue(tempBool);//20
        tempBool = p1.callAddMember(paiDAO,p4,"CASHIER2");
        assertTrue(!tempBool);//21
        tempBool = p2.callAddMember(paiDAO,p4,"CASHIER2");
        assertTrue(tempBool);//22

        address[] list;
        list.push(p1);
        list.push(p5);
        tempBool = p1.callResetMembers(paiDAO,list,"DIRECTOR2");
        assertTrue(tempBool); //23
        tempBool = p1.callAddMember(paiDAO,p2,"CASHIER2");
        assertTrue(tempBool); //24
        tempBool = p2.callAddMember(paiDAO,p3,"CASHIER2");
        assertTrue(!tempBool);//25
        tempBool = p3.callAddMember(paiDAO,p3,"CASHIER2");
        assertTrue(!tempBool);//26
        tempBool = p4.callAddMember(paiDAO,p3,"CASHIER2");
        assertTrue(!tempBool);//27
        tempBool = p5.callAddMember(paiDAO,p3,"CASHIER2");
        assertTrue(tempBool); //28


        tempBool = p1.callCreateNewRole(paiDAO,"DIRECTOR3","ADMIN",0,false);
        assertTrue(tempBool);//29
        tempBool = p1.callCreateNewRole(paiDAO,"DIRECTOR4","ADMIN",0,false);
        assertTrue(tempBool);//30
        tempBool = p1.callCreateNewRole(paiDAO,"CASHIER3","DIRECTOR3",0,false);
        assertTrue(tempBool);//31
        tempBool = p1.callAddMember(paiDAO,p2,"DIRECTOR3");
        assertTrue(tempBool);//32
        tempBool = p1.callAddMember(paiDAO,p3,"DIRECTOR4");
        assertTrue(tempBool);//33
        tempBool = p2.callAddMember(paiDAO,p4,"CASHIER3");
        assertTrue(tempBool);//34
        tempBool = p3.callAddMember(paiDAO,p5,"CASHIER3");
        assertTrue(!tempBool);//35
        tempBool = p2.callChangeSuperior(paiDAO,"CASHIER3","DIRECTOR4");
        assertTrue(!tempBool);//36
        tempBool = p1.callChangeSuperior(paiDAO,"CASHIER3","DIRECTOR4");
        assertTrue(tempBool);//37
        tempBool = p2.callAddMember(paiDAO,p5,"CASHIER3");
        assertTrue(!tempBool);//38
        tempBool = p3.callAddMember(paiDAO,p5,"CASHIER3");
        assertTrue(tempBool);//39

        tempBool = p1.callCreateNewRole(paiDAO,"TESTLIMITATION","ADMIN",3,false);
        assertTrue(tempBool);//40
        tempBool = p1.callAddMember(paiDAO,p1,"TESTLIMITATION");
        assertTrue(tempBool);//41
        tempBool = p1.callAddMember(paiDAO,p2,"TESTLIMITATION");
        assertTrue(tempBool);//42
        tempBool = p1.callAddMember(paiDAO,p3,"TESTLIMITATION");
        assertTrue(tempBool);//43
        tempBool = p1.callAddMember(paiDAO,p4,"TESTLIMITATION");
        assertTrue(!tempBool);//44
        tempBool = p1.callRemoveMember(paiDAO,p2,"TESTLIMITATION");
        assertTrue(tempBool);//45
        tempBool = p1.callAddMember(paiDAO,p4,"TESTLIMITATION");
        assertTrue(tempBool);//46

        list.length = 0;
        list.push(p2);
        list.push(p3);
        list.push(p4);
        list.push(p5);
        tempBool = p1.callResetMembers(paiDAO,list,"TESTLIMITATION");
        assertTrue(!tempBool); //47
        tempBool = p2.callChangeMemberLimit(paiDAO,"TESTLIMITATION",4);
        assertTrue(!tempBool);//48
        tempBool = p1.callChangeMemberLimit(paiDAO,"TESTLIMITATION",4);
        assertTrue(tempBool);//49
        uint limit = paiDAO.getMemberLimit(bytes(TESTLIMITATION));
        assertEq(uint(limit),4);//50
        tempBool = p1.callResetMembers(paiDAO,list,"TESTLIMITATION");
        assertTrue(tempBool);//51

    }

    function testChangeTopAdmin() public {
        //callChangeTopAdmin
        FakePaiDao paiDAO;
        FakePerson p1 = new FakePerson();
        FakePerson p2 = new FakePerson();
        FakePerson p3 = new FakePerson();
        FakePerson p4 = new FakePerson();
        FakePerson p5 = new FakePerson();

        paiDAO = FakePaiDao(p1.createPAIDAO("PAIDAO"));
        paiDAO.init();
        bool tempBool = p2.callCreateNewRole(paiDAO,"PISVOTE","ADMIN",0,false);
        assertTrue(!tempBool);
        tempBool = p1.callCreateNewRole(paiDAO,"PISVOTE","ADMIN",0,false);
        assertTrue(tempBool);
        tempBool = p1.callAddMember(paiDAO,p3,"PISVOTE");
        assertTrue(tempBool);
        tempBool = p3.callCreateNewRole(paiDAO,"CHANGETEST","ADMIN",0,false);
        assertTrue(!tempBool);
        tempBool = p1.callChangeTopAdmin(paiDAO,"PISVOTE");
        assertTrue(tempBool);
        tempBool = p3.callCreateNewRole(paiDAO,"CHANGETEST","ADMIN",0,false);
        assertTrue(tempBool);

    }
}