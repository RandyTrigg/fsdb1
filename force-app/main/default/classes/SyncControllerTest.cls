@isTest
public with sharing class SyncControllerTest {
    
    @isTest 
    static void testLaunchSync() {

        Test.setMock(HttpCalloutMock.class, new SyncMock());
        List<FS_Group_Settings__mdt> fsGroups = [SELECT GFW_COA_Name__c, Designated_Role_for_Ownership__c
        FROM FS_Group_Settings__mdt WHERE Active__c = TRUE];

        Test.startTest();
        SyncController scThisFS = new SyncController();
        scThisFS.startDateTime = datetime.now();
        scThisFS.fsCOA = fsGroups[0].GFW_COA_Name__c;
        scThisFS.fsRole = fsGroups[0].Designated_Role_for_Ownership__c;
        String jsonResults = scThisFS.doQueryNextBatchCallout('testURL');
        scThisFS.LaunchSync();
        system.assert(jsonResults!='');
        List<Sync_Log_Record__c> logRecs = [SELECT Id, Name FROM Sync_Log_Record__c WHERE Status__c = 'Pending'];
        system.assert(logRecs.size()>0);
        Test.stopTest();
    }

    
    @isTest 
    static void testUpsertRecs() {
        // Test data should only be used in this test method

        // Create user for owner
        String emluname = 'user@name.org';
        Id pId = [SELECT Id FROM Profile WHERE Name =  'System Administrator' LIMIT 1].Id;
        User u = new User(
            Username = emluname,
            Email = emluname,
            CommunityNickname = emluname.left(4),
            LastName = 'testOwner',
            FirstName = 'testOwner',
            Alias = emluname.left(4),
            ProfileId = pId,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'GMT'
        );
        insert u;
        
        // Set up Sync Log and Sync Log Records
        List<FS_Group_Settings__mdt> fsGroups = [SELECT GFW_COA_Name__c, Designated_Role_for_Ownership__c
        FROM FS_Group_Settings__mdt WHERE Active__c = TRUE];
        String json = '' +
        '{"Name":"Jane Doe","RecordType":{' +
        '"DeveloperName":"Household","attributes":{' +
        '"url":"/services/data/v48.0/sobjects/RecordType/012i0000000HNlOAAW","type":"RecordType"}},' +
        '"AQB__AccountType__c":"Household","Id":"0011Y00002LvEcKQAV","attributes":'+
        '{"url":"/services/data/v48.0/sobjects/Account/0011Y00002LvEcKQAV","type":"Account"}}';

        Sync_Log__c sLog = new Sync_Log__c(
            Type__c = 'GFW to FSDB',
            Status__c = 'Launched'
        );
        insert sLog;

        Sync_Log_Record__c slRec = new Sync_Log_Record__c(
            RecordInfo__c = json,
            Sync_Log__c = sLog.Id,
            Status__c = 'Pending',
            Type__c = 'Account',
            FSGroupOwnerId__c = u.Id,
            FS_Group__c = fsGroups[0].GFW_COA_Name__c
        );
        insert slRec;

        Test.startTest();
        SyncController scThisFS = new SyncController();
        String mdtObjName = 'Account';
        List<sObject> recs = new List<sObject>(scThisFS.buildRecsToUpsert(mdtObjName));
        Test.stopTest();

        system.debug('Here is the final list: ' + recs);
        for (sObject rec : recs) {
            Account acct = (Account)rec;
            system.assertEquals(acct.Name, 'Jane Doe');
            system.assertEquals(acct.GFW_Account_ID__c, '0011Y00002LvEcKQAV');
        }
    
    }

}
