@isTest
public class InviteControllerTest {
    public static Id organizationRtId = Utilities.getRecTypeId(
        'Account',
        'Organization_GM'
    );
    public static Id fundRtId = Utilities.getRecTypeId('Fund__c', 'Standard');
    static testMethod void InviteControllerTest1() {
        // Build new records.
        Id userId = UserInfo.getUserId();
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'invtest_acct_1',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'),
            GM_email__c = 'abc@def.org'
        );
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Fund__c(
            Name = 'test fund',
            Amount_funded__c = 100,
            Active__c = true,
            RecordTypeId = fundRtId
        );
        Fund__c fund = [SELECT Id FROM Fund__c LIMIT 1];
        insert new Allocation__c(
            Fund__c = fund.Id,
            Grant_size__c = 10,
            Num_grants__c = 1,
            Staff_responsible__c = userId
        );
        Allocation__c alloc = [SELECT Id FROM Allocation__c LIMIT 1];
        insert new Invite__c(Account__c = acc.Id, Allocation__c = alloc.Id);
        Map<Id, Invite__c> invMap = new Map<Id, Invite__c>(
            [SELECT Id FROM Invite__c]
        );
        // Build new standard set controller and select the new invite.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            invMap.values()
        );
        ssc.setSelected(invMap.values());

        Test.StartTest();
        // Build a new invite controller and use it to build new letters for the selected invites.
        insert (new Template__c(
            Name = 'Test template',
            Source_object__c = 'Invite__c'
        ));
        InviteController ic1 = new InviteController(ssc);
        ic1.selectedTemplate = 'Test template';
        system.assertNotEquals(
            Utilities.recordIdFromName('Template__c', ic1.selectedTemplate),
            null
        );
        ic1.buildLetters();
        // These last bits are for code coverage.
        ApexPages.StandardController sc = new ApexPages.StandardController(
            invMap.values()[0]
        );
        InviteController ic2 = new InviteController(sc);
        ic2.buildLetters();
        ic2.selectedTemplate = 'Test template';
        ic2.buildLetters();
        ic2.doCancel();
        Test.StopTest();

        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Id FROM Letter__c]
        );
        validate(lMap.keySet());
    }

    static void validate(Set<ID> lIds) {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [
                SELECT Account__c, Emails__c, Invite__c
                FROM Letter__c
                WHERE Id IN :lIds
            ]
        );
        Map<Id, Invite__c> invMap = new Map<Id, Invite__c>(
            [
                SELECT Id
                FROM Invite__c
                WHERE Id IN (SELECT Invite__c FROM Letter__c WHERE Id IN :lIds)
            ]
        );
        system.debug(
            'InviteController validate: lMap = ' + JSON.serialize(lMap)
        );
        system.assertNotEquals(invMap.size(), lMap.size());
        // Gather email addresses for the accounts of these invites.
        Map<Id, Account> aMap = new Map<Id, Account>(
            [
                SELECT Id
                FROM Account
                WHERE
                    Id IN (
                        SELECT Account__c
                        FROM Invite__c
                        WHERE Id IN :invMap.keySet()
                    )
            ]
        );
        Map<Id, List<String>> emailMap = AccountController.emailsForAccounts(
            aMap.keySet()
        );
        system.debug(
            'InviteController validate: emailMap = ' + JSON.serialize(emailMap)
        );
        // The emails stored on the letter need to agree with the account's emails.
        for (Letter__c l : lMap.values()) {
            system.assertEquals(
                l.Emails__c,
                String.join(emailMap.get(l.Account__c), ',')
            );
        }
    }

    // Test functionality to build new invites/allocations for charges on a fund.
    static testMethod void InviteControllerTest2() {
        // Build new records.
        Id userId = UserInfo.getUserId();
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'invtest_acct_1',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'),
            GM_email__c = 'abc@def.org'
        );
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Fund__c(
            Name = 'test fund',
            Amount_funded__c = 100,
            Active__c = true,
            RecordTypeId = fundRtId
        );
        Fund__c fund = [SELECT Id FROM Fund__c LIMIT 1];
        insert new Proposal__c(
            Account__c = acc.Id,
            Amount_awarded__c = 50,
            Date_awarded__c = Date.today()
        );
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Charge__c(Fund__c = fund.Id, Proposal__c = prop.Id);

        Test.startTest();
        InvitesAllocationsForRstInvocable.NewInvsAllocsRequest req = new InvitesAllocationsForRstInvocable.NewInvsAllocsRequest();
        req.fundId = fund.Id;
        InvitesAllocationsForRstInvocable.newInvitesAllocations(
            new List<InvitesAllocationsForRstInvocable.NewInvsAllocsRequest>{
                req
            }
        );
        Test.stopTest();

        Allocation__c[] allocs = [SELECT Id FROM Allocation__c];
        Invite__c[] invs = [SELECT Id, Allocation__c FROM Invite__c];
        system.assert(allocs.size() > 0);
        system.assert(invs.size() > 0);
        system.assertEquals(allocs[0].Id, invs[0].Allocation__c);
    }

    // Test functionality to build new invites/allocations for charged proposals.
    static testMethod void InviteControllerTest3() {
        // Build new records.
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'invtest_acct_1',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'),
            GM_email__c = 'abc@def.org'
        );
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Fund__c(
            Name = 'test fund',
            Amount_funded__c = 100,
            Active__c = true,
            RecordTypeId = fundRtId
        );
        Fund__c fund = [SELECT Id FROM Fund__c LIMIT 1];
        insert new Proposal__c(
            Account__c = acc.Id,
            Amount_awarded__c = 50,
            Date_awarded__c = Date.today()
        );
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Charge__c(
            Fund__c = fund.Id,
            Proposal__c = prop.Id,
            Amount_charged__c = 20
        );
        Charge__c c1 = [
            SELECT Id
            FROM Charge__c
            WHERE Amount_charged__c = 20
            LIMIT 1
        ];
        insert new Charge__c(
            Fund__c = fund.Id,
            Proposal__c = prop.Id,
            Amount_charged__c = 30
        );
        Charge__c c2 = [
            SELECT Id
            FROM Charge__c
            WHERE Amount_charged__c = 30
            LIMIT 1
        ];

        Test.startTest();
        // First ensure that we skip props with split charges.
        InviteController.newAllocationsInvitesForProps(new Set<Id>{ prop.Id });
        Invite__c[] invs = [SELECT Id FROM Invite__c];
        system.assertEquals(0, invs.size());
        // Now delete the charge and test again via the batch process.
        delete c2;
        Database.executeBatch(
            new InvitesAllocationsForPropsBatch('SELECT Id FROM Proposal__c'),
            5
        );
        Test.stopTest();

        Allocation__c[] allocs = [SELECT Id FROM Allocation__c];
        invs = [SELECT Id, Allocation__c FROM Invite__c];
        system.assert(allocs.size() > 0);
        system.assert(invs.size() > 0);
        system.assertEquals(allocs[0].Id, invs[0].Allocation__c);
    }

    // Test the cloneProposal method.
    static testMethod void InviteControllerTest4() {
        // Build new records.
        Id userId = UserInfo.getUserId();
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'invtest_acct_1',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'),
            GM_email__c = 'abc@def.org'
        );
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Proposal__c(
            Account__c = acc.Id,
            Amount_awarded__c = 50,
            Date_awarded__c = Date.today()
        );
        Proposal__c p = [SELECT Id, Account__c FROM Proposal__c LIMIT 1];
        insert new Fund__c(
            Name = 'test fund',
            Amount_funded__c = 100,
            Active__c = true,
            RecordTypeId = fundRtId
        );
        Fund__c fund = [SELECT Id FROM Fund__c LIMIT 1];
        insert new Allocation__c(
            Fund__c = fund.Id,
            Grant_size__c = 10,
            Num_grants__c = 1,
            Staff_responsible__c = userId
        );
        Allocation__c alloc = [SELECT Id FROM Allocation__c LIMIT 1];
        insert new Invite__c(
            Account__c = acc.Id,
            Allocation__c = alloc.Id,
            Proposal_to_clone__c = p.Id
        );
        Invite__c i = [SELECT Id FROM Invite__c LIMIT 1];

        Test.StartTest();
        InviteCloneProposalInvocable.cloneProposal(new List<Id>{ i.Id });
        Test.StopTest();

        Proposal__c pNew = [
            SELECT Id, Account__c, Amount_awarded__c
            FROM Proposal__c
            WHERE Prior_proposal__c != null
            LIMIT 1
        ];
        system.assertNotEquals(p.Id, pNew.Id);
        system.assertEquals(p.Account__c, pNew.Account__c);
        system.assertEquals(null, pNew.Amount_awarded__c);
        GM_Data__c[] gmds = [SELECT Id FROM GM_Data__c];
        system.assertEquals(2, gmds.size());
    }

    // Test the aura enabled method for creating new proposal from invite.
    static testMethod void InviteControllerTest5() {
        // Build new records.
        Id userId = UserInfo.getUserId();
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'invtest_acct_1',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'),
            GM_email__c = 'abc@def.org'
        );
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Profile__c(Account__c = acc.Id, Language__c = 'English');
        Profile__c prof = [SELECT Id FROM Profile__c LIMIT 1];
        insert new Fund__c(
            Name = 'test fund',
            Amount_funded__c = 100,
            Active__c = true,
            RecordTypeId = fundRtId
        );
        Fund__c fund = [SELECT Id FROM Fund__c LIMIT 1];
        insert new Allocation__c(
            Fund__c = fund.Id,
            Grant_size__c = 10,
            Num_grants__c = 1,
            Staff_responsible__c = userId
        );
        Allocation__c alloc = [SELECT Id FROM Allocation__c LIMIT 1];
        insert new Invite__c(
            Account__c = acc.Id,
            Profile__c = prof.Id,
            Allocation__c = alloc.Id
        );
        Invite__c i = [SELECT Id FROM Invite__c LIMIT 1];

        Test.StartTest();
        String jsonString = JSON.serialize(
            new Map<String, Object>{
                'inviteId' => i.Id,
                'invitationDeadline' => Date.today().addDays(100),
                'awardNotificationDeadline' => Date.today().addDays(200)
            }
        );
        String returnJSON = InviteController.newProposal(jsonString);
        Test.StopTest();

        // Check that records were created, and that they're inter-linked.
        Proposal__c prop = [
            SELECT Id, GM_Data__c, Invite__c
            FROM Proposal__c
            LIMIT 1
        ];
        GM_Data__c gmd = [SELECT Id, Proposal__c FROM GM_Data__c LIMIT 1];
        i = [SELECT Id, Proposal__c FROM Invite__c LIMIT 1];
        system.assertNotEquals(null, prop);
        system.assertNotEquals(null, gmd);
        system.assertEquals(prop.Id, i.Proposal__c);
        system.assertEquals(prop.Id, gmd.Proposal__c);
        system.assertEquals(gmd.Id, prop.GM_Data__c);
        system.assertEquals(i.Id, prop.Invite__c);
    }
}