@isTest
public with sharing class AccountControllerTest {
    static testMethod void AccountControllerTest1() {
        // Build new proposals and accounts
        BuildTestProposals.InitTestObjects(2, 2);
        // Build a dev account with a contact.
        insert new Account(
            Name = 'test dev account',
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization')
        );
        Account acc1 = [
            SELECT Id
            FROM Account
            WHERE Name = 'test dev account'
            LIMIT 1
        ];
        insert new Contact(
            LastName = 'test last name',
            AccountId = acc1.Id,
            Rank__c = 1,
            Email = 'abc1@def.org',
            Email2__c = 'abc1@def.org',
            RecordTypeId = Utilities.getRecTypeId('Contact', 'Contact_Dev')
        );
        Map<Id, Account> aMap = new Map<Id, Account>([SELECT Id FROM Account]);
        // Build new standard set controller and select the new accounts.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            aMap.values()
        );
        ssc.setSelected(aMap.values());

        Test.StartTest();
        // Build a new controller and use it to build new letters for the selected accounts.
        insert (new Template__c(
            Name = 'Test template',
            Source_object__c = 'Account'
        ));
        AccountController ac = new AccountController(ssc);
        ac.selectedTemplate = 'Test template';
        system.assertNotEquals(
            Utilities.recordIdFromName('Template__c', ac.selectedTemplate),
            null
        );
        ac.buildLetters();
        Test.StopTest();

        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Id FROM Letter__c]
        );
        validate(lMap.keySet());
    }

    static void validate(Set<ID> lIds) {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Account__c, Emails__c FROM Letter__c WHERE Id IN :lIds]
        );
        system.debug('validate: lMap = ' + JSON.serialize(lMap));
        // Gather accounts and their contacts' email addresses.
        Map<Id, Account> aMap = new Map<Id, Account>(
            [
                SELECT Id
                FROM Account
                WHERE Id IN (SELECT Account__c FROM Letter__c WHERE Id IN :lIds)
            ]
        );
        system.debug('validate: aMap = ' + JSON.serialize(aMap));
        // Should be a different letter for each account.
        system.assertEquals(lMap.size(), aMap.size());
        Map<Id, List<String>> emailMap = AccountController.emailsForAccounts(
            aMap.keySet()
        );
        system.debug('validate: emailMap = ' + JSON.serialize(emailMap));
        // The emails stored on the letter need to agree with the account's emails.
        for (Letter__c l : lMap.values()) {
            system.assertEquals(
                l.Emails__c,
                Utilities.stringJoinWithCharLimit(emailMap.get(l.Account__c), ',', 255)
            );
        }
    }

    // Test the update contact info code.
    static testMethod void AccountControllerTest4() {
        // Build records.
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'acc test',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Address__c(
            Account__c = acc.Id,
            IsActive__c = true,
            Street__c = 'aaa'
        );
        insert new Contact(
            AccountId = acc.Id,
            LastName = 'Test contact',
            Rank__c = 1,
            Email = 'testing@applicant.org',
            RecordTypeId = Utilities.getRecTypeId('Contact', 'Contact_GM')
        );

        Test.startTest();
        AccountUpdateContactInfoInvocable.updateContactInfo(
            new List<Id>{ acc.Id }
        );
        Test.stopTest();
    }
}