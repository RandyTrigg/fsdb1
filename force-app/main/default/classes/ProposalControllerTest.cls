@isTest
public class ProposalControllerTest {
    /**********************************
     * Test the component/Experience-related methods
     * *******************************/

    static testMethod void ProposalSummaryTest() {
        Date tday = Date.today();
        BuildTestProposals.InitTestObjects(1, 1);
        Proposal__c p = [SELECT Id, Account__c FROM Proposal__c LIMIT 1];
        Form__c testForm = new Form__c(
            Name='Test',
            Active__c = true,
            Type__c = 'Application'
        );
        insert testForm;
        insert new Form_Instance__c(
            Form__c = testForm.Id,
            Proposal__c = p.Id,
            Language__c = 'English'
        );
        Template__c template = new Template__c(
            Name='Test',
            Active__c = true,
            Type__c = 'Grantmaking',
            Source_object__c = 'Proposal__c'
        );
        insert template;
        insert new Letter__c(
            Template__c = template.Id,
            Account__c = p.Account__c,
            Proposal__c = p.Id,
            Date_emailed__c = tday-2
        );

        Test.StartTest();
        ProposalController.ProposalSummary pSummary = ProposalController.ProposalSummary(
            p.Id
        );
        Test.StopTest();

        List<Letter__c> let = new List<Letter__c>([SELECT Id FROM Letter__c WHERE Proposal__c = :p.Id AND Date_sent__c<>null]);
        List<Form_Instance__c> fmInst = new List<Form_Instance__c>([SELECT Id FROM Form_Instance__c WHERE Proposal__c = :p.Id]);

        System.assertEquals(let.size(), pSummary.letterList.size());
        System.assertEquals(fmInst.size(), pSummary.formInstanceList.size());
    }

    static testMethod void ProposalControllerTest() {
        // Build new records
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'test account',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Review_Form__c(Name = 'test proposal review form');
        Review_Form__c rf = [SELECT Id FROM Review_Form__c LIMIT 1];
        insert new Review_Form_Component__c(
            Review_Form__c = rf.Id,
            Lightning_component_name__c = 'InputCheckbox',
            Sort_number__c = 1
        );
        insert new Custom_Reqs__c(
            Name = 'test custom reqs',
            Proposal_review_form__c = rf.Id
        );
        Custom_Reqs__c cr = [SELECT Id FROM Custom_Reqs__c LIMIT 1];
        insert new Profile__c();
        Profile__c pr = [SELECT Id FROM Profile__c LIMIT 1];
        insert new Proposal__c(
            Account__c = a.Id,
            Profile__c = pr.Id,
            Custom_Reqs__c = cr.Id
        );
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Classification__c(
            Name = 'Test Population',
            Type__c = 'Population'
        );
        Classification__c cp = [
            SELECT Id
            FROM Classification__c
            WHERE Type__c = 'Population'
            LIMIT 1
        ];
        insert new Classification__c(
            Name = 'Test Strategy',
            Type__c = 'Strategy'
        );
        Classification__c cs = [
            SELECT Id
            FROM Classification__c
            WHERE Type__c = 'Strategy'
            LIMIT 1
        ];
        insert new Classification__c(Name = 'Test Issue 1', Type__c = 'Issue');
        Classification__c ci1 = [
            SELECT Id
            FROM Classification__c
            WHERE Name = 'Test Issue 1'
            LIMIT 1
        ];
        insert new Classification__c(Name = 'Test Issue 2', Type__c = 'Issue');
        Classification__c ci2 = [
            SELECT Id
            FROM Classification__c
            WHERE Name = 'Test Issue 2'
            LIMIT 1
        ];
        insert new Classification_Assign__c(
            Proposal__c = p.Id,
            Classification__c = cs.Id
        );
        insert new Classification_Profile_Assign__c(
            Profile__c = pr.Id,
            Classification__c = cs.Id
        );
        insert new Classification_Profile_Assign__c(
            Profile__c = pr.Id,
            Classification__c = ci1.Id
        );
        insert new Classification_Profile_Assign__c(
            Profile__c = pr.Id,
            Classification__c = ci2.Id
        );
        insert new Portfolio__c(Name = 'Test portfolio', Type__c = 'Priority');
        Id portId = [SELECT Id FROM Portfolio__c LIMIT 1].Id;
        insert new Portfolio_Assignment__c(
            Proposal__c = p.Id,
            Portfolio__c = portId
        );

        Test.StartTest();
        //system.assertEquals((String)d.Id, fis.gmDataId);
        ProposalController.ProposalInfo pInfo = ProposalController.getProposalInfo(
            p.Id
        );
        ProposalController.getClassificationInfo('Issue', p.Id);
        GM_Data__c d = [SELECT Id FROM GM_Data__c WHERE Proposal__c = :p.Id];
        ProposalController.saveProposalInfo1(
            p,
            d,
            String.valueOf(cp.Id),
            String.valueOf(cs.Id),
            String.valueOf(ci1.Id),
            String.valueOf(portId)
        );
        Test.StopTest();

        // Copy classification assigns from profile, check that we don't duplicate the ones that proposal already has.
        ProposalController.copyClassificationAssignsFromProfile(p.Id, pr.Id);
        Classification_Assign__c[] propClassAssigns = [
            SELECT Id
            FROM Classification_Assign__c
        ];
        Classification_Profile_Assign__c[] profClassAssigns = [
            SELECT Id
            FROM Classification_Profile_Assign__c
        ];
        system.assertEquals(3, profClassAssigns.size());
        system.assertEquals(4, propClassAssigns.size());
    }

