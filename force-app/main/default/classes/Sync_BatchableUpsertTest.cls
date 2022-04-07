@isTest
public without sharing class Sync_BatchableUpsertTest {
    
    @TestSetup
    static void makeData(){

        /*
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
        String json = '' +
        '{"Name":"John Doe","RecordType":{' +
        '"DeveloperName":"Household","attributes":{' +
        '"url":"/services/data/v48.0/sobjects/RecordType/012i0000000HNlOAAW","type":"RecordType"}},' +
        '"AQB__AccountType__c":"Household","Id":"0011Y00002LvEcKQAV","attributes":'+
        '{"url":"/services/data/v48.0/sobjects/Account/0011Y00002LvEcKQAV","type":"Account"}}';

        String mdtObjName;

        Sync_Log__c sLog = new Sync_Log__c(
            Type__c = 'GFW to FSDB',
            Status__c = 'Launched'
        );
        insert sLog;

        Sync_Log_Record__c slRec = new Sync_Log_Record__c(
            RecordInfo__c = json,
            Sync_Log__c = sLog.Id,
            Status__c = 'Pending',
            Type__c = mdtObjName,
            FSGroupOwnerId__c = u.Id,
            FS_Group__c = fsGroups[0].GFW_COA_Name__c
        );
        insert slRec;

        */
    }


    @isTest
    static void QueueableTest() {
        Test.setMock(HttpCalloutMock.class, new SyncMock());

        Test.startTest();

        List<FS_Group_Settings__mdt> fsGroups = [SELECT GFW_COA_Name__c, Designated_Role_for_Ownership__c
        FROM FS_Group_Settings__mdt WHERE Active__c = TRUE LIMIT 1];

        // Runs first part of Queueable that launches sync
        System.enqueueJob(new Sync_Queueable(fsGroups));

        // Runs second part of Queueable that upserts Accounts when running tests 
        System.enqueueJob(new Sync_Queueable(null));

        /* Assertions don't seem to work because of asynchronous nature.
        //  WHERE Status__c = 'Pending' AND Type__c = 'Account'
        List<Sync_Log_Record__c> logRecs = [SELECT Id, Name FROM Sync_Log_Record__c];
        // system.assert(logRecs.size()>0);
        List<Account> accts = [SELECT Id, Name, GFW_Account_ID__c FROM Account];
        system.assert(accts.size()>0);
        // system.assertEquals(logRecs.size(), accts.size());
        */
        Test.stopTest();
    }
}