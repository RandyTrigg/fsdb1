@isTest
public class AdvisorPaymentControllerTest {
    static testmethod void AdvisorPaymentControllerTest1 () {
        // Build new advisors and accounts and advisor terms.
        AdvisorControllerTest.InitTestObjects(1, 1);
        Advisor_Term__c at = [SELECT Id FROM Advisor_Term__c LIMIT 1];
        Date d = System.today();
        insert new Advisor_Payment__c (Advisor_Term__c = at.Id, Amount_paid__c=0, Date_paid_accounting__c=d, Payment_ref__c='Cash');
        Map<Id, Advisor_Payment__c> apMap = new Map<Id, Advisor_Payment__c> ([SELECT Id FROM Advisor_Payment__c]);
        // Build new standard set controller and select the new advisor terms.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(apMap.values());
        ssc.setSelected(apMap.values());
        
        Test.StartTest();
        // Build a new advisor payment controller and use it to build new letters for the selected advisor payments.
        Template__c temp = new Template__c (Name = 'Test template', Source_object__c = 'Advisor_Payment__c');
        insert temp;
        AdvisorPaymentController pc = new AdvisorPaymentController (ssc);
        pc.selectedTemplate = temp.Id;
        system.assertNotEquals(pc.selectedTemplate, null);
        pc.buildLetters();
        Test.StopTest();
        
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c> ([SELECT Id FROM Letter__c]);
        AdvisorControllerTest.validate(lMap.keySet());
    }
    
    static testmethod void AdvisorPaymentControllerTest2 () {
        // Build new advisors and accounts and advisor terms.
        AdvisorControllerTest.InitTestObjects(1, 1);
        Advisor_Term__c at = [SELECT Id FROM Advisor_Term__c LIMIT 1];
        Date d = System.today();
        insert new Advisor_Payment__c (Advisor_Term__c = at.Id, Amount_paid__c=0, Date_paid_accounting__c=d, Payment_ref__c='Cash');
        Map<Id, Advisor_Payment__c> apMap = new Map<Id, Advisor_Payment__c> ([SELECT Id FROM Advisor_Payment__c]);
        // Build new standard controller.
        ApexPages.StandardController sc = new ApexPages.StandardController(apMap.values()[0]);
        
        Test.StartTest();
        // Build a new advisor payment controller and use it to build new letter.
        Template__c temp = new Template__c (Name = 'Test template', Source_object__c = 'Advisor_Payment__c');
        insert temp;

        AdvisorPaymentController pc = new AdvisorPaymentController (sc);
        pc.selectedTemplate = temp.Id;
        system.assertNotEquals(pc.selectedTemplate, null);
        pc.buildLetters();
        Test.StopTest();
        
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c> ([SELECT Id FROM Letter__c]);
        AdvisorControllerTest.validate(lMap.keySet());
    }
}