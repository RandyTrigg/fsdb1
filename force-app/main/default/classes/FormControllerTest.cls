@isTest
public with sharing class FormControllerTest {
    
    // Test form phrase tagging code
    static testmethod void FormCloneTest3 () {
        // Build records.
        insert new Form_Phrase__c (Name = 'test phrase');
        Form_Phrase__c fp = [SELECT Id FROM Form_Phrase__c LIMIT 1];
        insert new Form_Phrase__c (Name = 'test phrase pre-tagged', SavedSetNames__c = 'test form');
        insert new Form__c (Name = 'test form', Type__c = 'Admin', Form_Phrase_confirm__c = fp.Id);
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        Test.startTest();
        FormTagFormPhrasesInvocable.tagFormPhrases(new List<Id>{f.Id});
        Test.stopTest();
        fp = [SELECT SavedSetNames__c FROM Form_Phrase__c WHERE Name = 'test phrase' LIMIT 1];
        Form_Phrase__c fp1 = [SELECT SavedSetNames__c FROM Form_Phrase__c WHERE Name = 'test phrase pre-tagged' LIMIT 1];
        system.assertEquals('test form', fp.SavedSetNames__c);
        system.assertEquals(null, fp1.SavedSetNames__c);
    }
}