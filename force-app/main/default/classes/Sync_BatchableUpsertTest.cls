@isTest
public without sharing class Sync_BatchableUpsertTest {

    @TestSetup
    static void makeData(){
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
    }

    @isTest
    static void Sync_BatchableUpsertTest() {
        
        Test.startTest();

        // Execute batch for Account
        List<String> objNames = new List<String>{'Account'};
        Id batchInstanceId = Database.executeBatch(new Sync_BatchableUpsert(objNames), 5);
        System.debug('batchInstanceId: ' + batchInstanceId);

        Test.stopTest();

        List<Sync_Log_Record__c> logRecs = [SELECT Id, Name FROM Sync_Log_Record__c WHERE Status__c = 'Success' AND Type__c = 'Account'];
        system.assertEquals(logRecs.size(), 1);
        List<Account> accts = [SELECT Id, Name, GFW_Account_ID__c, RecordType.Name FROM Account];
        system.debug('acct name: ' + accts[0].Name);
        system.assertEquals(logRecs.size(), accts.size());
        system.assertEquals('Household Account', accts[0].RecordType.Name);
        system.assertEquals('0011Y00002LvEcKQAV', accts[0].GFW_Account_ID__c);

    }
}