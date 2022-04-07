@isTest
public without sharing class Sync_QueueableTest {

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

        Test.stopTest();

        List<Sync_Log_Record__c> logRecs = [SELECT Id, Name FROM Sync_Log_Record__c WHERE Status__c = 'Success' AND Type__c = 'Account'];
        system.assert(logRecs.size()>0);
        List<Account> accts = [SELECT Id, Name, GFW_Account_ID__c FROM Account];
        system.assert(accts.size()>0);
        system.assertEquals(logRecs.size(), accts.size());
    }
}
