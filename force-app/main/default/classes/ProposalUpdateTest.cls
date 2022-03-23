@isTest
public with sharing class ProposalUpdateTest {
    // Test simple statuses - part 1
    static testMethod void ProposalUpdateTest1a() {
        buildTemplateMacros();
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'test account',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Proposal__c(Account__c = a.Id);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];

        Test.StartTest();
        // Basic pending status
        ProposalUpdate.updateProposal(p.Id, true);
        p = [SELECT Status_numeric__c FROM Proposal__c WHERE Id = :p.Id];
        system.assertEquals(1, p.Status_numeric__c);
        // Statuses governed by single date fields.
        p.Date_declined__c = Date.today();
        update p;
        ProposalUpdate.updateProposal(p.Id, true);
        p = [SELECT Status_numeric__c FROM Proposal__c WHERE Id = :p.Id];
        system.assertEquals(0, p.Status_numeric__c);
        p.Date_declined__c = null;
        p.Date_request_withdrawn__c = Date.today();
        update p;
        ProposalUpdate.updateProposal(p.Id, true);
        p = [SELECT Status_numeric__c FROM Proposal__c WHERE Id = :p.Id];
        system.assertEquals(0.5, p.Status_numeric__c);
        p.Date_request_withdrawn__c = null;
        p.Date_reminder_sent__c = Date.today();
        update p;
        ProposalUpdate.updateProposal(p.Id, true);
        p = [SELECT Status_numeric__c FROM Proposal__c WHERE Id = :p.Id];
        system.assertEquals(1.15, p.Status_numeric__c);
        Test.StopTest();
    }
    // Test simple statuses - part 2
    static testMethod void ProposalUpdateTest1b() {
        buildTemplateMacros();
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'test account',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Proposal__c(Account__c = a.Id);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];

        Test.StartTest();
        p.Date_received__c = Date.today();
        update p;
        ProposalUpdate.updateProposal(p.Id, true);
        p = [SELECT Status_numeric__c FROM Proposal__c WHERE Id = :p.Id];
        system.assertEquals(1.5, p.Status_numeric__c);
        p.Date_received__c = null;
        p.Date_review_completed__c = Date.today();
        update p;
        ProposalUpdate.updateProposal(p.Id, true);
        p = [SELECT Status_numeric__c FROM Proposal__c WHERE Id = :p.Id];
        system.assertEquals(2, p.Status_numeric__c);
        p.Date_review_completed__c = null;
        p.Date_held__c = Date.today();
        update p;
        ProposalUpdate.updateProposal(p.Id, true);
        p = [SELECT Status_numeric__c FROM Proposal__c WHERE Id = :p.Id];
        system.assertEquals(2.1, p.Status_numeric__c);
        // One extra call for coverage - because it's not passing allowRecursiveCall flag, updateProposal will bail.
        ProposalUpdate.updateProposal(p.Id);
        Test.StopTest();
    }

    // Test simple statuses - part 3
    static testMethod void ProposalUpdateTest1c() {
        buildTemplateMacros();
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'test account',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Proposal__c(Account__c = a.Id);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];

        Test.StartTest();
        // Basic pending status
        ProposalUpdate.updateProposal(p.Id, true);
        // Statuses governed by single date fields.
        p.Date_awarded__c = Date.today();
        update p;
        ProposalUpdate.updateProposal(p.Id, true);
        p.Date_award_withdrawn__c = Date.today();
        update p;
        ProposalUpdate.updateProposal(p.Id, true);
        p.Date_award_withdrawn__c = null;
        p.Date_completed__c = Date.today();
        update p;
        ProposalUpdate.updateProposal(p.Id, true);
        p.Date_completed__c = null;
        p.Date_closed_incomplete__c = Date.today();
        update p;
        ProposalUpdate.updateProposal(p.Id, true);
        Test.StopTest();
    }

    static testMethod void ProposalUpdateTest2() {
        buildTemplateMacros();
        InitTestObjectsPre();
        Account a = [
            SELECT Id
            FROM Account
            WHERE Name = 'test account'
            LIMIT 1
        ];
        Profile__c pr = [SELECT Id FROM Profile__c LIMIT 1];
        insert new Proposal__c(
            Account__c = a.Id,
            Profile__c = pr.Id,
            Date_awarded__c = Date.today(),
            Amount_awarded__c = 10,
            Date_closed_incomplete__c = Date.today().addDays(100)
        );
        Proposal__c p = [
            SELECT Id, Account__c, Next_milestone_due__c
            FROM Proposal__c
            LIMIT 1
        ];

        Test.StartTest();
        InitTestObjectsPost(p); // Build and link an invite for more coverage
        ProposalUpdate.updateProposal(p.Id, true);
        // Invocable class doesn't run when testing - calling for code coverage.
        ProposalUpdateInvocable.updateProposal(new List<Id>{ p.Id });
        Test.StopTest();
    }

    static testMethod void ProposalUpdateTest3() {
        buildTemplateMacros();
        InitTestObjectsPre();
        Account a = [
            SELECT Id
            FROM Account
            WHERE Name = 'test account'
            LIMIT 1
        ];
        Profile__c prof = [SELECT Id FROM Profile__c LIMIT 1];

        Test.StartTest();
        insert new Proposal__c(
            Account__c = a.Id,
            Profile__c = prof.Id,
            Date_approved_for_contract__c = Date.today().addDays(-18),
            Date_OFAC_checked__c = Date.today().addDays(-19),
            Date_awarded__c = Date.today().addDays(-30),
            Amount_awarded__c = 10
        );
        Proposal__c p = [
            SELECT Id, Account__c, Status__c
            FROM Proposal__c
            LIMIT 1
        ];
        MilestoneController.buildMilestones(p.Id); // Build milestones.

        ProposalUpdate.updateProposal(p.Id, true);
        Test.StopTest();
    }

    static testMethod void ProposalUpdateTest4() {
        buildTemplateMacros();
        InitTestObjectsPre();
        Account a = [
            SELECT Id
            FROM Account
            WHERE Name = 'test account'
            LIMIT 1
        ];
        Profile__c prof = [SELECT Id FROM Profile__c LIMIT 1];
        prof.Account__c = null; // Clear account field so that updateProposal will update (code coverage).
        update prof;
        insert new Custom_Reqs__c(Name = 'test reporting reqs');
        Id repReqsId = [SELECT Id FROM Custom_Reqs__c LIMIT 1].Id;
        String milestoneSpecType = Utilities.picklistValues(
            'Milestone_Spec__c',
            'Type__c'
        )[0];
        insert new Milestone_Spec__c(
            Custom_Reqs__c = repReqsId,
            Fraction_of_amount_awarded__c = .5,
            Date_due__c = Date.today().addDays(100),
            Type__c = milestoneSpecType
        );
        insert new Milestone_Spec__c(
            Custom_Reqs__c = repReqsId,
            Fraction_of_amount_awarded__c = .5,
            Date_due__c = Date.today().addDays(200),
            Type__c = milestoneSpecType
        );

        insert new Proposal__c(
            Account__c = a.Id,
            Profile__c = prof.Id,
            Date_approved_for_contract__c = Date.today().addDays(-18),
            Date_OFAC_checked__c = Date.today().addDays(-19),
            Date_pre_contract_docs_recd__c = Date.today().addDays(-20),
            Date_awarded__c = Date.today().addDays(-30),
            Amount_awarded__c = 10,
            Date_award_ack_submitted__c = Date.today().addDays(-20),
            Custom_Reqs__c = repReqsId
        );
        Proposal__c p = [SELECT Id, Account__c FROM Proposal__c LIMIT 1];

        Test.StartTest();
        MilestoneController.buildMilestones(p.Id); // Build milestones.
        Test.StopTest(); // Stop test here to force batch process to complete updating payment.

        ProposalUpdate.updateProposal(p.Id, true);
    }

    static void InitTestObjectsPre() {
        // Build records
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'test account',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Account(
            Name = 'test account 1',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account a1 = [
            SELECT Id
            FROM Account
            WHERE Name = 'test account 1'
            LIMIT 1
        ];
        // Ensure that profile's account clashes with proposal's account (for code coverage).
        insert new Profile__c(Account__c = a1.Id);
    }

    static void InitTestObjectsPost(Proposal__c p) {
        insert new Fund__c(
            Name = 'test fund',
            Amount_funded__c = 100,
            Active__c = true,
            RecordTypeId = Utilities.getRecTypeId('Fund__c', 'Standard')
        );
        Fund__c fund = [
            SELECT Id
            FROM Fund__c
            WHERE Name = 'test fund'
            LIMIT 1
        ];
        Id userId = UserInfo.getUserId();
        insert new Allocation__c(
            Fund__c = fund.Id,
            Grant_size__c = 10,
            Num_grants__c = 1,
            Staff_responsible__c = userId
        );
        Allocation__c alloc = [SELECT Id FROM Allocation__c LIMIT 1];
        insert new Invite__c(
            Proposal__c = p.Id,
            Account__c = p.Account__c,
            Allocation__c = alloc.Id
        );
    }

    /**********************************
     * TEMPLATE MACROS FOR PROPOSAL STATUS CALCULATIONS
     *********************************/
    public static void buildTemplateMacros() {
        insert new Template__c(
            Name = 'Proposal status',
            Type__c = 'Grantmaking'
        );
        Template__c t = [SELECT Id FROM Template__c LIMIT 1];
        insert new Template_Macro__c(
            Name = 'STATUS STAGE',
            Template__c = t.Id,
            Macro_text__c = '' +
                '// Compute status stage based on the numeric value of the computed status.\n' +
                'CASEFM(' +
                '[[STATUS NUMERIC]] < 1, "00 - Declined/withdrawn", ' +
                '[[STATUS NUMERIC]] < 1.5, "01 - Pending", ' +
                '[[STATUS NUMERIC]] < 5, "02 - Under review", ' +
                '[[STATUS NUMERIC]] < 6, "03 - Pending approval/award", ' +
                '[[STATUS NUMERIC]] < 6.6, "04 - Award/contracting", ' +
                '[[STATUS NUMERIC]] == 7.15 || [[STATUS NUMERIC]] == 7.5, "05 - Payment problems/delays", ' +
                '[[STATUS NUMERIC]] <= 7.09, "06 - Payment pending", ' +
                '[[STATUS NUMERIC]] <= 8.1, "07 - Paid", ' +
                '[[STATUS NUMERIC]] < 8.5, "08 - Milestone review", ' +
                '[[STATUS NUMERIC]] < 10, "09 - Closing", ' +
                '"10 - Closed/withdrawn"' +
                ')'
        );
        insert new Template_Macro__c(
            Name = 'STATUS NUMERIC',
            Template__c = t.Id,
            Macro_text__c = '' +
                '// Grab the numeric part of the computed status, the part before the first space.\n' +
                'VALUE(LEFT([[STATUS]], FIND([[STATUS]], " ") - 1))'
        );
        insert new Template_Macro__c(
            Name = 'STATUS',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/**********************************' +
                '* Overall status calculations (0 - 10.3)' +
                '* First check the 0 and 10 cases, and then check sub-statuses in order from highest to lowest.' +
                '*********************************/' +
                'CASEFM(' +
                'NOT(ISBLANK(Date_declined__c)), "0 - decline", ' +
                'NOT(ISBLANK(Date_request_withdrawn__c)), "0.5 - request withdrawn", ' +
                'NOT(ISBLANK([[STATUS CLOSING]])), [[STATUS CLOSING]], ' +
                'NOT(ISBLANK([[STATUS MILESTONE]])), [[STATUS MILESTONE]], ' +
                'NOT(ISBLANK([[STATUS PAYMENT]])), [[STATUS PAYMENT]], ' +
                'NOT(ISBLANK([[STATUS CONTRACT]])), [[STATUS CONTRACT]], ' +
                '[[STATUS UNDER REVIEW]]' +
                ')'
        );
        insert new Template_Macro__c(
            Name = 'STATUS UNDER REVIEW',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/**********************************' +
                '* Status calculations for Under Review (1 - 5.5)' +
                '*********************************/' +
                'CASEFM(' +
                'NOT(ISBLANK(Date_approved_for_award__c)) && ' +
                'To_be_charged__c == 0, ' +
                '"5.5 - UR/Finance/VP approved", ' +
                'ISBLANK([[STATUS 5 ISSUES]]) && ' +
                'Amount_awarded__c > 0 && ' +
                'To_be_charged__c == 0 && ' +
                'NOT(ISBLANK(Date_ready_for_award_approval__c)), ' +
                '"5.4 - UR/Ready for VP approval", ' +
                'ISBLANK([[STATUS 5 ISSUES]]) && ' +
                'Amount_awarded__c > 0 && ' +
                'To_be_charged__c == 0, ' +
                '"5.1 - UR/Charges assigned", ' +
                'ISBLANK([[STATUS 5 ISSUES]]), ' +
                '"5 - UR/Proposal recommended for approval", ' +
                'NOT(ISBLANK(Date_approved_for_award__c)) && ' +
                'Amount_awarded__c > 0, ' +
                '"4.9 - UR/Grant pre-approved", ' +
                'Amount_recommended__c > 0 && ' +
                'NOT(ISBLANK(Date_review_completed__c)), ' +
                '"4 - UR/Proposal recommended for funding", ' +
                'NOT(ISBLANK(Decline_reason__c)) && ' +
                'NOT(ISBLANK(Date_review_completed__c)), ' +
                '"2.9 - UR/Proposal to decline", ' +
                'NOT(ISBLANK(Date_held__c)), ' +
                '"2.1 - UR/Proposal held", ' +
                'NOT(ISBLANK(Date_review_completed__c)), ' +
                '"2 - UR/Proposal review complete", ' +
                'NOT(ISBLANK(Date_received__c)), ' +
                '"1.5 - UR/Proposal submitted", ' +
                'Is_overdue__c && ' +
                'Date_overdue_letter_sent__c >= Proposal_submit_deadline__c, ' +
                '"1.17 - UR/Proposal overdue letter sent", ' +
                'Is_overdue__c, ' +
                '"1.16 - UR/Proposal overdue", ' +
                'NOT(ISBLANK(Date_reminder_sent__c)), ' +
                '"1.15 - UR/Proposal reminder sent", ' +
                '"1 - UR/Proposal pending" ' +
                ')'
        );
        insert new Template_Macro__c(
            Name = 'STATUS 5 ISSUES',
            Template__c = t.Id,
            Macro_text__c = '' +
                'TRIM( ' +
                ' IF(ISBLANK(Account__c.Highlights__c), "Purpose (in Account)", "") & BR() & ' +
                ' IF(ISBLANK(Amount_awarded__c), "Amount awarded", "") & BR() & ' +
                ' IF(ISBLANK(Amount_requested__c), "Amount requested", "") & BR() & ' +
                ' IF(ISBLANK(Description__c), "Description", "") & BR() & ' +
                ' IF(ISBLANK(Grant_type__c), "Grant type", "") & BR() & ' +
                ' IF(ISBLANK(Date_review_completed__c), "Date review completed", "") & BR() & ' +
                ' IF(ISBLANK(Staff_analysis__c), "Staff analysis", "") & BR() & ' +
                ' // NOTE: Related list of portfolios, Initiative_Assignments__r, is pre-filtered for priority portfolios.\n ' +
                ' IF(ISBLANK(Initiative_Assignments__r), "Priority portfolio", "") & BR() & ' +
                ' IF(Num_classifications__c == 0, "Classifications", "")' +
                ') '
        );
        insert new Template_Macro__c(
            Name = 'PAY DATE',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/********************************** ' +
                '* The payDate for a grant is the most recent of the payment\'s date paid and the payment method\'s date requested. ' +
                '*********************************/ ' +
                'CASEFM( ' +
                ' ISBLANK(Current_payment_method__c), ' +
                '    // Note that value is null (aka blank) if both dates are blank\n ' +
                '    IF(NOT(ISBLANK(Payment_recent__c)), Payment_recent__c.Date_paid__c, Payment_recent__c),  ' +
                ' ISBLANK(Payment_recent__c) || ISBLANK(Payment_recent__c.Date_paid__c), DATEVALUE(Current_payment_method__c.CreatedDate), ' +
                ' DATEVALUE(Current_payment_method__c.CreatedDate) > Payment_recent__c.Date_paid__c, DATEVALUE(Current_payment_method__c.CreatedDate), ' +
                ' Payment_recent__c.Date_paid__c ' +
                ') '
        );
        insert new Template_Macro__c(
            Name = 'PENDING PAYMENT METHOD',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/********************************** ' +
                '*  Current payment method is pending if its date requested is more recent than the payment\'s date paid. ' +
                '*********************************/ ' +
                'NOT(ISBLANK(Current_payment_method__c)) && ' +
                'NOT(ISBLANK(Current_payment_method__c.CreatedDate)) && ' +
                'DATEVALUE(Current_payment_method__c.CreatedDate) == [[PAY DATE]] '
        );
        insert new Template_Macro__c(
            Name = 'STATUS CONTRACT',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/********************************** ' +
                '* Status calculations for Contract (6 - 6.9) ' +
                '* Check higher statuses (CONTRACT 1) and then lower statuses (CONTRACT 2). ' +
                '*********************************/ ' +
                'CASEFM( ' +
                ' NOT(ISBLANK([[STATUS CONTRACT 1]])), [[STATUS CONTRACT 1]], ' +
                ' NOT(ISBLANK([[STATUS CONTRACT 2]])), [[STATUS CONTRACT 2]], ' +
                ' NOT(ISBLANK(Date_awarded__c)), "6 - G/board approved" ' +
                ') '
        );
        insert new Template_Macro__c(
            Name = 'STATUS CONTRACT 1',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/********************************** ' +
                '* Status calculations for Contract (6 - 6.9) ' +
                '* These higher contract statuses (6.4 - 6.9) all require CFO approval. ' +
                '*********************************/ ' +
                'IF (NOT(ISBLANK(Date_approved_for_contract__c)),  ' +
                ' CASEFM( ' +
                '  Date_contract_docs_recd__c >= Date_approved_for_contract__c && ' +
                '  NOT(ISBLANK(Payment_dependent_on_prior_grant__c)) && // This proposal is dependent on a prior grant\n ' +
                '  Payment_dependent_on_prior_grant__c.Status_numeric__c < 9.8, ' +
                '   "6.81 - G/payment held for prior grant report approval", ' +
                '  Date_payment_put_on_hold__c >= Date_approved_for_contract__c, ' +
                '   "6.8 - G/payment on hold by grantee request", ' +
                '  Date_contract_letter_sent__c >= Date_approved_for_contract__c && ' +
                '  Date_contract_docs_recd__c >= Date_approved_for_contract__c && ' +
                '  Date_OFAC_checked__c >= Date_contract_letter_sent__c && ' +
                '  Date_OFAC_checked__c >= Date_contract_docs_recd__c, ' +
                '   "6.7 - G/Ready to send to accounting", ' +
                '  Date_contract_letter_sent__c >= Date_approved_for_contract__c && ' +
                '  Date_contract_docs_recd__c >= Date_approved_for_contract__c, ' +
                '   "6.6 - G/contract documents received",  ' +
                '  Date_contract_letter_sent__c >= Date_approved_for_contract__c && ' +
                '  NOT(ISBLANK(Current_payment_method__c)) && ' +
                '  Current_payment_method__c.Date_FS_request_letter_sent__c >= Date_approved_for_contract__c && ' +
                '  Current_payment_method__c.Date_FS_agreement_letter_sent__c >= Date_approved_for_contract__c, ' +
                '   "6.56 - G/FS forms sent/UR", ' +
                '  Date_contract_letter_sent__c >= Date_approved_for_contract__c && ' +
                '  Date_partial_contract_docs_recd__c >= Date_approved_for_contract__c, ' +
                '   "6.55 - G/partial contract docs received/UR", ' +
                '  Date_contract_letter_sent__c >= Date_approved_for_contract__c, ' +
                '   "6.5 - G/contract docs sent / awaiting return", ' +
                '  NOT(ISBLANK(Date_awarded__c)) && ' +
                '  Date_OFAC_checked__c >= IF(NOT(ISBLANK(Date_pre_contract_docs_recd__c)), Date_pre_contract_docs_recd__c, Date_awarded__c) && ' +
                '  Date_OFAC_checked__c >= IF(NOT(ISBLANK(Date_award_ack_submitted__c)), Date_award_ack_submitted__c, Date_awarded__c), ' +
                '   "6.4 - G/CFO approved" ' +
                ' ), "" ' +
                ') '
        );
        insert new Template_Macro__c(
            Name = 'STATUS CONTRACT 2',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/********************************** ' +
                '* Status calculations for Contract (6 - 6.9) ' +
                '* These lower contract statuses (6.1 - 6.35) all require award date and OFAC checked date. ' +
                '*********************************/ ' +
                'IF(NOT(ISBLANK(Date_awarded__c)) && NOT(ISBLANK(Date_OFAC_checked__c)), ' +
                ' CASEFM( ' +
                '  NOT(ISBLANK (Date_pre_contract_docs_approved__c)), ' +
                '    "6.35 - G/OFAC checked for contract", ' +
                '  NOT(ISBLANK(Date_pre_contract_docs_recd__c)) ||  ' +
                '  ( ' +
                '   Date_pre_contract_docs_recd__c >= Date_grant_award_notification_sent__c ' +
                '  ), ' +
                '    "6.3 - G/Pre-contract response recd", ' +
                '  NOT(ISBLANK(Date_partial_pre_contract_docs_recd__c)) ||  ' +
                '  ( ' +
                '   Date_partial_pre_contract_docs_recd__c >= Date_grant_award_notification_sent__c ' +
                '  ), ' +
                '    "6.25 - G/partial pre contract docs received/UR", ' +
                '   NOT(ISBLANK(Date_grant_award_notification_sent__c)), ' +
                '    "6.2 - G/pre-contract or award notification sent", ' +
                '    "6.1 - G/OFAC checked pre-contract" ' +
                ' ), "" ' +
                ') '
        );
        insert new Template_Macro__c(
            Name = 'STATUS PAYMENT',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/********************************** ' +
                '* Aggregate status for Payment (7.1 - 8.1; 7.02 - 7.09) ' +
                '* Check first payment statuses (PAYMENT 1) and then subsequent payment statuses (PAYMENT 2). ' +
                '*********************************/ ' +
                'IF(NOT(ISBLANK([[STATUS PAYMENT 1]])), [[STATUS PAYMENT 1]], [[STATUS PAYMENT 2]]) '
        );
        insert new Template_Macro__c(
            Name = 'STATUS PAYMENT 1',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/********************************** ' +
                '* Status calculations for Payment (7.1 - 8.1; 7.02 - 7.09) ' +
                '* These statuses (7.1 - 8.1) are for first payments with date paid, which must be after payment method\'s date requested, if any. ' +
                '*********************************/ ' +
                'IF( ' +
                '  NOT(ISBLANK(Payment_recent__c)) && ' +
                '  NOT(ISBLANK(Payment_recent__c.Date_paid__c)) && ' +
                '  (ISBLANK(Current_payment_method__c) || Payment_recent__c.Date_paid__c >= DATEVALUE(Current_payment_method__c.CreatedDate)), ' +
                ' CASEFM( ' +
                '  NOT(ISBLANK(Payment_recent__c.Date_funds_receipt_ackd__c)), ' +
                '   "8.1 - G/payment recpt confirmed", ' +
                '  Payment_recent__c.Has_problem__c, ' +
                '   "7.5 - G/payment problem", ' +
                '  NOT(ISBLANK(Payment_recent__c.Date_payment_letter_sent__c)) && ' +
                '  ISBLANK(Payment_recent__c.Date_stalled__c), ' +
                '   "7.2 - G/payment letter sent", ' +
                '  NOT(ISBLANK(Payment_recent__c.Date_stalled__c)), ' +
                '   "7.15 - G/payment stalled", ' +
                '   "7.1 - G/payment sent" ' +
                ' ), "" ' +
                ') '
        );
        insert new Template_Macro__c(
            Name = 'STATUS PAYMENT 2',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/********************************** ' +
                '* Status calculations for Payment (7.1 - 8.1; 7.02 - 7.09) ' +
                '* These statuses (7.02 - 7.09) are for subsequent payments.  There must be a current payment method, which isn\'t the grant\'s first payment method. ' +
                '*********************************/ ' +
                'IF(NOT(ISBLANK(Current_payment_method__c)) && Current_payment_method__c != First_payment_method__c, ' +
                ' CASEFM( ' +
                '  NOT(ISBLANK(Current_payment_method__c.Date_ready_for_payment__c)) && ' +
                '  Current_payment_method__c.Date_ready_for_payment__c >= Current_payment_method__c.Date_ready_for_payment__c, ' +
                '   "7.09 - G/Subsequent payment sent to accounting", ' +
                '  NOT(ISBLANK(Current_payment_method__c.Date_ready_for_payment__c)) && ' +
                '  Current_payment_method__c.Date_docs_received__c >= Current_payment_method__c.Date_ready_for_payment__c && ' +
                '  // Note that we\'re checking against the proposal\'s "Date OFAC checked" field\n ' +
                '  Date_OFAC_checked__c >= Current_payment_method__c.Date_docs_received__c, ' +
                '   "7.07 - G/Subsequent payment ready to send to accounting", ' +
                '  NOT(ISBLANK(Current_payment_method__c.Date_ready_for_payment__c)) && ' +
                '  Current_payment_method__c.Date_docs_received__c >= Current_payment_method__c.Date_ready_for_payment__c, ' +
                '   "7.06 - G/Subsequent payment authorization documents received", ' +
                '  NOT(ISBLANK(Current_payment_method__c.Date_ready_for_payment__c)) && ' +
                '  ( ' +
                '   Current_payment_method__c.Date_FS_request_letter_sent__c >= Current_payment_method__c.Date_ready_for_payment__c ||  ' +
                '   Current_payment_method__c.Date_FS_agreement_letter_sent__c >= Current_payment_method__c.Date_ready_for_payment__c ' +
                '  ), ' +
                '   "7.056 - G/Subsequent payment FS forms sent", ' +
                '  NOT(ISBLANK(Current_payment_method__c.Date_ready_for_payment__c)) && ' +
                '  Current_payment_method__c.Date_partial_docs_received__c >= Current_payment_method__c.Date_ready_for_payment__c, ' +
                '   "7.055 - G/Subsequent payment authorization partial docs received", ' +
                '  NOT(ISBLANK(Current_payment_method__c.Date_ready_for_payment__c)), ' +
                '   "7.04 - G/Subsequent payment method verified/authorization needed", ' +
                '  NOT(ISBLANK(Current_payment_method__c.Date_submitted__c)) && ' +
                '  ( ' +
                '   ISBLANK(Current_payment_method__c.Date_clarification_requested__c) ||  ' +
                '   Current_payment_method__c.Date_submitted__c >= Current_payment_method__c.Date_clarification_requested__c ' +
                '  ), ' +
                '   "7.03 - G/Subsequent payment info received", ' +
                '  NOT(ISBLANK(Current_payment_method__c.Date_clarification_requested__c)), ' +
                '   "7.025 - G/Subsequent partial payment info received", ' +
                '  NOT(ISBLANK(Current_payment_method__c)), ' +
                '   "7.02 - G/Subsequent payment info requested" ' +
                ' ), "" ' +
                ') '
        );
        insert new Template_Macro__c(
            Name = 'STATUS MILESTONE',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/**********************************' +
                '* Status calculations for milestones (8.1 - 8.9)' +
                '* These statuses involve milestones either received (8.4 - 8.9) or due (8.1 - 8.3).' +
                '* If we\'re working on a subsequent payment method or there\'s a problem/stalled payment, then "drop down" into payment statuses.' +
                '*********************************/' +
                'IF(' +
                ' // If these conditions aren\'t true, then "drop down" into payment statuses.\n ' +
                ' NOT(ISBLANK([[PAY DATE]])) && ' +
                ' ![[PENDING PAYMENT METHOD]] &&' +
                ' NOT(ISBLANK(Payment_recent__c)) &&' +
                ' !Payment_recent__c.Has_problem__c &&' +
                ' ISBLANK(Payment_recent__c.Date_stalled__c),' +
                ' // Check lower statuses on the next milestone due (which has blank date received) that hasn\'t been manually approved,\n ' +
                ' // before checking higher statuses on the most recent milestone (which has non-blank date received).\n ' +
                ' IF(' +
                '  NOT(ISBLANK(Next_milestone_due__c)) &&  ' +
                '  ISBLANK(Next_milestone_due__c.Date_milestone_approved__c),' +
                ' CASEFM(' +
                '  Next_milestone_due__c.Is_overdue__c &&' +
                '  Next_milestone_due__c.Date_overdue_letter_sent__c >= [[PAY DATE]],' +
                '   "8.3 - G/milestone overdue letter sent (" & Next_milestone_due__c.Type__c & ")",' +
                '  Next_milestone_due__c.Is_overdue__c &&' +
                '  Next_milestone_due__c.Date_due__c >= [[PAY DATE]],' +
                '   "8.2 - G/milestone overdue (" & Next_milestone_due__c.Type__c & ")",' +
                '  Next_milestone_due__c.Date_reminder_sent__c >= [[PAY DATE]],' +
                '   "8.1 - G/milestone reminder sent (" & Next_milestone_due__c.Type__c & ")",' +
                '   ""' +
                ' ),' +
                ' // Now check higher statuses on earlier received milestone.\n ' +
                ' // If the milestone was received prior to the pay date, then drop into the 7.0x statuses.\n ' +
                ' IF(' +
                '  NOT(ISBLANK(Milestone_recent__c)) &&' +
                '  Milestone_recent__c.Date_completed__c >= [[PAY DATE]],' +
                ' CASEFM(' +
                '  NOT(ISBLANK(Milestone_recent__c.Date_milestone_approved__c)),' +
                '   "8.9 - G/milestone approved (" & Milestone_recent__c.Type__c & ")",' +
                '  NOT(ISBLANK(Milestone_recent__c.Date_follow_up_response_received__c)),' +
                '   "8.8 - G/milestone follow-up response recd (" & Milestone_recent__c.Type__c & ")",' +
                '  NOT(ISBLANK(Milestone_recent__c.Date_follow_up_letter_sent__c)),' +
                '   "8.7 - G/milestone follow-up sent (" & Milestone_recent__c.Type__c & ")",' +
                '  NOT(ISBLANK(Milestone_recent__c.Date_reviewed__c)),' +
                '   "8.6 - G/milestone reviewed (" & Milestone_recent__c.Type__c & ")",' +
                '  NOT(ISBLANK(Milestone_recent__c.Date_acknowledged__c)),' +
                '   "8.5 - G/milestone completed and acknowledged (" & Milestone_recent__c.Type__c & ")",' +
                '  NOT(ISBLANK(Milestone_recent__c.Date_completed__c)),' +
                '   "8.4 - G/milestone completed (" & Milestone_recent__c.Type__c & ")",' +
                '   ""' +
                '  ), ""' +
                ' )), ""' +
                ' )'
        );
        insert new Template_Macro__c(
            Name = 'STATUS CLOSING',
            Template__c = t.Id,
            Macro_text__c = '' +
                '/**********************************' +
                '* Status calculations for closing a grant (9.9, 10 - 10.3)' +
                '*********************************/' +
                'CASEFM(' +
                ' // Various ways to close a grant\n ' +
                ' NOT(ISBLANK(Date_award_withdrawn__c)), "10.3 - award withdrawn", ' +
                ' NOT(ISBLANK(Date_completed__c)), "10 - G/closed, complete", ' +
                ' NOT(ISBLANK(Date_closed_incomplete__c)), "10.1 - G/closed, incomplete", ' +
                '// Check conditions on the final milestone.\n ' +
                'IF(' +
                ' // If these conditions aren\'t true, then "drop down" into payment statuses.\n ' +
                ' NOT(ISBLANK([[PAY DATE]])) &&' +
                ' NOT(ISBLANK(Payment_recent__c)) &&' +
                ' !Payment_recent__c.Has_problem__c &&' +
                ' ISBLANK(Payment_recent__c.Date_stalled__c),' +
                ' IF(' +
                '  // Considerations for final milestone\n ' +
                '  ISBLANK(Next_milestone_due__c) &&' +
                '  NOT(ISBLANK(Milestone_recent__c)),' +
                ' CASEFM(' +
                '  NOT(ISBLANK(Milestone_recent__c.Date_accountability_verified__c)),' +
                '   "9.9 - G/final milestone accountability verified (" & Milestone_recent__c.Type__c & ")",' +
                '  ""' +
                ' ), ""' +
                '), ""' +
                '))'
        );
    }
}