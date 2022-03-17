@isTest
public class AdvisorControllerTest {
    public static Id organizationRtId = Utilities.getRecTypeId('Account', 'Organization');
    public static Id ctAdvRecTypeId = Utilities.getRecTypeId('Contact', 'Contact_GM_Advisor');
    public static Id orgGMRtId = Utilities.getRecTypeId('Account', 'Organization_GM');
    
    static testmethod void AdvisorControllerTest1 () {
        // Build new advisors and accounts
        InitTestObjects(2, 2);
        Map<Id, Advisor__c> advMap = new Map<Id, Advisor__c> ([SELECT Id FROM Advisor__c]);
        // Build new standard set controller and select the new advisors.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(advMap.values());
        ssc.setSelected(advMap.values());        
        
        Test.StartTest();
        // Test code to build advisor records.
        Country__c country = [SELECT Id, Region__r.Name FROM Country__c LIMIT 1];
        insert new Portfolio__c (Name = 'test portfolio', Type__c = 'Saved Set');
        Portfolio__c port = [SELECT Id FROM Portfolio__c LIMIT 1];
        String jsonString = JSON.serialize(new Map<String, Object> {
            'type' => 'Reference', 
            'firstName' => 'Josephine', 
            'lastName' => 'Sprat', 
            'email' => 'abc@def.org', 
            'countryId' => country.Id,
            'orgAffilName' => 'org1',
            'advisorTermRecordType' => 'Assessor',
            'advisorTermType' => 'Strategic',
            'advisorTermStartDate' => Date.today().addDays(-10),
            'portfolioId' => port.Id
        });
        String responseString = AdvisorController.buildAdvisorRecs(jsonString);
        system.debug('responseString = ' +responseString);
        Advisor_Term__c advt = [SELECT Id, Advisor__c FROM Advisor_Term__c WHERE Advisor__r.GM_org_affiliation__r.Name = 'org1' LIMIT 1];
        // Force type to be non-blank, as though we've successfully invited them to be a strategic advisor.
        advt.Date_term_begins__c = Date.today().addDays(-100);
        advt.Date_accepted__c = Date.today();
        advt.Type__c = 'Strategic'; 
        update advt;
        AdvisorUpdateLookupsInvocable.updateLookups(new List<Id> {advt.Advisor__c});
        Advisor__c adv = [SELECT Id, Current_assessor_term__c FROM Advisor__c WHERE Id = : advt.Advisor__c];
        system.assertEquals(advt.Id, adv.Current_assessor_term__c);
        // Build a new advisor controller and use it to build new letters for the selected advisors.
        Template__c temp = new Template__c (Name = 'Test template', Source_object__c = 'Advisor__c');
        insert temp;
        AdvisorController pc = new AdvisorController (ssc);
        pc.selectedTemplate = temp.Id;
        system.assertNotEquals(pc.selectedTemplate, null);
        pc.buildLetters();
        Test.StopTest();
        
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c> ([SELECT Id FROM Letter__c]);
        validate(lMap.keySet());
        // Check that build new records succeeded.
        Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(responseString);
        Map<string, Object> results = (Map<String, Object>)response.get('results');
        system.debug('results: ' +results);
        system.debug('errMsg: ' +response.get('errMsg'));
        System.assertEquals(true, response.get('isSuccess'));
    }
    
