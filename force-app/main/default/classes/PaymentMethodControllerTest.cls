@isTest
public class PaymentMethodControllerTest {
    static testMethod void PaymentMethodControllerTest1a() {
        // Build new payment methods, proposals and accounts
        InitTestObjects(1, 1);
        // Build new standard set controller and select the new payment methods.
        Map<Id, Payment_Method__c> pMap = new Map<Id, Payment_Method__c>(
            [SELECT Id FROM Payment_Method__c]
        );
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            pMap.values()
        );
        ssc.setSelected(pMap.values());

        Test.StartTest();
        // Build a new controller and use it to build new letters for the selected payment methods.
        insert (new Template__c(
            Name = 'Test template',
            Source_object__c = 'Payment_Method__c'
        ));
        PaymentMethodController pc = new PaymentMethodController(ssc);
        pc.selectedTemplate = 'Test template';
        system.assertNotEquals(
            Utilities.recordIdFromName('Template__c', pc.selectedTemplate),
            null
        );
        pc.buildLetters();
        Test.StopTest();

        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Id FROM Letter__c]
        );
        validate(lMap.keySet());
    }

    static void validate(Set<ID> lIds) {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [
                SELECT Account__c, Account__r.Name, Emails__c, Payment_Method__c
                FROM Letter__c
                WHERE Id IN :lIds
            ]
        );
        Map<Id, Payment_Method__c> pMap = new Map<Id, Payment_Method__c>(
            [
                SELECT Id
                FROM Payment_Method__c
                WHERE
                    Id IN (
                        SELECT Payment_Method__c
                        FROM Letter__c
                        WHERE Id IN :lIds
                    )
            ]
        );
        // Should be a different letter for each payment method.
        system.assertEquals(lMap.size(), pMap.size());
        // Gather email addresses for contacts under the accounts.
        Map<Id, Account> aMap = new Map<Id, Account>([SELECT Id FROM Account]);
        Map<Id, List<String>> emailMap = Utilities.emailsForAccounts(
            aMap.keySet()
        );
        // The emails stored on the letter need to agree with the account's emails.
        for (Letter__c l : lMap.values()) {
            system.debug(
                'loop in validate: l.Account__r.Name= ' +
                l.Account__r.Name +
                '; l.Emails__c = ' +
                JSON.serialize(l.Emails__c)
            );
            system.assertEquals(
                l.Emails__c,
                String.join(emailMap.get(l.Account__c), ',')
            );
        }
    }

    static void InitTestObjects(
        Integer NumberOfPaymentMethods,
        Integer NumberOfAccounts
    ) {
        // Build proposals and accounts
        BuildTestProposals.InitTestObjects(
            NumberOfPaymentMethods,
            NumberOfAccounts
        );
        List<Proposal__c> ps = new List<Proposal__c>(
            [SELECT Id, Account__c FROM Proposal__c]
        );
        // Build and insert payment methods linked to the new proposals.
        List<Payment_Method__c> pas = new List<Payment_Method__c>();
        for (Integer x = 0; x < NumberOfPaymentMethods; x++) {
            pas.add(
                new Payment_Method__c(
                    Proposal__c = ps[x].Id,
                    Account__c = ps[x].Account__c
                    // Add other field assignments for payment methods
                )
            );
        }
        insert pas;
    }

    static testMethod void PaymentMethodControllerTest2a() {
        // Build records.
        BuildTestProposals.InitTestObjects(1, 1);
        Proposal__c p = [SELECT Id, Account__c FROM Proposal__c LIMIT 1];
        Account a = [
            SELECT Id, Account_number__c
            FROM Account
            WHERE Id = :p.Account__c
        ];
        insert new Payment_Method__c(
            Proposal__c = p.Id,
            Account__c = a.Id,
            Type__c = 'Org account'
        );
        Payment_Method__c pm = [
            SELECT Id
            FROM Payment_Method__c
            WHERE Type__c = 'Org account'
            LIMIT 1
        ];

        Test.StartTest();
        PaymentMethodUniqueIdInvocable.updateUniqueId(new List<Id>{ pm.Id });
        Test.StopTest();

        // Ensure that new unique ids were constructed from the appropriate account's Account Number.
        pm = [
            SELECT Id, Unique_id__c
            FROM Payment_Method__c
            WHERE Type__c = 'Org account'
            LIMIT 1
        ];
        system.assertEquals(a.Account_number__c + '-1', pm.Unique_id__c);
    }

    static testMethod void PaymentMethodControllerTest3() {
        // Build records.
        BuildTestProposals.InitTestObjects(1, 1);
        Proposal__c p = [SELECT Id, Account__c FROM Proposal__c LIMIT 1];
        Account a = [
            SELECT Id, Account_number__c
            FROM Account
            WHERE Id = :p.Account__c
        ];
        insert new Payment_Method__c(
            Proposal__c = p.Id,
            Account__c = a.Id,
            Unique_id__c = 'wu 1',
            Type__c = 'Org account'
        );
        Payment_Method__c pm = [
            SELECT Id
            FROM Payment_Method__c
            WHERE Type__c = 'Org account'
            LIMIT 1
        ];
        insert new Payment_Method__c(
            Proposal__c = p.Id,
            Account__c = a.Id,
            Type__c = 'Alternative'
        );
        Payment_Method__c pm1 = [
            SELECT Id
            FROM Payment_Method__c
            WHERE Type__c = 'Alternative'
            LIMIT 1
        ];

        Test.StartTest();
        PaymentMethodUniqueIdInvocable.updateUniqueId(new List<Id>{ pm1.Id });
        Test.StopTest();

        // Ensure that new Unique id was copied from the earlier payment method.
        pm1 = [
            SELECT Id, Unique_id__c
            FROM Payment_Method__c
            WHERE Type__c = 'Alternative'
            LIMIT 1
        ];
        system.assertEquals('wu 1', pm1.Unique_id__c);
    }

    // Test the newPaymentMethod code
    static testMethod void PaymentMethodControllerTest4() {
        // Build records.
        ProposalUpdateTest.buildTemplateMacros();
        BuildTestProposals.InitTestObjects(1, 1);
        Proposal__c p = [SELECT Id, Account__c FROM Proposal__c LIMIT 1];
        p.Amount_awarded__c = 100;
        update p;
        Account a = [
            SELECT Id, Account_number__c
            FROM Account
            WHERE Id = :p.Account__c
        ];

        Test.StartTest();
        // No existing payment method to clone, so this should build a new one.
        PaymentMethodNewInvocable.newPaymentMethod(new List<Id>{ p.Id });
        Payment_Method__c[] pms = [
            SELECT Id, Type__c, Proposal__c, Account__c, Amount_to_pay__c
            FROM Payment_Method__c
        ];
        system.assertEquals(1, pms.size());
        system.assertEquals(100, pms[0].Amount_to_pay__c);
        system.assertEquals('Org account', pms[0].Type__c);
        // Because the new one isn't yet confirmed, we won't be able to create another.
        PaymentMethodNewInvocable.newPaymentMethod(new List<Id>{ p.Id });
        pms = [
            SELECT Id, Type__c, Proposal__c, Account__c
            FROM Payment_Method__c
        ];
        system.assertEquals(1, pms.size());
        // Verify and clear prop lookup, to make it based on the account.
        pms[0].Date_payment_info_confirmed__c = Date.today();
        pms[0].Proposal__c = null;
        update pms[0];
        ProposalUpdate.updateProposal(p.Id, true);
        // This time we can create a new one, cloning, linking to the proposal, and clearing date fields.
        PaymentMethodNewInvocable.newPaymentMethod(new List<Id>{ p.Id });
        pms = [
            SELECT Id, Type__c, Proposal__c, Account__c
            FROM Payment_Method__c
        ];
        system.assertEquals(2, pms.size());
        pms = [
            SELECT Id, Type__c, Proposal__c, Date_payment_info_confirmed__c
            FROM Payment_Method__c
            WHERE Proposal__c != null
        ];
        system.assertEquals(1, pms.size());
        system.assertEquals(p.Id, pms[0].Proposal__c);
        system.assertEquals(null, pms[0].Date_payment_info_confirmed__c);
        Test.StopTest();
    }
}