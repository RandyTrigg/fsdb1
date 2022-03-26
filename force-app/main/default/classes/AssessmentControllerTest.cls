@isTest
public with sharing class AssessmentControllerTest {
    
    // New letter for assessment set
    static testmethod void AssessmentControllerTest1a () {
        // Build new advisors and accounts and advisor terms.
        AdvisorControllerTest.InitTestObjects(1);
        Advisor__c adv = [SELECT Id, Account__c FROM Advisor__c LIMIT 1];
        insert new Account (Name = 'Test account');
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Form__c (Name = 'Test form', Type__c = 'Admin');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        // Build new assessment.
        insert new Assessment__c (Advisor__c = adv.Id, Account__c = acc.Id, Form__c = f.Id);
        Assessment__c[] assessments = [SELECT Id FROM Assessment__c];
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(assessments);
        ssc.setSelected(assessments);
        
        Test.StartTest();
        // Build a new assessment controller and use it to build new letter for the selected assessment.
        Template__c temp = new Template__c (Name = 'Test template', Source_object__c = 'Assessment__c');
        insert temp;
        AssessmentController pc = new AssessmentController (ssc);
        pc.selectedTemplate = temp.Id;
        system.assertNotEquals(pc.selectedTemplate, null);
        pc.buildLetters();
        Test.StopTest();
        
        Letter__c let = [SELECT Id, Advisor__c, Account__c FROM Letter__c LIMIT 1];
        system.assertEquals(adv.Id, let.Advisor__c);
        system.assertEquals(adv.Account__c, let.Account__c);
    }
    
    // New letter for single assessment
    static testmethod void AssessmentControllerTest1b () {
        // Build new advisors and accounts and advisor terms.
        AdvisorControllerTest.InitTestObjects(1);
        Advisor__c adv = [SELECT Id, Account__c FROM Advisor__c LIMIT 1];
        insert new Account (Name = 'Test account');
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Form__c (Name = 'Test form', Type__c = 'Admin');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        // Build new assessment.
        insert new Assessment__c (Advisor__c = adv.Id, Account__c = acc.Id, Form__c = f.Id);
        Assessment__c assessment = [SELECT Id FROM Assessment__c LIMIT 1];
        // Build new standard controller and select the new assessment.
        ApexPages.StandardController sc = new ApexPages.StandardController(assessment);
        
        Test.StartTest();
        // Build a new assessment controller and use it to build new letter for the selected assessment.
        Template__c temp = new Template__c (Name = 'Test template', Source_object__c = 'Assessment__c');
        insert temp;
        AssessmentController pc = new AssessmentController (sc);
        pc.selectedTemplate = temp.Id;
        system.assertNotEquals(pc.selectedTemplate, null);
        pc.buildLetters();
        Test.StopTest();
        
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c> ([SELECT Id FROM Letter__c]);
        AdvisorControllerTest.validate(lMap.keySet());
    }
    
}