@isTest
public class UpdateAccountContactInfoTest {
    static testMethod void UpdateAccountContactInfoTest1() {
        // Build data records
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'Test account',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'),
            Website = 'www.abc.org'
        );
        Account acc = [SELECT Id, Contact_primary__c FROM Account LIMIT 1];
        insert new Address__c(
            Account__c = acc.Id,
            Street__c = 'test street',
            City__c = 'test city'
        );
        insert new Contact(
            AccountId = acc.Id,
            LastName = 'Primary contact name',
            Rank__c = 1,
            RecordTypeId = Utilities.getRecTypeId('Contact', 'Contact_GM')
        );
        Id ctId = [SELECT Id FROM Contact LIMIT 1].Id;
        acc.Contact_primary__c = ctId;
        update acc;

        Test.StartTest();
        UpdateAccountContactInfo.UpdateAccountContactInfo(
            new List<Id>{ acc.Id }
        );
        acc = [
            SELECT Id, Name, Contact_info_GM__c
            FROM Account
            WHERE Id = :acc.Id
        ];
        system.assertEquals('Test account', acc.Name);
        // Run same request again in order to cover more code
        UpdateAccountContactInfo.UpdateAccountContactInfo(
            new List<Id>{ acc.Id }
        );
        Test.StopTest();
    }
}