    public static void validate(Set<ID> lIds) {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c> ([
            SELECT Account__c, Emails__c, Advisor__c
            FROM Letter__c
            WHERE Id IN : lIds
        ]);
        Map<Id, Advisor__c> advMap = new Map<Id, Advisor__c> ([
            SELECT Id
            FROM Advisor__c
            WHERE Id IN (SELECT Advisor__c FROM Letter__c WHERE Id IN : lIds)
        ]);
        // Should be a different letter for each advisor.
        system.assertEquals(lMap.size(), advMap.size());
        // Gather email addresses for contacts under accounts of these advisors. 
        Map<Id, Account> aMap = new Map<Id, Account> ([
            SELECT (SELECT Email FROM Contacts)
            FROM Account
            WHERE Id IN (SELECT Account__c FROM Advisor__c WHERE Id IN : advMap.keySet())
        ]);
        system.debug('validate: lMap = ' +JSON.serialize(lMap));
        system.debug('validate: aMap = ' +JSON.serialize(aMap));
        // The emails stored on the letter need to agree with the account's emails.
        for (Letter__c l : lMap.values()) {
            List<String> emails = new List<String> ();
            for (Contact c : aMap.get(l.Account__c).Contacts) emails.add(c.Email);
            system.assertEquals(String.join(emails, ','), l.Emails__c);
        }
    }
    // Prepare the specified number of advisors and accounts.  Include one contact per account.
    // The advisors are distributed evenly among the number of accounts specified.
    public static void InitTestObjects(Integer NumberOfAdvisors, Integer NumberOfAccounts)
    {
 		List<Account>accts = new List<Account>();
        Id acctAdvRecTypeId = Utilities.getRecTypeId('Account', 'Household_GM_Advisor');
		for(Integer x=0;x<NumberOfAccounts;x++) {      
			accts.add(new Account(
                Name = 'advtest_acct_' + String.valueOf(x),
                RecordTypeId = acctAdvRecTypeId
            ));
		}
		insert accts;
        system.debug('InitTestObjects: accts = ' +JSON.serialize(accts));
        // Use record type filter in SOQL call to ensure that we're not picking up random accounts from non-advisor InitTestObjects calls.
		List<Account> accounts = new List<Account> ([SELECT Id, Name FROM Account WHERE RecordTypeId = : acctAdvRecTypeId]);

		List<Contact>cts = new List<Contact>();
		for(Integer x=0;x<NumberOfAccounts;x++) {      
			cts.add(new Contact(
				LastName = 'ptest_' + String.valueOf(x),
				AccountId = accounts[x].Id,
                Email = 'ptest_' + String.valueOf(x) + '@ptest.org',
                AQB__OtherEmail__c = 'ptest_' + String.valueOf(x) + '@ptest.org',
                AQB__EmailPreference__c = 'Other Email',
                RecordTypeId = ctAdvRecTypeId,
                Rank__c = 1
				));
		}
		insert cts;
        // Use record type filter in SOQL call to ensure that we're not picking up random contacts from non-advisor InitTestObjects calls.
		List<Contact> contacts = new List<Contact> ([SELECT AccountId, LastName, RecordType.Name FROM Contact WHERE RecordTypeId = : ctAdvRecTypeId]);
        system.debug('InitTestObjects: contacts = ' +JSON.serialize(contacts));

		// Build and insert advisors linked to appropriate accounts.  
		List<Advisor__c> advs = new List<Advisor__c>();    
		Integer acctnumber = 0;
		for(Integer x=0; x<NumberOfAdvisors; x++) {      
			advs.add(new Advisor__c(
				Account__c = contacts[acctnumber].AccountId
                , Contact__c = contacts[acctnumber].Id
                , Name = 'Test advisor ' + x
                , Global__c = true
                // Add other field assignments for advisors
				));
			acctnumber++;
			if(acctnumber >= NumberOfAccounts) acctnumber = 0;	
		}
        insert advs;
        system.debug('InitTestObjects: advs = ' +JSON.serialize(advs));
        // Build an advisor term for each advisor.
		List<Advisor_Term__c> advTs = new List<Advisor_Term__c>();    
		for(Advisor__c adv : advs) {      
			advTs.add(new Advisor_Term__c(
                Advisor__c = adv.Id,
                RecordTypeId = Utilities.getRecTypeId('Advisor_Term__c', 'Assessor'),
                Date_term_begins__c = Date.today().addDays(-100),
                Type__c = 'Reference'
				));
		}
        system.debug('InitTestObjects: advTs = ' +JSON.serialize(advTs));
        insert advTs;
        // Build a country record.
        Region__c reg = new Region__c (Name = 'test region');
        insert reg;
        insert new Country__c (Name = 'test country', Region__c = reg.Id);
    }

