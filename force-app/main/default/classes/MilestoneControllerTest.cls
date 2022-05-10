@isTest
public class MilestoneControllerTest {
    /**********************************
     * Test the component-related methods
     * *******************************/

    static testMethod void MilestoneControllerTest1() {
        // Build new records
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'test account',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Review_Form__c(Name = 'test milestone review form');
        Review_Form__c rf = [SELECT Id FROM Review_Form__c LIMIT 1];
        insert new Review_Form__c(Name = 'ReportStandard_WF');
        insert new Review_Form_Component__c(
            Review_Form__c = rf.Id,
            Lightning_component_name__c = 'InputCheckbox',
            Sort_number__c = 1
        );
        insert new Custom_Reqs__c(Name = 'test custom reqs');
        Custom_Reqs__c cr = [SELECT Id FROM Custom_Reqs__c LIMIT 1];
        insert new Milestone_Spec__c(
            Custom_Reqs__c = cr.Id,
            Type__c = 'Report',
            Date_due__c = Date.today(),
            Review_form__c = rf.Id
        );
        Milestone_Spec__c ms = [SELECT Id FROM Milestone_Spec__c LIMIT 1];
        insert new Profile__c();
        Profile__c pr = [SELECT Id FROM Profile__c LIMIT 1];
        insert new Proposal__c(
            Account__c = a.Id,
            Profile__c = pr.Id,
            Custom_Reqs__c = cr.Id
        );
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Milestone__c(
            Proposal__c = p.Id,
            Type__c = 'Report',
            Milestone_Spec__c = ms.Id
        );
        Milestone__c m = [SELECT Id FROM Milestone__c LIMIT 1];
        Test.StartTest();
        MilestoneController.MilestoneInfo mInfo = MilestoneController.getMilestoneInfo(
            m.Id
        );
        GM_Data__c d = [SELECT Id FROM GM_Data__c WHERE Proposal__c = :p.Id];
        MilestoneController.saveMilestoneInfo(m, d);
        Test.StopTest();
    }

    /**********************************
     * Test the VF-related methods
     * *******************************/

    static testMethod void MilestoneControllerTest2a() {
        // Build new milestones, proposals and accounts
        InitTestObjects(1, 1);
        Map<Id, Milestone__c> mMap = new Map<Id, Milestone__c>(
            [SELECT Id FROM Milestone__c]
        );
        // Build new standard set controller and select the new records.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            mMap.values()
        );
        ssc.setSelected(mMap.values());

