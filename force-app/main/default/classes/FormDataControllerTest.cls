@isTest
public class FormDataControllerTest {
    static testmethod void FormDataControllerTest1 () {
        // Build new records.
        insert new Region__c (Name = 'test region');
        Region__c r = [SELECT Id FROM Region__c LIMIT 1];
        insert new Country__c (Region__c = r.Id, Name = 'Côte d\'Ivoire');
        Country__c c = [SELECT Id FROM Country__c LIMIT 1];
        
        BuildTestProposals.InitTestObjects(1, 1);
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Profile__c (Account__c = acc.Id, Organization_type__c = 'LocalNetwork');
        Profile__c prof = [SELECT Id FROM Profile__c LIMIT 1];
        
        insert new Form_Picklist__c (Name = 'Countries');
        Form_Picklist__c plist = [SELECT Id FROM Form_Picklist__c LIMIT 1];
        insert new Form__c (Name = 'test form', Type__c = 'Admin');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Profile__c = prof.Id);
        Form_Instance__c fi1 = [SELECT Id FROM Form_Instance__c LIMIT 1];
        insert new Classification_Category__c (Name = 'Age and Gender');
        Classification_Category__c cc = [SELECT Id FROM Classification_Category__c LIMIT 1];
        insert new Classification__c (Name = 'Girls', Type__c = 'Population', Classification_Category__c = cc.Id);
        Classification__c cl = [SELECT Id FROM Classification__c LIMIT 1];
        insert new Classification_Profile_Assign__c (Profile__c = prof.Id, Classification__c = cl.Id);
        insert new Classification__c (Name = 'Young Women', Type__c = 'Population', Classification_Category__c = cc.Id);
        
