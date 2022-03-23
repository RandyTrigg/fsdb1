@isTest
public class TouchRecordsSchedulableTest {
    static testMethod void TouchRecordsSchedulableTest() {
        // Build custom setting instance with dummy data.
        insert (new Classification__c(Name = 'test class'));
        insert (new Periodic_touch_queries__c(
            Name = 'ptq1',
            Active__c = true,
            Query__c = 'select Id from Classification__c',
            Batch_size__c = 1
        ));
        // The schedule time isn't actually used; it just runs after Test.StopTest().
        String CRON_EXP = '0 0 0 15 3 ?';
        Test.StartTest();
        String jobId = System.schedule(
            'Touch records',
            CRON_EXP,
            new TouchRecordsSchedulable()
        );
        Test.StopTest();
    }
}