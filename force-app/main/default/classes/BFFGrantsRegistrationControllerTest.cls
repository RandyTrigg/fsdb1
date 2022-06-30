@isTest
public with sharing class BFFGrantsRegistrationControllerTest {
    
    static testmethod void RegistrationTest () {
        // Create test records
        String accountRecordTypeId = Schema.Sobjecttype.Account.RecordTypeInfosByName.get('Organization GM').RecordTypeId;
        Account a = new Account(
            Name='BFF Community Users Account',
            RecordTypeId = accountRecordTypeId
            );
        insert a;

        Contact c = new Contact (
                LastName = 'Testing',
                AccountId = a.Id,
                Email = 'xxx@gmail.com'
            );
        insert c;
        
        ID profileId = [SELECT Id, Name from Profile WHERE Name = 'BFF Basic Community Login User' LIMIT 1].Id;
        User u = new User();
        u.ProfileId = profileId;
        u.LastName = 'Testing';
        u.Email = 'xxx@gmail.com';
        u.Username = 'bff-xxx@gmail.com';
        u.EmailEncodingKey = 'UTF-8';
        u.LocaleSidKey = 'en_US';
        u.LanguageLocaleKey = 'en_US';
        u.TimeZoneSidKey = 'GMT';
        u.Alias = 'xxx';
        u.ContactId = c.Id;
        u.CommunityNickname = 'xxx'; 

        System.debug('u: '+u);
        insert u;

        Test.StartTest();

        Map<String,String> registrant = new Map<String,String>();
        registrant.put('email', 'xxx@gmail.com');
        registrant.put('groupName', 'TestGroup');
        registrant.put('language', 'French');
        
        String errorDupeVal = SiteController.handleRegistration(JSON.serialize(registrant));
        registrant.put('email', 'yyy@gmail.com');
        String noErr = SiteController.handleRegistration(JSON.serialize(registrant));
        System.assertEquals('DuplicateUsername', errorDupeVal);
        System.assertEquals('', noErr);
        Test.stopTest();
    }
}