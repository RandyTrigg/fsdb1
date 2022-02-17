@isTest
public class OFACLookupTest {
    static testMethod void OFACLookupTest() {
        // Set mock callout class and build custom settings.
        Test.setMock(HttpCalloutMock.class, new OFACLookupMock());
        buildCustomSettings();
        // Build data records
        insert new Region__c(Name = 'East Africa');
        Id regionId = [SELECT Id FROM Region__c LIMIT 1].Id;
        insert new Country__c(Name = 'Zimbabwe', Region__c = regionId);
        Id countryId = [SELECT Id FROM Country__c LIMIT 1].Id;
        // Two accounts, one grantee and one fiscal sponsor, each with a contact.
        insert new Account(
            Name = 'Test account',
            GM_Country__c = countryId,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Id accId1 = [SELECT Id FROM Account LIMIT 1].Id;
        insert new Account(
            Name = 'Test fiscal sponsor account',
            GM_Country__c = countryId,
            // Record type Organization_GM_FS is currently (10/8/20) hidden for FFDB
            RecordTypeId = Utilities.getRecTypeId(
                'Account',
                'Organization_GM' // 'Organization_GM_FS'
            )
        );
        Id accId2 = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test fiscal sponsor account'
            LIMIT 1
        ]
        .Id;
        insert new Contact(
            LastName = 'Doe',
            FirstName = 'John',
            Rank__c = 1,
            Email = 'abc1@def.org',
            AccountId = accId1,
            RecordTypeId = Utilities.getRecTypeId('Contact', 'Contact_GM')
        );
        insert new Contact(
            LastName = 'Doe',
            FirstName = 'John',
            Rank__c = 1,
            Email = 'abc2@def.org',
            AccountId = accId2,
            RecordTypeId = Utilities.getRecTypeId('Contact', 'Contact_GM')
        );
        // Build proposal under the grantee account.
        insert new Proposal__c(Account__c = accId1);
        Id propId = [SELECT Id FROM Proposal__c LIMIT 1].Id;
        // Build a payment method linked to a fiscal sponsor
        insert new Payment_Method__c(
            Proposal__c = propId,
            Account__c = accId1,
            Fiscal_sponsor__c = accId2
        );

        Test.StartTest();
        //String results = OFACLookup.OFACLookupInStatusRange();
        String results = OFACLookup.lookupProposals(new Set<Id>{ propId });
        system.debug('OFACLookupTest: results = ' + results);
        system.assert(results != null);
        system.assert(results.contains('(FS)')); // The results should include an FS hit.
        OFACLookup.OFACLookupNotificationEmail(results);
        Test.StopTest();
    }

    // Build custom setting instance with dummy data for OFAC search.
    public static void buildCustomSettings() {
        insert (new OFAC_search_SDN__c(
            Name = 'OFACSearchSDN',
            Base_URL__c = 'http://search.ofac-api.com/api/v1',
            API_key__c = '2f74fbc7-78c3-4ccd-8b1f-34b3ced7cc84-yJEXM',
            Min_score__c = 100,
            Recipient_email__c = 'abc@def.org'
        ));
    }
}