        Test.StartTest();
        // Build a new milestone controller and use it to build new letters for the selected milestones.
        insert (new Template__c(
            Name = 'Test template',
            Source_object__c = 'Milestone__c'
        ));
        MilestoneController gc = new MilestoneController(ssc);
        gc.selectedTemplate = 'Test template';
        system.assertNotEquals(
            Utilities.recordIdFromName('Template__c', gc.selectedTemplate),
            null
        );
        gc.buildLetters();
        Test.StopTest();

        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Id FROM Letter__c]
        );
        validate(lMap.keySet());
    }

    static testMethod void MilestoneControllerTest2b() {
        // Build new milestones, proposals and accounts
        InitTestObjects(1, 1);
        Map<Id, Milestone__c> mMap = new Map<Id, Milestone__c>(
            [SELECT Id FROM Milestone__c]
        );
        // Build new standard controller and select the new record.
        ApexPages.StandardController sc = new ApexPages.StandardController(
            mMap.values()[0]
        );

        Test.StartTest();
        // Build a new milestone controller and use it to build new letters for the selected milestones.
        insert (new Template__c(
            Name = 'Test template',
            Source_object__c = 'Milestone__c'
        ));
        MilestoneController gc = new MilestoneController(sc);
        gc.selectedTemplate = 'Test template';
        system.assertNotEquals(
            Utilities.recordIdFromName('Template__c', gc.selectedTemplate),
            null
        );
        gc.buildLetters();
        Test.StopTest();

        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Id FROM Letter__c]
        );
        validate(lMap.keySet());
    }

    static testMethod void MilestoneControllerTest3() {
        // Build 1 new milestone/proposal/account
        InitTestObjects(1, 1);
        Milestone__c m = [SELECT Id FROM Milestone__c LIMIT 1];
        Test.StartTest();
        String templateName = 'Test template';
        insert (new Template__c(
            Name = templateName,
            Source_object__c = 'Milestone__c'
        ));
        Template__c template = [
            SELECT Id
            FROM Template__c
            WHERE Name = :templateName
            LIMIT 1
        ];
        // Use invocable class to build and email letter.
        MilestoneEmailLetterInvocable.EmailLetterRequest req = new MilestoneEmailLetterInvocable.EmailLetterRequest();
        req.mId = m.Id;
        req.templateId = template.Id;
        MilestoneEmailLetterInvocable.buildAndEmailLetter(
            new List<MilestoneEmailLetterInvocable.EmailLetterRequest>{ req }
        );
        Test.StopTest();
    }

    static testMethod void MilestoneControllerTest4() {
        // Build 1 new milestone/proposal/account
        InitTestObjects(1, 1);
        Milestone__c m = [SELECT Id FROM Milestone__c LIMIT 1];
        Test.StartTest();
        insert (new Template__c(
            Name = 'Milestone reminder letter',
            Source_object__c = 'Milestone__c'
        ));
        Template__c t = [SELECT Id FROM Template__c LIMIT 1];
        insert new Letter__c(
            Milestone__c = m.Id,
            Template__c = t.Id,
            Date_emailed__c = Date.today()
        );
        Letter__c l = [SELECT Id FROM Letter__c LIMIT 1];
        // Use invocable class to run the letter sent actions.
        MilestoneLetterSentInvocable.MilestoneLetterSentRequest req = new MilestoneLetterSentInvocable.MilestoneLetterSentRequest();
        req.letterId = l.Id;
        // Test each of four letter templates.
        MilestoneLetterSentInvocable.letterSent(
            new List<MilestoneLetterSentInvocable.MilestoneLetterSentRequest>{
                req
            }
        );
        m = [
            SELECT Id, Num_overdue_notices_sent__c, Num_reminders_sent__c
            FROM Milestone__c
            LIMIT 1
        ];
        system.assertEquals(1, m.Num_reminders_sent__c);
        t.Name = 'Milestone overdue letter';
        update t;
        MilestoneLetterSentInvocable.letterSent(
            new List<MilestoneLetterSentInvocable.MilestoneLetterSentRequest>{
                req
            }
        );
        m = [
            SELECT Id, Num_overdue_notices_sent__c, Num_reminders_sent__c
            FROM Milestone__c
            LIMIT 1
        ];
        system.assertEquals(1, m.Num_overdue_notices_sent__c);
        t.Name = 'Milestone acknowledgement letter';
        update t;
        MilestoneLetterSentInvocable.letterSent(
            new List<MilestoneLetterSentInvocable.MilestoneLetterSentRequest>{
                req
            }
        );
        t.Name = 'Milestone follow up letter';
        update t;
        MilestoneLetterSentInvocable.letterSent(
            new List<MilestoneLetterSentInvocable.MilestoneLetterSentRequest>{
                req
            }
        );
        Test.StopTest();
    }

    static void validate(Set<ID> lIds) {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [
                SELECT Account__c, Emails__c, Milestone__c
                FROM Letter__c
                WHERE Id IN :lIds
            ]
        );
        Map<Id, Milestone__c> mMap = new Map<Id, Milestone__c>(
            [
                SELECT Id
                FROM Milestone__c
                WHERE
                    Id IN (SELECT Milestone__c FROM Letter__c WHERE Id IN :lIds)
            ]
        );
        // Should be a different letter for each proposal.
        system.assertEquals(lMap.size(), mMap.size());
        // Gather email addresses for contacts under the accounts.
        Map<Id, Account> aMap = new Map<Id, Account>([SELECT Id FROM Account]);
        Map<Id, List<String>> emailMap = AccountController.emailsForAccounts(
            aMap.keySet()
        );
        // The emails stored on the letter need to agree with the account's emails.
        for (Letter__c l : lMap.values()) {
            system.assertEquals(
                l.Emails__c,
                String.join(emailMap.get(l.Account__c), ',')
            );
        }
    }

    static void InitTestObjects(
        Integer NumberOfGranteeReports,
        Integer NumberOfAccounts
    ) {
        // Build proposals and accounts
        BuildTestProposals.InitTestObjects(
            NumberOfGranteeReports,
            NumberOfAccounts
        );
        List<Proposal__c> ps = new List<Proposal__c>(
            [SELECT Id, Account__c FROM Proposal__c]
        );
        // Build and insert milestones linked to the new proposals.
        List<Milestone__c> ms = new List<Milestone__c>();
        for (Integer x = 0; x < NumberOfGranteeReports; x++) {
            ms.add(
                new Milestone__c(
                    Proposal__c = ps[x].Id
                    // Add other field assignments for milestones
                )
            );
        }
        insert ms;
    }

    // Test code to build new milestones for awarded proposals.
    static testMethod void MilestoneControllerTest5() {
        // Build new proposals, accounts, milestone specs.
        BuildTestProposals.InitTestObjects(1, 1);
        insert new Custom_Reqs__c(Name = 'test reporting reqs');
        Custom_Reqs__c custReqs = [SELECT Id FROM Custom_Reqs__c LIMIT 1];
        insert new Milestone_Spec__c(
            Custom_Reqs__c = custReqs.Id,
            Date_due__c = Date.today().addDays(100),
            Type__c = 'Report'
        );
        insert new Milestone_Spec__c(
            Custom_Reqs__c = custReqs.Id,
            Num_months_due__c = 12,
            Type__c = 'Report'
        );
        // Push the proposal to award stage.
        Proposal__c p = [SELECT Id, Account__c FROM Proposal__c LIMIT 1];
        p.Amount_awarded__c = 100;
        p.Custom_Reqs__c = custReqs.Id;
        update p;
        // Have to update date awarded separately because of a validation rule on changes to amount/date awarded fields.
        p.Date_awarded__c = Date.today();
        update p;

        Test.StartTest();
        // Insert a report milestone.
        insert new Milestone__c(Proposal__c = p.Id, Type__c = 'Report');
        Milestone__c m1 = [SELECT Id FROM Milestone__c LIMIT 1];
        MilestoneController.buildMilestones(p.Id);
        Test.StopTest();

        // Insert a new milestone.  Because it isn't linked to a milestone spec, date due is not updated.
        Milestone__c[] ms = [SELECT Id, Date_due__c FROM Milestone__c];
        for (Milestone__c m : ms) {
            system.assertEquals(null, m.Date_due__c);
        }
    }
}