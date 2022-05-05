@isTest
public class FormInstanceControllerTest {
    
    static testmethod void FormInstanceControllerTest1 () {
        // Build new records
        insert new Profile__c ();
        Profile__c prof = [SELECT Id FROM Profile__c LIMIT 1];
        insert new Form__c (Name = 'Profile_Initial', Type__c = 'Profile');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Profile__c = prof.Id, Date_submitted__c = date.today());
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c LIMIT 1];
        Id fiId = fi.Id;
        insert new Form_Component__c (Name = 'test comp1', Form__c = f.Id, Sort_number__c = 1, Clear_on_re_open__c = true);
        Form_Component__c comp = [SELECT Id FROM Form_Component__c LIMIT 1];
        insert new Form_Component__c (
            Name = 'test comp2', 
            Form__c = f.Id, 
            Sort_number__c = 2, 
            Group_Component__c = comp.Id
        );
        Form_Component__c comp2 = [SELECT Id FROM Form_Component__c WHERE Name = 'test comp2' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp.Id, Data_text__c = 'test form data');
        Form_Data__c fd = [SELECT Id FROM Form_Data__c LIMIT 1];

        // Build new standard set controller and select the new form instance(s).
        List<Form_Instance__c> fiList = new List<Form_Instance__c> {fi};
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(fiList);
        ssc.setSelected(fiList);
        FormInstanceController fic = new FormInstanceController (ssc);
        
        Test.StartTest();
        FormInstanceController.getFormInstance(fi.Id);
        FormInstanceController.getFormData(fi.Id);
        List<Form_Component__c> comps = FormInstanceController.getComponents(f.Id);
        FormInstanceController.buildCmpNumberMap(comps);
        
        FormInstanceController.DataManager dm = new FormInstanceController.DataManager(fiId);
        String dataStr = FormInstanceController.getFormInstanceData(fiId);
        system.assertNotEquals(null, dataStr);

        FormInstanceController.updateTextData(fi.Id, comp.Id, 'abc');
        FormInstanceController.updateTextAreaData(fi.Id, comp2.Id, 'def');
    }

}