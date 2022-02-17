@isTest
public class GenericUpdateRecordsBatchTest {
    static testMethod void GenericUpdateRecordsBatchTest() {
        // Build new records
        insert new Account(Name = 'Test 1');
        insert new Account(Name = 'Test 2');
        Account[] accs1 = [SELECT Id FROM Account WHERE Name = 'Test 1'];
        Account[] accs2 = [SELECT Id FROM Account WHERE Name = 'Test 2'];

        Test.StartTest();
        accs1[0].Description = 'la la';
        accs2[0].Description = 'ta ta';
        Database.executeBatch(new GenericUpdateRecordsBatch(accs1), 5);
        Database.executeBatch(
            new GenericUpdateRecordsBatch(accs1, accs2, 3),
            5
        );
        Test.StopTest();

        accs1 = [SELECT Id, Description FROM Account WHERE Name = 'Test 1'];
        system.assertEquals('la la', accs1[0].Description);
        accs2 = [SELECT Id, Description FROM Account WHERE Name = 'Test 2'];
        system.assertEquals('ta ta', accs2[0].Description);
    }
}