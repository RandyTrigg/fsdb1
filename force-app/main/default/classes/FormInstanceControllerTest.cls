@isTest
public class FormInstanceControllerTest {
    
    static testmethod void FormInstanceControllerTest1 () {
        // Build new records
        insert new Profile__c (Contact1_email__c = 'abc@def.com');
        Profile__c prof = [SELECT Id FROM Profile__c LIMIT 1];
        insert new Form_Phrase__c (Name = 'testPhrase');
        Form_Phrase__c fp = [SELECT Id FROM Form_Phrase__c LIMIT 1];
        insert new Form_Phrase_Translation__c (Form_Phrase__c = fp.Id, Text__c = 'testing...');
        Form_Phrase_Translation__c fpt = [SELECT Id FROM Form_Phrase_Translation__c LIMIT 1];
        insert new Form__c (
            Name = 'Profile_Initial', 
            Type__c = 'Profile', 
            Form_Phrase_ack_email_subject__c = fp.Id,
            Form_Phrase_ack_email_body__c = fp.Id
            );
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Profile__c = prof.Id, Date_submitted__c = date.today());
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c LIMIT 1];
        Id fiId = fi.Id;
        insert new Form_Component__c (Name = 'test comp1', Type__c = 'group', Form__c = f.Id, Sort_number__c = 1, Clear_on_re_open__c = true);
        Form_Component__c comp = [SELECT Id FROM Form_Component__c LIMIT 1];
        insert new Form_Component__c (
            Name = 'test comp2', 
            Type__c = 'text',
            Form__c = f.Id, 
            Sort_number__c = 2, 
            Group_Component__c = comp.Id
        );
        Form_Component__c comp2 = [SELECT Id FROM Form_Component__c WHERE Name = 'test comp2' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp.Id, Data_text__c = 'test form data');
        Form_Data__c fd = [SELECT Id FROM Form_Data__c LIMIT 1];
        
        Test.StartTest();
        FormInstanceController.getFormInstance(fi.Id);
        FormInstanceController.getFormData(fi.Id);
        List<Form_Component__c> comps = FormInstanceController.getComponents(f.Id);
        FormInstanceController.buildCmpNumberMap(comps);
        
        String dataStr = SiteController.getFormInstanceData(fiId);
        system.assertNotEquals(null, dataStr);

        SiteController.updateFormData(fi.Id, comp.Id, 'abc', false);
        SiteController.updateFormData(fi.Id, comp2.Id, 'def', true);

        FormInstanceController.FormDataInfo[] fdis = new List<FormInstanceController.FormDataInfo> {
            new FormInstanceController.FormDataInfo(comp.Id, 'aabbcc', false), // changed
            new FormInstanceController.FormDataInfo(comp2.Id, 'def', true) // not changed
        };
        SiteController.updateFormDataBulk(fi.Id, JSON.serialize(fdis));

        SiteController.submitForm(fi.Id);

        SiteController.getFormInstances(prof.Id);
        Test.stopTest();
        Form_Data__c[] fds = [SELECT Id FROM Form_Data__c];
        system.assertEquals(2, fds.size()); // A new form data should be created by call to updateFormData
        // Build new "dupe" form data
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp.Id, Data_text__c = 'test form data 2');
        Form_Data__c fd2 = [SELECT Id FROM Form_Data__c WHERE Data_text__c = 'test form data 2' LIMIT 1];
        // Rerun bulk save and check that the earlier form data was deleted
        SiteController.updateFormDataBulk(fi.Id, JSON.serialize(fdis));
        fds = [SELECT Id FROM Form_Data__c];
        system.assertEquals(2, fds.size()); // Still only 2, following delete
    }

}