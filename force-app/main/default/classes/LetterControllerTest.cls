@isTest
public class LetterControllerTest {
    /*
     * Test of LetterReset class
     */

    static testMethod void LetterResetTest1() {
        // Build new accounts, letters, template pieces, template macros, templates
        InitTestRecords1(3);
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Id FROM Letter__c]
        );

        Test.StartTest();
        LetterReset lr = new LetterReset();
        lr.resetLettersHandler(lMap.keySet());
        Test.StopTest();

        validate1(lMap.keySet());
    }

    // Build sample accounts, letters, template pieces, template macros, templates
    static void initTestRecords1(Integer NumberOfRecords) {
        insert new Template__c(Name = 'TY General', Type__c = 'Development');
        Id tId = [SELECT Id FROM Template__c LIMIT 1].Id;
        insert new Custom_Reqs__c(
            Name = 'Test reporting reqs',
            Short_name__c = 'Test'
        );
        Id iId = [SELECT Id FROM Custom_Reqs__c LIMIT 1].Id;
        insert new Template_macro__c(
            Template__c = tId,
            Name = 'TRUE MACRO',
            Macro_text__c = 'true'
        );
        insert new Template_macro__c( // Evals to non-null in this test.
            Template__c = tId,
            Name = 'DESCRIPTION',
            Macro_text__c = 'Account.Description'
        );
        insert new Template_macro__c( // Includes test of embedded macro call.
            Template__c = tId,
            Name = 'TEST MACRO',
            Macro_text__c = 'if([[DESCRIPTION]] == "0" && [[TRUE MACRO]], "{{Test piece EVEN}}", "{{Test piece ODD}}")'
        );
        insert new Template_macro__c( // Should eval to blank, and not try to eval the DATEVALUE call.
            Template__c = tId,
            Name = 'TEST IF',
            Macro_text__c = 'IF(ISBLANK(Account.Site), "", CONCATENATE(" (", DATEVALUE(Account.LastModifiedDate), ")"))'
        );
        insert new Template_macro__c(
            Template__c = tId,
            Name = 'TEST FLOOR',
            Macro_text__c = 'TEXT(FLOOR(15.5))'
        );
        insert new Template_piece__c(
            Template__c = tId,
            Name = 'PAGE 1',
            Piece_text__c = '{{Test empty piece}}{{Test generic}} [[TEST MACRO]]'
        );
        insert new Template_piece__c(
            Template__c = null,
            Name = 'Test empty piece',
            Piece_text__c = ''
        );
        insert new Template_piece__c(
            Template__c = null,
            Name = 'Test generic',
            Piece_text__c = 'Letter body'
        );
        insert new Template_piece__c(
            Template__c = null,
            Custom_Reqs__c = iId,
            Name = 'Test generic',
            Piece_text__c = 'Letter body'
        );
        insert new Template_piece__c(
            Template__c = tId,
            Custom_Reqs__c = iId,
            Name = 'Test piece EVEN',
            Piece_text__c = 'EVEN (reporting reqs) for account = <<Account.Name>>[[TEST IF]]'
        );
        insert new Template_piece__c(
            Template__c = tId,
            Name = 'Test piece ODD',
            Piece_text__c = 'ODD for account = <<Account.Name>> [[TEST FLOOR]]'
        );
        List<Account> accts = new List<Account>();
        for (Integer x = 0; x < NumberOfRecords; x++)
            accts.add(
                new Account(
                    Name = 'LetterTest_' + String.valueOf(x),
                    // Record type Household is currently (10/8/20) hidden for FFDB
                    RecordTypeId = Utilities.getRecTypeId(
                        'Account',
                        'Organization' // 'Household'
                    ),
                    Description = String.valueOf(Math.mod(x, 2))
                )
            );
        insert accts;
        List<Letter__c> lets = new List<Letter__c>();
        for (Integer x = 0; x < NumberOfRecords; x++)
            lets.add(
                new Letter__c(
                    Account__c = accts[x].Id,
                    Template__c = tId,
                    Custom_Reqs__c = (Math.mod(x, 2) == 0) ? iId : null
                )
            );
        insert lets;
    }

    // Test the error checking code.
    static testMethod void LetterResetTest2() {
        // Build new account, letter, template piece, template macro, template
        InitTestRecords2(1);
        Letter__c let = [SELECT Id FROM Letter__c LIMIT 1];
        Template_piece__c tp = [
            SELECT Id, Piece_text__c
            FROM Template_piece__c
            LIMIT 1
        ];
        Template_macro__c tm = [
            SELECT Id, Macro_text__c
            FROM Template_macro__c
            LIMIT 1
        ];

        Test.StartTest();
        // Test a bunch of different errors.
        // Unknown field in PAGE 1 template piece.
        testResetLetter(let.Id);
        // Empty field in PAGE 1 template piece.
        tp.Piece_text__c = '<<>>';
        update tp;
        testResetLetter(let.Id);
        // Unknown macro call in PAGE 1 template piece.
        tp.Piece_text__c = '[[UnknownMacro]]';
        update tp;
        testResetLetter(let.Id);
        // Unknown piece in template macro.
        tp.Piece_text__c = '[[Testing macro]]';
        update tp;
        testResetLetter(let.Id);
        // Unknown field name in template macro.
        tm.Macro_text__c = 'UnknownField';
        update tm;
        testResetLetter(let.Id);
        // Recursive call in template macro.
        tm.Macro_text__c = '[[Testing macro]]';
        update tm;
        testResetLetter(let.Id);
        Test.StopTest();
    }

    // Reset given letter in try/catch with debugging statements.
    static void testResetLetter(Id letId) {
        try {
            LetterReset lr = new LetterReset();
            lr.resetLettersHandler(new Set<Id>{ letId });
        } catch (exception e) {
            system.debug('testResetLetter: exception = ' + e);
        }
        Letter__c let = [SELECT Id, Page_1__c FROM Letter__c WHERE Id = :letId];
        system.debug('testResetLetter: Page_1__c = ' + let.Page_1__c);
    }

    // Build sample accounts, letters, template pieces, template macros, templates
    static void initTestRecords2(Integer NumberOfRecords) {
        insert new Template__c(Name = 'TY General', Type__c = 'Development');
        Id tId = [SELECT Id FROM Template__c LIMIT 1].Id;
        insert new Custom_Reqs__c(
            Name = 'Test reporting reqs',
            Short_name__c = 'Test'
        );
        Id iId = [SELECT Id FROM Custom_Reqs__c LIMIT 1].Id;
        insert new Template_macro__c(
            Template__c = tId,
            Name = 'Testing macro',
            Macro_text__c = '"{{UnknownPiece}}"'
        );
        insert new Template_piece__c(
            Template__c = tId,
            Name = 'PAGE 1',
            Piece_text__c = '<<UnknownField>>'
        );
        List<Account> accts = new List<Account>();
        for (Integer x = 0; x < NumberOfRecords; x++)
            accts.add(
                new Account(
                    Name = 'LetterTest_' + String.valueOf(x),
                    // Record type Household is currently (10/8/20) hidden for FFDB
                    RecordTypeId = Utilities.getRecTypeId(
                        'Account',
                        'Organization' // 'Household'
                    ),
                    Description = String.valueOf(Math.mod(x, 2))
                )
            );
        insert accts;
        List<Letter__c> lets = new List<Letter__c>();
        for (Integer x = 0; x < NumberOfRecords; x++)
            lets.add(
                new Letter__c(
                    Account__c = accts[x].Id,
                    Template__c = tId,
                    Custom_Reqs__c = (Math.mod(x, 2) == 0) ? iId : null
                )
            );
        insert lets;
    }

    static void validate1(Set<ID> lIds) {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [
                SELECT Account__r.Name, Account__r.Description, Page_1__c
                FROM Letter__c
                WHERE Id IN :lIds
            ]
        );

        // "Even" accounts need to have "even" letter bodies, and likewise for "odd" accounts.
        // The "even" ones should get the reporting reqs-based piece.
        for (Letter__c l : lMap.values()) {
            if (l.Account__r.Description == '0') {
                system.assertEquals(
                    'Letter body EVEN (reporting reqs) for account = ' +
                    l.Account__r.Name,
                    l.Page_1__c
                );
            } else {
                system.assertEquals(
                    'Letter body ODD for account = ' +
                    l.Account__r.Name +
                    ' 15',
                    l.Page_1__c
                );
            }
        }
    }

    // Test batch process - no problems (that is, none unprocessed because of non-blank date sent).
    static testMethod void LetterControllerTestBatch1() {
        Map<Id, Letter__c> letMap = initTestLetters(1);
        Test.StartTest();
        // Run the batch reset process.
        Database.executeBatch(
            new LetterResetBatch(letMap.keySet(), false),
            LetterController.resetBatchSize
        );
        Test.StopTest();
    }

    // Test batch process - one problem (that is, one unprocessed because of non-blank date sent).
    static testMethod void LetterControllerTestBatch2() {
        Map<Id, Letter__c> letMap = initTestLetters(2);
        Test.StartTest();
        // Set date emailed to cause a problem for reset.
        letMap.values()[0].Date_emailed__c = Date.today();
        update letMap.values();
        // Run the batch reset process.
        Database.executeBatch(
            new LetterResetBatch(letMap.keySet(), false),
            LetterController.resetBatchSize
        );
        Test.StopTest();
    }

    // Test batch process - two problems (that is, both letters unprocessed because of non-blank date sent).
    static testMethod void LetterControllerTestBatch3() {
        Map<Id, Letter__c> letMap = initTestLetters(2);
        Test.StartTest();
        // Set date emailed to cause a problem for reset.
        letMap.values()[0].Date_emailed__c = Date.today();
        letMap.values()[1].Date_emailed__c = Date.today();
        update letMap.values();
        // Run the batch reset process.
        Database.executeBatch(
            new LetterResetBatch(letMap.keySet(), false),
            LetterController.resetBatchSize
        );
        Test.StopTest();
    }

    // Test print process.
    static testMethod void LetterControllerTestPrint() {
        Map<Id, Letter__c> letMap = initTestLetters(2);
        // Build new standard set controller for the letters.
        ApexPages.StandardSetController ssct = new ApexPages.StandardSetController(
            letMap.values()
        );
        ssct.setSelected(letMap.values());
        LetterController lc1 = new LetterController(ssct);
        // Build standard controller for a single letter
        ApexPages.StandardController sct = new ApexPages.StandardController(
            letMap.values()[0]
        );
        LetterController lc2 = new LetterController(sct);
        Test.StartTest();
        lc1.printLetters();
        lc2.printLetters();
        // Invocations for code coverage
        lc1.resetLetters();
        lc1.emailLetters();
        lc1.doCancel();
        lc2.doCancel();
        Test.StopTest();
    }

    // Build a test letter for proposal contract letter.
    static Map<Id, Letter__c> initTestLetters(Integer numRecords) {
        // Build new accounts, letters, template pieces, template macros, templates
        insert new Account(
            Name = 'LetterTest',
            // Record type Household is currently (10/8/20) hidden for FFDB
            RecordTypeId = Utilities.getRecTypeId(
                'Account',
                'Organization' // 'Household'
            )
        );
        Id acc1Id = [SELECT Id FROM Account LIMIT 1].Id;
        insert new Contact(
            AccountId = acc1Id,
            LastName = 'Smith',
            Email = 'abc@def.org',
            RecordTypeId = Utilities.getRecTypeId('Contact', 'Contact_Dev')
        );
        Id ct1Id = [SELECT Id FROM Contact LIMIT 1].Id;
        for (Integer x = 0; x < numRecords; x++) {
            insert new Proposal__c(
                Account__c = acc1Id,
                Contract_signer__c = ct1Id,
                Contract_signer_2__c = ct1Id
            );
        }
        insert new Template__c(
            Name = 'Contract letter & cover',
            Type__c = 'Grantmaking',
            Source_object__c = 'Proposal__c'
        );
        Map<Id, Proposal__c> pMap = new Map<Id, Proposal__c>(
            [SELECT Id FROM Proposal__c]
        );
        // Build new standard set controller and build letters for the new proposals.
        ApexPages.StandardSetController ssct = new ApexPages.StandardSetController(
            pMap.values()
        );
        ssct.setSelected(pMap.values());
        ProposalController pc = new ProposalController(ssct);
        pc.selectedTemplate = 'Contract letter & cover';
        pc.buildLetters();
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Id, Proposal__c FROM Letter__c]
        );
        return lMap;
    }

    // Test code to update date field in related record.
    static testMethod void LetterControllerTest2() {
        BuildTestProposals.InitTestObjects(1, 1);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Template__c(
            Name = 'Decline letter',
            Type__c = 'Grantmaking',
            Date_sent_recd_object_name__c = 'Proposal__c',
            Date_sent_recd_field_name__c = 'Date_declined__c'
        );
        Template__c t = [SELECT Id FROM Template__c LIMIT 1];
        Date d = Date.today();
        insert new Letter__c(
            Template__c = t.Id,
            Proposal__c = p.Id,
            Date_emailed__c = d
        );
        Letter__c l = [SELECT Id FROM Letter__c LIMIT 1];

        Test.startTest();
        LetterUpdatedInvocable.letterUpdated(new List<Id>{ l.Id });
        Test.stopTest();

        p = [SELECT Id, Date_declined__c FROM Proposal__c LIMIT 1];
        system.assertEquals(d, p.Date_declined__c);
    }
}