        // Build form components and matching form data.
        // Update a text field in Profile.
        insert new Form_Component__c (
            Name = 'test component 1', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Target_object_name__c = 'Profile__c', 
            Target_field_name__c = 'Language__c'
        );
        Form_Component__c comp1 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 1' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = comp1.Id, Data_text__c = 'French');
        insert new Form_Component__c (
            Name = 'test component 2', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Target_object_name__c = 'Profile__c', 
            Target_field_name__c = 'Org_name_submitted__c'
        );
        Form_Component__c comp2 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 2' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = comp2.Id, Data_text__c = 'group name');
        // Update country field in Profile.
        insert new Form_Component__c (
            Name = 'test component 3', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Target_object_name__c = 'Profile__c', 
            Target_field_name__c = 'Country__c',
            Form_Picklist__c = plist.Id
        );
        Form_Component__c comp3 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 3' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = comp3.Id, Data_text__c = 'Côte d\'Ivoire');
        // Update checkbox field in Profile.
        insert new Form_Component__c (
            Name = 'test component 4', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Target_object_name__c = 'Profile__c', 
            Target_field_name__c = 'Keep_confidential__c'
        );
        Form_Component__c comp4 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 4' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = comp4.Id, Data_text__c = 'Yes');
        // Update classification joins in Profile.
        insert new Form_Component__c (
            Name = 'Populations', 
            Form__c = f.Id, 
            Sort_number__c = 1
        );
        
        Test.StartTest();
        FormDataUpdateTargetsInvocable.UpdateTargetFields(new List<Id> {fi1.Id});
        // Run batch code for coverage.
        String q = 'SELECT Id FROM Form_Instance__c';
        Database.executeBatch(new FormDataUpdateTargetsBatch(q), 10);
        Test.StopTest();
        
        // Check that target fields were updated.
        prof = [SELECT Id, Keep_confidential__c, Org_name_submitted__c, Country__c, Language__c FROM Profile__c LIMIT 1];
        System.assert(prof.Keep_confidential__c);
        System.assertEquals('French', prof.Language__c);
        System.assertEquals('group name', prof.Org_name_submitted__c);
        System.assertEquals(c.Id, prof.Country__c);
    }

    // Test field targeting to gmdata
    static testmethod void FormDataControllerTest2 () {
        // Build new records.
        
        BuildTestProposals.InitTestObjects(1, 1);
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Milestone__c (Proposal__c = prop.Id, Type__c = 'Report');
        Milestone__c milestone = [SELECT Id FROM Milestone__c LIMIT 1];
        // First gm data is in the "new" style: proposal links TO the gm data
        insert new GM_Data__c ();
        GM_Data__c gmData1 = [SELECT Id FROM GM_Data__c LIMIT 1];
        prop.GM_Data__c = gmData1.Id;
        update prop;
        
        Test.StartTest();
        insert new Form__c (Name = 'test form', Type__c = 'Admin');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Proposal__c = prop.Id, Milestone__c = null);
        Form_Instance__c fi1 = [SELECT Id FROM Form_Instance__c WHERE Proposal__c = : prop.Id LIMIT 1];
                
        // Update a currency field in GM Data.
        insert new Form_Component__c (
            Name = 'test component 1', 
            Type__c = 'currency',
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Target_object_name__c = 'GM_Data__c', 
            Target_field_name__c = 'Total_income_recent_completed_FY__c'
        );
        Form_Component__c comp1 = [SELECT Id FROM Form_Component__c LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = comp1.Id, Proposal__c = prop.Id, Data_text__c = '500.00');

        insert new Form_Component__c (
            Name = 'test component 2', 
            Type__c = 'percent',
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Target_object_name__c = 'GM_Data__c', 
            Target_field_name__c = 'Fraction_of_grant_to_Operations__c'
        );
        Form_Component__c comp2 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 2' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = comp2.Id, Proposal__c = prop.Id, Data_text__c = '.1');
        
        FormDataUpdateTargetsInvocable.UpdateTargetFields(new List<Id> {fi1.Id});
        Test.StopTest();
        
        gmData1 = [SELECT Id, Total_income_recent_completed_FY__c, Fraction_of_grant_to_Operations__c FROM GM_Data__c WHERE Id = : gmData1.Id];
        System.assertEquals(500.00, gmData1.Total_income_recent_completed_FY__c);
    }

    // Test field targeting for indicator components
    static testmethod void FormDataControllerTest3 () {
        // Build new records.
        BuildTestProposals.InitTestObjects(1, 1);
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Milestone__c (Proposal__c = prop.Id, Type__c = 'Report');
        Milestone__c milestone = [SELECT Id FROM Milestone__c LIMIT 1];
        
        Test.StartTest();
        insert new GM_Data__c (Proposal__c = prop.Id, Account__c = acc.Id, Total_income_recent_completed_FY__c = 1000);
        GM_Data__c gmData1 = [SELECT Id FROM GM_Data__c WHERE Total_income_recent_completed_FY__c = 1000 LIMIT 1];
        
        insert new Form__c (Name = 'test form', Type__c = 'Admin');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Proposal__c = prop.Id, Milestone__c = milestone.Id, GM_Data__c = gmData1.Id);
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c WHERE Proposal__c = : prop.Id LIMIT 1];
                
        // Build indicators and indicator form components.
        insert new Indicator__c (Name = 'test indicator 1', Requires_comment__c = true);
        Indicator__c i1 = [SELECT Id FROM Indicator__c WHERE Name = 'test indicator 1' LIMIT 1];
        insert new Indicator__c (Name = 'test indicator 2', Requires_number__c = true);
        Indicator__c i2 = [SELECT Id FROM Indicator__c WHERE Name = 'test indicator 2' LIMIT 1];
        insert new Form_Component__c (
            Name = 'test component 1', 
            Type__c = 'indicator', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Target_object_name__c = 'Indicator_Assign__c', 
            Indicator__c = i1.Id
        );
        Form_Component__c comp1 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 1' LIMIT 1];
        insert new Form_Component__c (
            Name = 'test component 2', 
            Type__c = 'indicator', 
            Form__c = f.Id, 
            Sort_number__c = 2, 
            Target_object_name__c = 'Indicator_Assign__c',  
            Indicator__c = i2.Id
        );
        Form_Component__c comp2 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 2' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp1.Id, Proposal__c = prop.Id, Data_textarea__c = 'testing 1 2 3');
        Form_Data__c fd1 = [SELECT Id FROM Form_Data__c LIMIT 1];

        FormDataUpdateTargetsInvocable.UpdateTargetFields(new List<Id> {fi.Id});
        Test.StopTest();
        
        // One indicator assign with comment inserted
        Indicator_Assign__c[] ias = [SELECT Id, Quantity__c, Comment__c FROM Indicator_Assign__c];
        System.assertEquals(1, ias.size());
        System.assertEquals('testing 1 2 3', ias[0].Comment__c);
        // Update that one and insert a new one
        fd1.Data_textarea__c = 'testing 1 2 3 4';
        update fd1;
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp2.Id, Proposal__c = prop.Id, Data_text__c = '12');
        FormDataController.updateTargetFields(fi.Id);
        ias = [SELECT Id, Quantity__c, Comment__c FROM Indicator_Assign__c];
        System.assertEquals(2, ias.size());
        System.assertEquals('testing 1 2 3 4', ias[0].Comment__c);
        System.assertEquals(12, ias[1].Quantity__c);
        // Delete the original indicator assign, by emptying its form data
        fd1.Data_textarea__c = null;
        update fd1;
        FormDataController.updateTargetFields(fi.Id);
        ias = [SELECT Id, Quantity__c, Comment__c FROM Indicator_Assign__c];
        System.assertEquals(1, ias.size());
    }

    // Test prefill
    static testmethod void FormDataControllerTest4 () {
        // Build new records.
        BuildTestProposals.InitTestObjects(1, 1);
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        prop.Date_received__c = Date.today();
        update prop;
        insert new Milestone__c (Proposal__c = prop.Id, Type__c = 'Report');
        Milestone__c milestone = [SELECT Id FROM Milestone__c LIMIT 1];
        
        Test.StartTest();
        insert new GM_Data__c (Proposal__c = prop.Id, Account__c = acc.Id, Total_income_recent_completed_FY__c = 1000);
        GM_Data__c gmData2 = [SELECT Id FROM GM_Data__c WHERE Proposal__c = :prop.Id LIMIT 1];
        
        insert new Form__c (Name = 'test form', Type__c = 'Admin');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Proposal__c = prop.Id, Milestone__c = milestone.Id, GM_Data__c = gmData2.Id);
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c WHERE Proposal__c = : prop.Id LIMIT 1];
                
        // Prefill from a currency field in GM Data.
        insert new Form_Component__c (
            Name = 'test component 1', 
            Type__c = 'currency', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Prefill_object_name__c = 'GM_Data__c', 
            Prefill_field_name__c = 'Total_income_recent_completed_FY__c'
        );
        Form_Component__c comp1 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 1' LIMIT 1];

        // Prefill from a checkbox field in Proposal.
        insert new Form_Phrase__c (Name = 'test phrase');
        Form_Phrase__c phr = [SELECT Id FROM Form_Phrase__c LIMIT 1];
        insert new Form_Component__c (
            Name = 'test component 2', 
            Type__c = 'checkbox', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Prefill_object_name__c = 'Proposal__c', 
            Prefill_field_name__c = 'Is_first_grant__c',
            Form_Phrase__c = phr.Id
        );
        Form_Component__c comp2 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 2' LIMIT 1];

        // Prefill from a date field in Proposal.
        insert new Form_Component__c (
            Name = 'test component 3', 
            Type__c = 'date', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Prefill_object_name__c = 'Proposal__c', 
            Prefill_field_name__c = 'Date_received__c',
            Form_Phrase__c = phr.Id
        );
        Form_Component__c comp3 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 3' LIMIT 1];

        FormDataPrefillFormInstanceInvocable.prefillFormInstance(new List<Id> {fi.Id});
        Test.StopTest();
        
        Form_Data__c fd3 = [SELECT Id, Data_text__c, Data_textarea__c FROM Form_Data__c WHERE Form_Component__c = : comp3.Id LIMIT 1];
        System.assertEquals(String.valueOf(System.today()), fd3.Data_text__c);
        Form_Data__c fd2 = [SELECT Id, Data_text__c, Data_textarea__c FROM Form_Data__c WHERE Form_Component__c = : comp2.Id LIMIT 1];
        System.assertEquals(null, fd2.Data_text__c);
        Form_Data__c fd1 = [SELECT Id, Data_text__c, Data_textarea__c FROM Form_Data__c WHERE Form_Component__c = : comp1.Id LIMIT 1];
        System.assertEquals('1000.00', fd1.Data_text__c);
    }

}