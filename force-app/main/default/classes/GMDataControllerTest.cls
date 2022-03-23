@isTest
public class GMDataControllerTest {
    /**********************************
     * Test the component-related methods
     * *******************************/

    static testMethod void GMDataControllerTest1() {
        // Build new records
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'acc test',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Id aId = [SELECT Id FROM Account LIMIT 1].Id;
        insert new Profile__c(
            Expiration_date__c = Date.newInstance(1960, 2, 17)
        );
        Profile__c p = [SELECT Id FROM Profile__c LIMIT 1];
        Id pId = p.Id;
        insert new Portfolio__c(Name = 'Test portfolio', Type__c = 'Priority');
        Id portId = [SELECT Id FROM Portfolio__c LIMIT 1].Id;
        insert new Portfolio_Profile_Assign__c(
            Profile__c = pId,
            Portfolio__c = portId
        );
        insert new GM_Data__c(Account__c = aId, Portfolio__c = portId);
        Id gId = [SELECT Id FROM GM_Data__c LIMIT 1].Id;
        insert new Restricted_Classification__c(
            Name = 'Test restr class 1',
            Type__c = 'Outcome'
        );
        insert new Restricted_Classification__c(
            Name = 'Test restr class 2',
            Type__c = 'Outcome'
        );
        Id rcId1 = [
            SELECT Id
            FROM Restricted_Classification__c
            WHERE Name = 'Test restr class 1'
            LIMIT 1
        ]
        .Id;
        Id rcId2 = [
            SELECT Id
            FROM Restricted_Classification__c
            WHERE Name = 'Test restr class 2'
            LIMIT 1
        ]
        .Id;
        insert new Restricted_Classification_Portfolio__c(
            Portfolio__c = portId,
            Restricted_Classification__c = rcId1
        );
        insert new Restricted_Classification_GM_Data__c(
            GM_Data__c = gId,
            Restricted_Classification__c = rcId1
        );

        insert new Indicator__c(
            Name = 'test indicator 1',
            GM_Data_field_name__c = 'Test_indicator_tracking__c'
        );
        insert new Indicator__c(
            Name = 'test indicator 2',
            GM_Data_field_name__c = 'Test_indicator_tracking__c'
        );
        insert new Indicator__c(
            Name = 'test indicator 3',
            GM_Data_field_name__c = 'Test_indicator_tracking__c'
        );
        Id indId1 = [
            SELECT Id
            FROM Indicator__c
            WHERE Name = 'test indicator 1'
            LIMIT 1
        ]
        .Id;
        Id indId2 = [
            SELECT Id
            FROM Indicator__c
            WHERE Name = 'test indicator 2'
            LIMIT 1
        ]
        .Id;
        Id indId3 = [
            SELECT Id
            FROM Indicator__c
            WHERE Name = 'test indicator 3'
            LIMIT 1
        ]
        .Id;
        insert new Indicator_Assign__c(
            Indicator__c = indId1,
            GM_Data__c = gId,
            Quantity__c = 13
        );
        insert new Indicator_Assign__c(
            Indicator__c = indId2,
            GM_Data__c = gId,
            Quantity__c = 14
        );

        Test.StartTest();
        GMDataController.GMDataInfo gm = GMDataController.getGMDataInfo(gId);
        gm.indicatorAssignInfo.put(indId1, '15;'); // Update an existing indicator assign.
        gm.indicatorAssignInfo.put(indId3, '111;abc'); // Insert a new indicator assign.
        system.debug('gm = ' + JSON.serialize(gm));
        GMDataController.saveGMDataInfo(JSON.serialize(gm));
        gm = GMDataController.getGMDataInfo(gId);
        gm.selectedIdsPacked.put(gId, (String) rcId2);
        GMDataController.saveGMDataInfo(JSON.serialize(gm));
        Test.StopTest();
    }

    /**********************************
     * Test the VF-related methods
     * *******************************/

    static testMethod void GMDataControllerTestVF() {
        // Build new records
        InitTestObjects(10);
        Map<Id, GM_Data__c> gMap = new Map<Id, GM_Data__c>(
            [SELECT Id FROM GM_Data__c]
        );
        // Build new standard set controller and select the new profiles.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            gMap.values()
        );
        ssc.setSelected(gMap.values());

        Test.StartTest();
        // Build a new profile controller and use it to build new letters for the selected profiles.
        insert (new Template__c(
            Name = 'Test template',
            Source_object__c = 'GM_Data__c'
        ));
        GMDataController pc = new GMDataController(ssc);
        pc.selectedTemplate = 'Test template';
        system.assertNotEquals(
            Utilities.recordIdFromName('Template__c', pc.selectedTemplate),
            null
        );
        pc.buildLetters();
        Test.StopTest();

        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Id FROM Letter__c]
        );
        validate(lMap.keySet());
    }

    static void validate(Set<ID> lIds) {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Emails__c, GM_Data__c FROM Letter__c WHERE Id IN :lIds]
        );
        Map<Id, GM_Data__c> gMap = new Map<Id, GM_Data__c>(
            [
                SELECT Id
                FROM GM_Data__c
                WHERE Id IN (SELECT GM_Data__c FROM Letter__c WHERE Id IN :lIds)
            ]
        );
        // Should be a different letter for each profile.
        system.assertEquals(lMap.size(), gMap.size());
    }

    // NOTE: Not providing email addresses, because we'd have to create linked contacts and accounts.
    static void InitTestObjects(Integer NumberOfRecords) {
        // Build and insert GM data records.
        List<GM_Data__c> gas = new List<GM_Data__c>();
        for (Integer x = 0; x < NumberOfRecords; x++) {
            gas.add(new GM_Data__c());
        }
        insert gas;
    }

    // Test the code that updates risk fields.
    static testMethod void GMDataControllerTest2() {
        // Build records
        BuildTestProposals.InitTestObjects(1, 1);
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        // Build two grants with milestones on that account.
        // NOTE: Uncomment out the following lines to get more coverage from the test.  But they must be
        // commented out when deploying to avoid "Too many SOQL" errors.
        /*
        insert new Proposal__c (Account__c = acc.Id, Date_awarded__c = Date.today().addDays(-100), Amount_awarded__c = 100);
        Proposal__c prop2 = [SELECT Id FROM Proposal__c WHERE Amount_awarded__c = 100 LIMIT 1];
        insert new Milestone__c (Proposal__c = prop2.Id, Type__c = 'Report', Date_due__c = Date.today().addDays(-30));
        insert new Proposal__c (Account__c = acc.Id, Date_awarded__c = Date.today().addDays(-100), Amount_awarded__c = 200);
        Proposal__c prop3 = [SELECT Id FROM Proposal__c WHERE Amount_awarded__c = 200 LIMIT 1];
        insert new Milestone__c (Proposal__c = prop3.Id, Type__c = 'Report', Date_due__c = Date.today().addDays(-60));
        */

        Test.StartTest();
        String cronExp = '0 0 0 15 3 ?';
        System.schedule(
            'GMDataUpdateSchedule',
            cronExp,
            new GMDataUpdateSchedule()
        );
        Test.StopTest();
    }
}