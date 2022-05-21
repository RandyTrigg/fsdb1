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
        // Update country field in Account.
        insert new Form_Component__c (
            Name = 'test component 3', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Target_object_name__c = 'Account', 
            Target_field_name__c = 'GM_country__c',
            Form_Picklist__c = plist.Id
        );
        Form_Component__c comp3 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 3' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = comp3.Id, Data_text__c = 'Côte d\'Ivoire');
        // Update classification joins in Profile.
        insert new Form_Component__c (
            Name = 'Populations', 
            Form__c = f.Id, 
            Sort_number__c = 1
        );
        Form_Component__c compPop = [SELECT Id FROM Form_Component__c WHERE Name = 'Populations' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = compPop.Id, Data_text__c = 'Girls||YoungWomen');
        // Update geo field in profile.
        insert new Form_Component__c (
            Name = 'TargetGeographicArea', 
            Form__c = f.Id, 
            Sort_number__c = 1
        );
        Form_Component__c compGeo = [SELECT Id FROM Form_Component__c WHERE Name = 'TargetGeographicArea' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = compGeo.Id, Data_text__c = 'District');
        // Update org type field in profile.
        insert new Form_Component__c (
            Name = 'OrgTypeSelect', 
            Form__c = f.Id, 
            Sort_number__c = 1
        );
        Form_Component__c compOrgType = [SELECT Id FROM Form_Component__c WHERE Name = 'OrgTypeSelect' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = compOrgType.Id, Data_text__c = 'OrgTypeGrassroots');
        
        Test.StartTest();
        FormDataUpdateTargetsInvocable.UpdateTargetFields(new List<Id> {fi1.Id});
        // Run batch code for coverage.
        String q = 'SELECT Id FROM Form_Instance__c';
        Database.executeBatch(new FormDataUpdateTargetsBatch(q), 10);
        Test.StopTest();
        
        // Check that target fields were updated.
        appl = [SELECT Id, Keep_confidential__c, Group_name__c, Country__c FROM Applicant__c LIMIT 1];
        System.assert(appl.Keep_confidential__c);
        System.assertEquals('group name', appl.Group_name__c);
        System.assertEquals(c.Id, appl.Country__c);
        prof = [SELECT Id, Rank_ZV__c, Organization_type__c, Geo_target_area_District__c FROM Profile__c LIMIT 1];
        System.assertEquals(1, prof.Rank_ZV__c);
        System.assertEquals('Grassroots', prof.Organization_type__c);
        System.assertEquals(true, prof.Geo_target_area_District__c);
    }

    // Test field targeting to gmdata
    static testmethod void FormDataControllerTest2 () {
        // Build new records.
        
        BuildTestProposals.InitTestObjects(1, 1);
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Milestone__c (Proposal__c = prop.Id, Which_yearly__c = 1, Type__c = 'Yearly');
        Milestone__c milestone = [SELECT Id FROM Milestone__c LIMIT 1];
        // First gm data is in the "new" style: proposal links TO the gm data
        insert new GM_Data__c ();
        GM_Data__c gmData1 = [SELECT Id FROM GM_Data__c LIMIT 1];
        prop.GM_Data__c = gmData1.Id;
        update prop;
        
        Test.StartTest();
        // Second gm data is in the "old" style: grantee report links FROM the gm data 
        insert new GM_Data__c (Proposal__c = prop.Id, Milestone__c = milestone.Id, Account__c = acc.Id);
        GM_Data__c gmData2 = [SELECT Id FROM GM_Data__c WHERE Milestone__c = : milestone.Id LIMIT 1];
        
        insert new Form__c (Name = 'test form', Type__c = 'Admin');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Proposal__c = prop.Id, Milestone__c = null);
        Form_Instance__c fi1 = [SELECT Id FROM Form_Instance__c WHERE Proposal__c = : prop.Id LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Proposal__c = prop.Id, Milestone__c = milestone.Id);
        Form_Instance__c fi2 = [SELECT Id FROM Form_Instance__c WHERE Milestone__c = : milestone.Id LIMIT 1];
                
        // Update a currency field in GM Data.
        insert new Form_Component__c (
            Name = 'test component 1', 
            Type__c = 'currency',
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Target_object_name__c = 'GM_Data__c', 
            Target_field_name__c = 'Average_grant_size__c'
        );
        Form_Component__c comp1 = [SELECT Id FROM Form_Component__c LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi1.Id, Form_Component__c = comp1.Id, Proposal__c = prop.Id, Data_text__c = '500.00');
        insert new Form_Data__c (Form_Instance__c = fi2.Id, Form_Component__c = comp1.Id, Proposal__c = prop.Id, Data_text__c = '1000.00');

        insert new Form_Component__c (
            Name = 'test component 2', 
            Type__c = 'percent',
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Target_object_name__c = 'GM_Data__c', 
            Target_field_name__c = 'Fraction_of_grant_to_Operations__c'
        );
        Form_Component__c comp2 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 2' LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi2.Id, Form_Component__c = comp2.Id, Proposal__c = prop.Id, Data_text__c = '.1');
        
        FormDataUpdateTargetsInvocable.UpdateTargetFields(new List<Id> {fi1.Id, fi2.Id});
        Test.StopTest();
        
        gmData1 = [SELECT Id, Average_grant_size__c, Fraction_of_grant_to_Operations__c FROM GM_Data__c WHERE Id = : gmData1.Id];
        System.assertEquals(500.00, gmData1.Average_grant_size__c);
        gmData2 = [SELECT Id, Average_grant_size__c, Fraction_of_grant_to_Operations__c FROM GM_Data__c WHERE Milestone__c = : milestone.Id LIMIT 1];
        System.assertEquals(1000.00, gmData2.Average_grant_size__c);
        System.assertEquals(.1, gmData2.Fraction_of_grant_to_Operations__c);
    }

    // Test field targeting for indicator components
    static testmethod void FormDataControllerTest3 () {
        // Build new records.
        BuildTestProposals.InitTestObjects(1, 1);
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Milestone__c (Proposal__c = prop.Id, Which_yearly__c = 1, Type__c = 'Yearly');
        Milestone__c milestone = [SELECT Id FROM Milestone__c LIMIT 1];
        
        Test.StartTest();
        insert new GM_Data__c (Proposal__c = prop.Id, Milestone__c = milestone.Id, Account__c = acc.Id, Average_grant_size__c = 1000);
        GM_Data__c gmData1 = [SELECT Id FROM GM_Data__c WHERE Milestone__c = : milestone.Id LIMIT 1];
        
        insert new Form__c (Name = 'test form', Type__c = 'Admin');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Proposal__c = prop.Id, Milestone__c = milestone.Id, GM_Data__c = gmData1.Id);
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c WHERE Proposal__c = : prop.Id LIMIT 1];
                
        // Build indicators and indicator form components.
        insert new Indicator__c (Name = 'test indicator 1', Requires_comment__c = true, GM_Data_field_name__c = 'Contrib_Grassroots_base__c');
        Indicator__c i1 = [SELECT Id FROM Indicator__c WHERE Name = 'test indicator 1' LIMIT 1];
        insert new Indicator__c (Name = 'test indicator 2', Requires_number__c = true, GM_Data_field_name__c = 'Contrib_Grassroots_base__c');
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
        // GM data's checkbox corresponding to indicator should be checked
        gmData1 = [SELECT Id, Contrib_Grassroots_base__c FROM GM_Data__c WHERE Id = : gmData1.Id];
        System.assert(gmData1.Contrib_Grassroots_base__c);
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
        insert new Milestone__c (Proposal__c = prop.Id, Which_yearly__c = 1, Type__c = 'Yearly');
        Milestone__c milestone = [SELECT Id FROM Milestone__c LIMIT 1];
        
        Test.StartTest();
        insert new GM_Data__c (Proposal__c = prop.Id, Milestone__c = milestone.Id, Account__c = acc.Id, Average_grant_size__c = 1000);
        GM_Data__c gmData2 = [SELECT Id FROM GM_Data__c WHERE Milestone__c = : milestone.Id LIMIT 1];
        
        insert new Form__c (Name = 'test form', Type__c = 'Admin');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Section__c (Name = 'test form section', Form__c = f.Id, Sort_number__c = 1);
        Form_Section__c sec = [SELECT Id FROM Form_Section__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Proposal__c = prop.Id, Milestone__c = milestone.Id, GM_Data__c = gmData2.Id);
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c WHERE Proposal__c = : prop.Id LIMIT 1];
                
        // Prefill from a currency field in GM Data.
        insert new Form_Component__c (
            Name = 'test component 1', 
            Type__c = 'currency', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Prefill_object_name__c = 'GM_Data__c', 
            Prefill_field_name__c = 'Average_grant_size__c'
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

        // Prefill from a numeric field in Proposal.
        insert new Form_Component__c (
            Name = 'test component 3', 
            Type__c = 'text', 
            Form__c = f.Id, 
            Sort_number__c = 1, 
            Prefill_object_name__c = 'Proposal__c', 
            Prefill_field_name__c = 'Num_years__c',
            Form_Phrase__c = phr.Id
        );
        Form_Component__c comp3 = [SELECT Id FROM Form_Component__c WHERE Name = 'test component 3' LIMIT 1];

        FormDataPrefillFormInstanceInvocable.prefillFormInstance(new List<Id> {fi.Id});
        Test.StopTest();
        
        Form_Data__c fd1 = [SELECT Id, Data_text__c, Data_textarea__c FROM Form_Data__c WHERE Form_Component__c = : comp1.Id LIMIT 1];
        Form_Data__c fd2 = [SELECT Id, Data_text__c, Data_textarea__c FROM Form_Data__c WHERE Form_Component__c = : comp2.Id LIMIT 1];
        Form_Data__c fd3 = [SELECT Id, Data_text__c, Data_textarea__c FROM Form_Data__c WHERE Form_Component__c = : comp3.Id LIMIT 1];
        System.assertEquals('1000.00', fd1.Data_text__c);
        System.assertEquals(null, fd2.Data_text__c);
        System.assertEquals('1', fd3.Data_text__c);
    }

}