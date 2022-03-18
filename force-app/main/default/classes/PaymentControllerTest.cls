@isTest
public class PaymentControllerTest {
    static testMethod void PaymentControllerTest1() {
        // Build new payments, proposals and accounts
        BuildTestProposals.InitTestObjects(1, 1);

        Test.StartTest();
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        // Push the proposal to award stage, and force creation of milestone.
        prop.Date_awarded__c = Date.today();
        update prop;
        MilestoneController.buildMilestones(prop.Id);
        Test.StopTest();

        insert new Payment__c(
            Proposal__c = prop.Id,
            Date_paid__c = Date.today()
        );
        buildLettersFUTURE(); // Build letters in future method to avoid too-many-soql errors in production.
        // NOTE: Uncomment validation call for testing in sandbox!  Commented out when deploying to production to avoid governor limits.
        /* 
Map<Id, Letter__c> lMap = new Map<Id, Letter__c> ([SELECT Id FROM Letter__c]);
validate(lMap.keySet());
*/
    }

    @future
    static void buildLettersFUTURE() {
        Map<Id, Payment__c> pMap = new Map<Id, Payment__c>(
            [SELECT Id FROM Payment__c]
        );
        // Build new standard set controller and select the new payments.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            pMap.values()
        );
        ssc.setSelected(pMap.values());
        // Build a new payment controller and use it to build new letters for the selected payments.
        insert (new Template__c(
            Name = 'Test template',
            Source_object__c = 'Payment__c'
        ));
        PaymentController pc = new PaymentController(ssc);
        pc.selectedTemplate = 'Test template';
        system.assertNotEquals(
            Utilities.recordIdFromName('Template__c', pc.selectedTemplate),
            null
        );
        pc.buildLetters();
        // For code coverage, run again with standard controller and no selected template (forcing error).
        ApexPages.StandardController sc = new ApexPages.StandardController(
            pMap.values()[0]
        );
        pc = new PaymentController(sc);
        pc.selectedTemplate = null;
        pc.buildLetters();
    }

    static void validate(Set<ID> lIds) {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [
                SELECT Account__c, Emails__c, Payment__c
                FROM Letter__c
                WHERE Id IN :lIds
            ]
        );
        Map<Id, Payment__c> pMap = new Map<Id, Payment__c>(
            [
                SELECT Id
                FROM Payment__c
                WHERE Id IN (SELECT Payment__c FROM Letter__c WHERE Id IN :lIds)
            ]
        );
        // Should be a different letter for each proposal.
        system.assertEquals(lMap.size(), pMap.size());
        // Gather email addresses for contacts under the accounts.
        Map<Id, Account> aMap = new Map<Id, Account>([SELECT Id FROM Account]);
        Map<Id, List<String>> emailMap = Utilities.emailsForAccounts(
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

    // Test update of existing report milestone
    static testMethod void PaymentControllerTest2() {
        // Build template and macros for proposal status
        ProposalUpdateTest.buildTemplateMacros();
        // Build proposals and accounts
        BuildTestProposals.InitTestObjects(1, 1);
        insert new Custom_Reqs__c(Name = 'test reporting reqs');
        Id repReqsId = [SELECT Id FROM Custom_Reqs__c LIMIT 1].Id;
        insert new Milestone_Spec__c(
            Custom_Reqs__c = repReqsId,
            Date_due__c = Date.today().addDays(50),
            Fraction_of_amount_awarded__c = 1,
            Type__c = 'Payment'
        );
        insert new Milestone_Spec__c(
            Custom_Reqs__c = repReqsId,
            Date_due__c = Date.today().addDays(100),
            Type__c = 'Report'
        );

        Test.StartTest();
        Proposal__c prop = [
            SELECT Id, Current_payment_milestone__c
            FROM Proposal__c
            LIMIT 1
        ];
        // Push the proposal to award stage, and force creation of milestones.
        prop.Amount_awarded__c = 100;
        prop.Custom_reqs__c = repReqsId;
        update prop;
        // Have to update date awarded separately because of a validation rule on changes to amount/date awarded fields.
        prop.Date_awarded__c = Date.today();
        update prop;
        MilestoneController.buildMilestones(prop.Id);
        Test.StopTest();

        prop = [
            SELECT Id, Current_payment_milestone__c
            FROM Proposal__c
            LIMIT 1
        ];
        // Build payment.
        insert new Payment__c(
            Proposal__c = prop.Id,
            Date_paid__c = Date.today(),
            Amount_paid__c = 100,
            Milestone__c = prop.Current_payment_milestone__c
        );
        Payment__c payment = [
            SELECT Id, Milestone__c, Date_paid__c
            FROM Payment__c
            LIMIT 1
        ];
        ProposalUpdate.updateProposal(prop.Id, true); // Update prop status

        List<Milestone__c> ms = [
            SELECT Id, Date_of_first_payment_actual__c
            FROM Milestone__c
            ORDER BY Date_due__c
        ];
        system.assertEquals(2, ms.size());
        system.assertEquals(ms[0].Id, payment.Milestone__c);
        system.assertEquals(
            ms[0].Date_of_first_payment_actual__c,
            payment.Date_paid__c
        );
    }
}