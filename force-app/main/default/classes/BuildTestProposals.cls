public with sharing class BuildTestProposals {
    // Grab account record type Ids.
    public static Id householdRtId = Utilities.getRecTypeId(
        'Account',
        'Household'
    );
    public static Id organizationRtId = Utilities.getRecTypeId(
        'Account',
        'Organization_GM'
    );

    // Prepare the specified number of proposals and accounts.  Include one contact per account.
    // The proposals are distributed evenly among the number of accounts specified.
    public static void InitTestObjects(
        Integer NumberOfProposals,
        Integer NumberOfAccounts
    ) {
        insert new Region__c(Name = 'test region');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Country__c(Name = 'test country', Region__c = reg.Id);
        Country__c cnt = [SELECT Id FROM Country__c LIMIT 1];
        List<Account> accts = new List<Account>();
        for (Integer x = 0; x < NumberOfAccounts; x++) {
            accts.add(
                new Account(
                    Name = 'ptest_acct_' + String.valueOf(x),
                    GM_Country__c = cnt.Id,
                    GM_email__c = 'ptestAcct' +
                        String.valueOf(x) +
                        '@ptest.org',
                    RecordTypeId = organizationRtId
                )
            );
        }
        insert accts;
        List<Account> accounts = new List<Account>(
            [SELECT Id, Name FROM Account]
        );

        List<Contact> cts = new List<Contact>();
        for (Integer x = 0; x < NumberOfAccounts; x++) {
            cts.add(
                new Contact(
                    LastName = 'ptest_' + String.valueOf(x),
                    AccountId = accounts[x].Id,
                    Rank__c = 1,
                    Email = 'ptest_' + String.valueOf(x) + '@ptest.org',
                    Email2__c = 'ptest_' + String.valueOf(x) + '@ptest.org',
                    RecordTypeId = Utilities.getRecTypeId('Contact', 'Contact_GM')
                )
            );
        }
        insert cts;
        List<Contact> contacts = new List<Contact>(
            [SELECT AccountId, LastName FROM Contact]
        );

        // Build and insert proposals linked to appropriate accounts.
        List<Proposal__c> ps = new List<Proposal__c>();
        Integer acctnumber = 0;
        for (Integer x = 0; x < NumberOfProposals; x++) {
            ps.add(
                new Proposal__c(
                    Account__c = accounts[acctnumber].Id,
                    Description__c = 'Description: ' + x
                    // Add other field assignments for proposals
                )
            );
            acctnumber++;
            if (acctnumber >= NumberOfAccounts)
                acctnumber = 0;
        }
        insert ps;
    }
}