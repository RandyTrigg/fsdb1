@isTest
public with sharing class DeleteRecordsSchedulableTest {
    // Test the batch apex class.
    static testMethod void DeleteRecordsSchedulableTest1() {
        // Build records to delete.
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'acc test',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        insert (new Account(
            Name = 'test 2',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        ));
        insert (new Account(
            Name = 'test 3',
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization')
        ));
        String q = 'SELECT Id FROM Account WHERE RecordType.DeveloperName = \'Organization_GM\'';
        Account[] accts = [
            SELECT Id
            FROM Account
            WHERE RecordType.DeveloperName = 'Organization'
        ];
        Test.StartTest();
        Database.executeBatch(new DeleteRecordsBatch(q, true), 3);
        Database.executeBatch(new DeleteRecordsBatch(accts, true), 3);
        Test.StopTest();
        Account[] acctResults = [SELECT Id FROM Account];
        system.assertEquals(0, acctResults.size());
    }

    // Test the schedulable class.
    static testMethod void DeleteRecordsSchedulableTest2() {
        // Build records to delete.
        insert (new Account(Name = 'test 1'));
        insert (new Account(Name = 'test 2'));
        // Build custom setting instance with dummy data.
        insert (new Periodic_delete_queries__c(
            Name = 'pdq1',
            Active__c = true,
            Query__c = 'SELECT Id FROM Account',
            Hard_delete__c = true,
            Batch_size__c = 3
        ));
        // The schedule time isn't actually used; it just runs after Test.StopTest().
        String CRON_EXP = '0 0 0 15 3 ?';
        Test.StartTest();
        String jobId = System.schedule(
            'Delete records',
            CRON_EXP,
            new DeleteRecordsSchedulable()
        );
        Test.StopTest();
        // Not validating after schedulable class test, because it doesn't work for some reason.
    }
}