    /**********************************
     * Test the VF-related methods
     * *******************************/

    static testMethod void ProposalControllerTest1() {
        // Build new proposals and accounts
        BuildTestProposals.InitTestObjects(2, 2);
        Map<Id, Proposal__c> pMap = new Map<Id, Proposal__c>(
            [SELECT Id FROM Proposal__c]
        );
        // Build new standard set controller and select the new proposals.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            pMap.values()
        );
        ssc.setSelected(pMap.values());

        Test.StartTest();
        // Build a new proposal controller and use it to build new letters for the selected proposals.
        insert (new Template__c(
            Name = 'Test template',
            Source_object__c = 'Proposal__c'
        ));
        ProposalController pc = new ProposalController(ssc);
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
                SELECT Account__c, Emails__c, Proposal__c
                FROM Letter__c
                WHERE Id IN :lIds
            ]
        );
        Map<Id, Proposal__c> pMap = new Map<Id, Proposal__c>(
            [
                SELECT Id
                FROM Proposal__c
                WHERE
                    Id IN (SELECT Proposal__c FROM Letter__c WHERE Id IN :lIds)
            ]
        );
        // Should be a different letter for each proposal.
        system.assertEquals(lMap.size(), pMap.size());
        // Gather email addresses for the accounts of these proposals.
        Map<Id, Account> aMap = new Map<Id, Account>(
            [
                SELECT Id
                FROM Account
                WHERE
                    Id IN (
                        SELECT Account__c
                        FROM Proposal__c
                        WHERE Id IN :pMap.keySet()
                    )
            ]
        );
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

    static testMethod void ProposalControllerTest2() {
        // Build 1 new proposal/account
        BuildTestProposals.InitTestObjects(1, 1);
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
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
        ProposalEmailLetterInvocable.EmailLetterRequest req = new ProposalEmailLetterInvocable.EmailLetterRequest();
        req.propId = prop.Id;
        req.templateId = template.Id;
        ProposalEmailLetterInvocable.buildAndEmailLetter(
            new List<ProposalEmailLetterInvocable.EmailLetterRequest>{ req }
        );
        Test.StopTest();
    }

    // Test batch OFAC search.
    static testMethod void ProposalControllerTest4() {
        // Set mock callout class and build custom settings for OFAC lookup test.
        Test.setMock(HttpCalloutMock.class, new OFACLookupMock());
        OFACLookupTest.buildCustomSettings();
        // Build new proposals and accounts
        BuildTestProposals.InitTestObjects(1, 1);
        Map<Id, Proposal__c> pMap = new Map<Id, Proposal__c>(
            [SELECT Id FROM Proposal__c]
        );
        // Build new standard set controller and select the new proposals.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            pMap.values()
        );
        ssc.setSelected(pMap.values());

        Test.StartTest();
        // Build a new proposal controller.
        ProposalController pc = new ProposalController(ssc);
        pc.performOFACLookupBatch(); // Do OFAC lookup for each proposal.
        Test.StopTest();
    }

    // Test the BuildSubmissions code (similar to BuildLetters).
    static testMethod void ProposalControllerTest5() {
        // Build new proposals and accounts
        BuildTestProposals.InitTestObjects(2, 2);
        Map<Id, Proposal__c> pMap = new Map<Id, Proposal__c>(
            [SELECT Id FROM Proposal__c]
        );
        // Build new standard set controller and select the new proposals.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            pMap.values()
        );
        ssc.setSelected(pMap.values());

        Test.StartTest();
        // Build a new proposal controller and use it to build submissions for the selected proposals.
        ProposalController pc = new ProposalController(ssc);
        pc.buildSubmissions();
        Test.StopTest();

        system.debug(
            'ProposalControllerTest5: pc.submissions = ' + pc.submissions
        );
    }


}