    static testmethod void AdvisorControllerTest2 () {
        // Build new advisors and accounts
        InitTestObjects(2, 2);
        Advisor__c[] advs = [SELECT Id FROM Advisor__c];
        
        Test.StartTest();
        // Code coverage for advisorsFromAccount method.
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Advisor__c[] advs1 = AdvisorController.advisorsFromAccount(acc.Id);
        system.assertEquals(1, advs1.size());
        String profPerms = AdvisorController.fetchProfileAndPermissionSets();
        // Test code to add advisor to a community.
        Country__c country = [SELECT Id, Region__r.Name FROM Country__c LIMIT 1];
        insert new Account (
            Name = AdvisorController.communityAccountName, 
            GM_country__c = country.Id,
            RecordTypeId = orgGMRtId
            );
        Account acc1 = [SELECT Id, Name FROM Account WHERE Name = : AdvisorController.communityAccountName LIMIT 1];
        String jsonString = JSON.serialize(new Map<String, Object> {
            'advisorId' => advs[0].Id
        });
        String responseString = AdvisorController.addAdvisorToCommunity(jsonString);
        system.debug('responseString = ' +responseString);
        Test.StopTest();
        
        Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(responseString);
        Map<string, Object> results = (Map<String, Object>)response.get('results');
        String userName;
        if (results.get('userName') != null) userName = (String)results.get('userName');
        List<String> errors = (List<String>)results.get('errors');
        system.debug('AdvisorControllerTest2: userName = ' +userName+ '; errors = ' +JSON.serialize(errors));
        system.assertNotEquals(null, userName);
        User u = [SELECT Username, ProfileId, ContactId FROM User WHERE Username = : userName];
        Id pIdAdv = [SELECT Id FROM Profile WHERE Name = : AdvisorController.advisorCommunityProfileName LIMIT 1].Id;
        system.assertEquals(pIdAdv, u.ProfileId);
        Contact c = [SELECT Id, AccountId FROM Contact WHERE Id = : u.ContactId];
        system.assertEquals(acc1.Id, c.AccountId);
        Advisor__c adv = [SELECT Id, Community_contact__c FROM Advisor__c WHERE Id = : advs[0].Id];
        system.assertEquals(u.ContactId, adv.Community_contact__c);
    }
    
    static testmethod void AdvisorControllerTest3 () {
        UserRole r = [SELECT ID FROM UserRole WHERE Name='Top Level'];
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        thisUser.UserRoleId = r.Id;
        update thisUser;

        // System.runAs avoids the Mixed DML Operations error.  (Can't update setup object like User in same context as non-setup object.)
        System.runAs(thisUser) {
            // Build new advisors and accounts
            InitTestObjects(1, 1);
            Advisor__c adv = [SELECT Id, Contact__c, Contact__r.LastName, Contact__r.FirstName, Contact__r.Email FROM Advisor__c][0];
            String email = adv.Contact__r.Email;
            Id pIdAdv = [SELECT Id FROM Profile WHERE Name = : AdvisorController.advisorCommunityProfileName LIMIT 1].Id;
            Country__c country = [SELECT Id, Region__r.Name FROM Country__c LIMIT 1];
            insert new Account (
                Name = AdvisorController.communityAccountName, 
                GM_country__c = country.Id,
                RecordTypeId = orgGMRtId
                );
            Account acc = [SELECT Id, Name FROM Account WHERE Name = : AdvisorController.communityAccountName LIMIT 1];
            insert new Contact (AccountId = acc.Id, LastName = 'test contact');
            Contact c = [SELECT Id FROM Contact WHERE LastName = 'test contact' LIMIT 1];
            
            // Pre-build user record with advisor's email (to force exception to be thrown).
            insert new User(
                Username = AdvisorController.advisorUsernameFromEmail(email),
                Email = email,
                CommunityNickname = email.left(40),
                LastName = adv.Contact__r.LastName != null ? adv.Contact__r.LastName.left(40) : null,
                FirstName = adv.Contact__r.FirstName != null ? adv.Contact__r.FirstName.left(40) : null,
                Alias = email.toLowerCase().left(4),
                ProfileId = pIdAdv,
                ContactId = c.Id,
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'GMT'
            );
            User u = [
                SELECT Id, Username, Email, CommunityNickname, LastName, FirstName, Alias, 
                ProfileId, ContactId, EmailEncodingKey, LanguageLocaleKey, LocaleSidKey, TimeZoneSidKey
                FROM User 
                WHERE Email = : email 
                LIMIT 1
            ];
            
            Test.StartTest();
            String profPerms = AdvisorController.fetchProfileAndPermissionSets();
            // Assign permission set for code coverage.
            Id psIdAdv = [SELECT Id FROM PermissionSet WHERE Label = : AdvisorController.advisorCommunityPermSetName LIMIT 1].Id;
            AdvisorController.assignPermissionSet(u.Id, psIdAdv);
            // Test code to add advisor to a community.
            String jsonString = JSON.serialize(new Map<String, Object> {
                'advisorId' => adv.Id
                    });
            String responseString = AdvisorController.addAdvisorToCommunity(jsonString);
            system.debug('responseString = ' +responseString);
            Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(responseString);
            Map<string, Object> results = (Map<String, Object>)response.get('results');
            String userName;
            if (results.get('userName') != null) userName = (String)results.get('userName');
            // Expect to get an error as that username is already in the advisor community.
            system.assertEquals(null, userName);
            system.assert(!(Boolean)response.get('isSuccess'));
            system.assert(((String)response.get('errMsg')).contains('Advisor contact username'));
            
            // Try again where the clash is with a user without a linked contact (for code coverage).
            User uNew = u.clone(false, true);
            String emailNew = 'dontuser@abc.org';
            u.Username = AdvisorController.advisorUsernameFromEmail(emailNew); // Tweak username on original user to avoid conflict.
            u.Email = emailNew;
            u.CommunityNickname = emailNew.left(40);
            update u;
            uNew.ProfileId = [SELECT Id FROM Profile WHERE Name = : AdvisorController.standardUserGMProfileName LIMIT 1].Id;
            uNew.ContactId = null;
            insert uNew;
            responseString = AdvisorController.addAdvisorToCommunity(jsonString);
            
            Test.StopTest();
        }
    }

