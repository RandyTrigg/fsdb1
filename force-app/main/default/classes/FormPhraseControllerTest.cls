@isTest
public class FormPhraseControllerTest {

    static testmethod void FormPhraseControllerTest () {
        // Build test records.
        insert new Form_Phrase__c (Name = 'test phrase');
        Form_Phrase__c phr = [SELECT Id FROM Form_Phrase__c WHERE Name='test phrase' LIMIT 1];
        insert new Form_Phrase_Translation__c (Form_Phrase__c = phr.Id, Language__c = 'English', Text__c = 'testing');
        Form_Phrase_Translation__c transEng = [SELECT Id FROM Form_Phrase_Translation__c WHERE Language__c='English' LIMIT 1];
        insert new Form_Phrase_Translation__c (Form_Phrase__c = phr.Id, Language__c = 'Spanish', Text__c = 'pruebas');
        Form_Phrase_Translation__c transSpan = [SELECT Id FROM Form_Phrase_Translation__c WHERE Language__c='Spanish' LIMIT 1];
        insert new Form__c (Name = 'test form', Type__c = 'Admin');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Component__c (Name = 'test form component', Form__c = f.Id, Sort_number__c = 1, Form_Phrase__c = phr.Id);
        Form_Component__c comp = [SELECT Id FROM Form_Component__c LIMIT 1];
        
        Test.startTest();
        FormPhraseUpdateEnglishInvocable.updatePhraseInEnglish(new List<Id> {phr.Id});
        Test.stopTest();
        
        phr = [SELECT Phrase_in_English__c, Phrase_in_English_trimmed__c FROM Form_Phrase__c WHERE Id = : phr.Id];
        system.assertEquals('testing', phr.Phrase_in_English__c);
        system.assertEquals('testing', phr.Phrase_in_English_trimmed__c);
        transEng = [SELECT Text_in_English__c FROM Form_Phrase_Translation__c WHERE Id = : transEng.Id];
        system.assertEquals('testing', transEng.Text_in_English__c);
        transSpan = [SELECT Text_in_English__c FROM Form_Phrase_Translation__c WHERE Id = : transSpan.Id];
        system.assertEquals('testing', transSpan.Text_in_English__c);
        comp = [SELECT Form_phrase_in_English__c FROM Form_Component__c WHERE Id = : comp.Id];
        system.assertEquals('testing', comp.Form_phrase_in_English__c);
    }

}