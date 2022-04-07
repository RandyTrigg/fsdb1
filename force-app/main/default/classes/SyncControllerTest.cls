@isTest
public without sharing class SyncControllerTest {
    
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
}
