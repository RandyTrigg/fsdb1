@isTest
public class TemplateControllerTest {
    // Test of TemplateMacros class
    static testMethod void TemplateControllerTest1() {
        // Build new accounts, template macros, templates
        BuildTestProposals.InitTestObjects(2, 2);
        insert new Template__c(Name = 'test template', Type__c = 'Grantmaking');
        Template__c t = [SELECT Id FROM Template__c LIMIT 1];
        insert new Template_macro__c(
            Template__c = t.Id,
            Name = 'TRUE MACRO',
            Macro_text__c = 'true'
        );
        insert new Template_macro__c( // Evals to non-null in this test.
            Template__c = t.Id,
            Name = 'ACCOUNT NAME',
            Macro_text__c = 'Account__c.Name'
        );
        insert new Template_macro__c( // Includes test of embedded macro call.
            Template__c = t.Id,
            Name = 'TEST MACRO',
            Macro_text__c = 'if(RIGHT([[ACCOUNT NAME]], 1) == "0" && [[TRUE MACRO]], "0th account: " & [[ACCOUNT NAME]], "1th account " & [[ACCOUNT NAME]])'
        );
        insert new Template_macro__c( // Should eval to blank, and not try to eval the DATEVALUE call.
            Template__c = t.Id,
            Name = 'TEST IF',
            Macro_text__c = 'IF(ISBLANK(Account__c.Site), "", CONCATENATE(" (", DATEVALUE(Account__c.LastModifiedDate), ")"))'
        );
        insert new Template_macro__c(
            Template__c = t.Id,
            Name = 'TEST FLOOR',
            Macro_text__c = 'TEXT(FLOOR(15.5))'
        );
        insert new Template_macro__c(
            Template__c = t.Id,
            Name = 'Macro with unknown field',
            Macro_text__c = 'abcdefg'
        );

        Test.StartTest();
        Proposal__c[] props = [
            SELECT Id, Account__r.Name, Account__r.Site
            FROM Proposal__c
        ];
        TemplateController.TemplateMacros tm = new TemplateController.TemplateMacros(
            t.Id
        );
        system.assertEquals(2, props.size());
        tm.initialize(props[0]);
        system.assert(
            ((String) tm.evaluate('TEST MACRO')).contains('0th account')
        );
        system.assertEquals('', (String) tm.evaluate('TEST IF'));
        system.assertEquals('15', (String) tm.evaluate('TEST FLOOR'));
        tm.initialize(props[1]);
        system.assert(
            ((String) tm.evaluate('TEST MACRO')).contains('1th account')
        );
        Test.StopTest();
    }
}