    @IsTest
    static void getRunningUserAdvisorIdTest(){
        //Setup test data
        UserRole r = [SELECT ID FROM UserRole WHERE Name='Top Level'];
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        thisUser.UserRoleId = r.Id;
        update thisUser;

        // System.runAs avoids the Mixed DML Operations error.  (Can't update setup object like User in same context as non-setup object.)
        System.runAs(thisUser) {
            // Build new advisors and accounts
            InitTestObjects(1, 1);
            Advisor__c adv = [SELECT Id, Contact__c, Contact__r.LastName, Contact__r.FirstName, Contact__r.Email FROM Advisor__c][0];
            String email = adv.Contact__r.Email;
            Id pIdAdv = [SELECT Id FROM Profile WHERE Name = : AdvisorController.advisorCommunityProfileName LIMIT 1].Id;
            Country__c country = [SELECT Id, Region__r.Name FROM Country__c LIMIT 1];
            insert new Account (
                Name = AdvisorController.communityAccountName, 
                GM_country__c = country.Id,
                RecordTypeId = orgGMRtId
                );
            Account acc = [SELECT Id, Name FROM Account WHERE Name = : AdvisorController.communityAccountName LIMIT 1];
            insert new Contact (AccountId = acc.Id, LastName = 'test contact');
            Contact c = [SELECT Id FROM Contact WHERE LastName = 'test contact' LIMIT 1];
            
            // Pre-build user record with advisor's email (to force exception to be thrown).
            insert new User(
                Username = AdvisorController.advisorUsernameFromEmail(email),
                Email = email,
                CommunityNickname = email.left(40),
                LastName = adv.Contact__r.LastName != null ? adv.Contact__r.LastName.left(40) : null,
                FirstName = adv.Contact__r.FirstName != null ? adv.Contact__r.FirstName.left(40) : null,
                Alias = email.toLowerCase().left(4),
                ProfileId = pIdAdv,
                ContactId = c.Id,
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'GMT'
            );
            User u = [
                SELECT Id, Username, Email, CommunityNickname, LastName, FirstName, Alias, 
                ProfileId, ContactId, EmailEncodingKey, LanguageLocaleKey, LocaleSidKey, TimeZoneSidKey
                FROM User 
                WHERE Email = : email 
                LIMIT 1
            ];
            //Done with test data setup
        }
        Test.startTest();
        String advisorId;
        System.runAs(thisUser){
            advisorId = AdvisorController.getRunningUserAdvisorId();
            System.debug('advisorId: '+advisorId);
        }
        Test.stopTest();

        //load the advisor record
        Advisor__c advisor = [SELECT Id, Contact__c, Contact__r.LastName, Contact__r.FirstName, Contact__r.Email FROM Advisor__c][0];
        System.assertEquals(advisor.Id, advisorId);
        
    }
    
}