@isTest
public with sharing class AdvisorTermControllerTest {
    
    static testmethod void AdvisorTermControllerTest1a () {
        // Build new advisors and accounts and advisor terms.
        AdvisorControllerTest.InitTestObjects(2);
        Map<Id, Advisor_Term__c> atMap = new Map<Id, Advisor_Term__c> ([SELECT Id FROM Advisor_Term__c]);
        // Build new standard set controller and select the new advisor terms.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(atMap.values());
        ssc.setSelected(atMap.values());        
        
        Test.StartTest();
        // Build a new advisor term controller and use it to build new letters for the selected advisor terms.
        Template__c temp = new Template__c (Name = 'Test template', Source_object__c = 'Assessment__c');
        insert temp;
        AdvisorTermController pc = new AdvisorTermController (ssc);
        pc.selectedTemplate = temp.Id;
        system.assertNotEquals(pc.selectedTemplate, null);
        pc.buildLetters();
        Test.StopTest();
        
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c> ([SELECT Id FROM Letter__c]);
        AdvisorControllerTest.validate(lMap.keySet());
    }
    
    static testmethod void AdvisorTermControllerTest1b () {
        // Build new advisors and accounts and advisor terms.
        AdvisorControllerTest.InitTestObjects(2);
        Map<Id, Advisor_Term__c> atMap = new Map<Id, Advisor_Term__c> ([SELECT Id FROM Advisor_Term__c]);
        // Build new standard controller and select the new advisor term.
        ApexPages.StandardController sc = new ApexPages.StandardController(atMap.values()[0]);
        
        Test.StartTest();
        // Build a new advisor term controller and use it to build new letter for the advisor term.
        Template__c temp = new Template__c (Name = 'Test template', Source_object__c = 'Assessment__c');
        insert temp;
        AdvisorTermController pc = new AdvisorTermController (sc);
        pc.selectedTemplate = temp.Id;
        system.assertNotEquals(pc.selectedTemplate, null);
        pc.buildLetters();
        Test.StopTest();
        
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c> ([SELECT Id FROM Letter__c]);
        AdvisorControllerTest.validate(lMap.keySet());
    }
    
    static testmethod void AdvisorTermControllerTest2 () {
        // Build new advisors and accounts and advisor terms.
        AdvisorControllerTest.InitTestObjects(1);
        insert new Template__c (Name = AdvisorTermController.reminderTemplateName, Source_object__c = 'Advisor_Term__c');
        Test.StartTest();
        // Test emailing reminders via the schedulable class.
        String CRON_EXP = '0 0 0 15 3 ?';    
        String jobId = System.schedule('Email reminders', CRON_EXP, new AdvisorTermRemindersSchedule());
        Test.StopTest();
    }
    
}