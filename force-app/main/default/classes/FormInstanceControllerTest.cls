@isTest
public class FormInstanceControllerTest {
    
    static testmethod void FormInstanceControllerTest1 () {
        // Build new records
        insert new Applicant__c (Name = 'Test applicant');
        Id applId = [SELECT Id FROM Applicant__c LIMIT 1].Id;
        insert new Form__c (Name = 'Profile_Initial', Type__c = 'Profile');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Applicant__c = applId, Date_submitted__c = date.today());
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c LIMIT 1];
        Id fiId = fi.Id;
        insert new Form_Section__c (Form__c = f.Id, Name = 'Test section', Sort_number__c = 1);
        Form_Section__c sec = [SELECT Id, Name FROM Form_Section__c LIMIT 1];
        system.debug('FormInstanceControllerTest1: sec = ' +JSON.serialize(sec));
        insert new Form_Item__c (Form_Section__c = sec.Id, Type__c = 'Standard', Sort_number__c = 1);
        Form_Item__c item = [SELECT Id FROM Form_Item__c LIMIT 1];
        insert new Form_Component__c (Form_Item__c = item.Id, Sort_number__c = 1, Clear_on_re_open__c = true);
        Form_Component__c comp = [SELECT Id FROM Form_Component__c LIMIT 1];
        insert new Form_Component__c (
            Name = 'test comp', 
            Form_Item__c = item.Id, 
            Sort_number__c = 2, 
            Group_Component__c = comp.Id
        );
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp.Id, Data_text__c = 'test form data');
        Form_Data__c fd = [SELECT Id FROM Form_Data__c LIMIT 1];

        // Build new standard set controller and select the new form instance(s).
        List<Form_Instance__c> fiList = new List<Form_Instance__c> {fi};
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(fiList);
        ssc.setSelected(fiList);
        FormInstanceController fic = new FormInstanceController (ssc);
        // Render form instance to text.
        fic.buildText();
        system.assert(fic.formInstanceText.contains('test form data'));

        // Clone the form and use that as the target form for the fi clone.
        FormClone.cloneForm(f.Id);
        Form__c fClone = [SELECT Id FROM Form__c WHERE Id <> : f.Id LIMIT 1];
        
        Test.StartTest();
        FormInstanceController.getFormInstance(fi.Id);
        FormInstanceController.getForm(f.Id);
        FormInstanceController.getSections(f.Id);
        FormInstanceController.getItems(sec.Id);
        FormInstanceController.getItemsForForm(f.Id);
        FormInstanceController.getComponents(item.Id);
        FormInstanceController.getComponentsForForm(f.Id);
        FormInstanceController.getComponentsInGroup(comp.Id);
        FormInstanceController.getFormData(comp.Id, fi.Id);
        FormInstanceController.getFormDataForFormInstance(fi.Id);
        
        Form_Instance__c fiClone = FormInstanceController.formInstanceClone(fiId);
        fiClone.Form__c = fClone.Id; // Rewire fiClone to the cloned form.
        update fiClone;
        system.assertEquals(applId, fiClone.Applicant__c);
        FormInstanceCloneInvocable.FICloneRequest cloneReq = new FormInstanceCloneInvocable.FICloneRequest();
        cloneReq.formInstanceIdA = fiId;
        cloneReq.formInstanceIdB = fiClone.Id;
        FormInstanceCloneInvocable.CloneFormInstanceFormData(new FormInstanceCloneInvocable.FICloneRequest[] {cloneReq});
        Test.StopTest();
        
        Form_Data__c[] fdsClone = [SELECT Id FROM Form_Data__c WHERE Form_Instance__c = : fiClone.Id];
        system.assertEquals(1, fdsClone.size());
        fiClone = [SELECT Id, Pre_populated_from__c FROM Form_Instance__c WHERE Id = : fiClone.Id];
        system.assertEquals(fi.Id, fiClone.Pre_populated_from__c);
        fd.Data_text__c = 'abc'; // Modify form data to force a diff result.
        update fd;
        String diffResults = FormInstanceController.computeDiffResults(fiClone.Id); // Compute form data differences.
        system.assertNotEquals(null, diffResults);
        
        FormInstanceController.DataManager dm = new FormInstanceController.DataManager(fiId);
        // Test re-opening the original form instance - the form data should be deleted.
        FormInstanceReopenInvocable.ReOpenRequest req = new FormInstanceReopenInvocable.ReOpenRequest ();
        req.formInstanceId = fiId;
        FormInstanceReopenInvocable.reOpen(new List<FormInstanceReopenInvocable.ReOpenRequest> {req});
        Form_Data__c[] fds = [SELECT Id FROM Form_Data__c WHERE Form_Instance__c = : fiId];
        system.assertEquals(0, fds.size());
    }
    
    // Test formInstanceMove method.
    static testmethod void FormInstanceControllerTest2 () {
        // Build new records
        insert new Applicant__c (Name = 'Test applicant');
        Applicant__c appl = [SELECT Id FROM Applicant__c LIMIT 1];
        insert new Form__c (Name = 'Profile_Initial', Type__c = 'Profile');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Applicant__c = appl.Id, Date_submitted__c = date.today());
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c LIMIT 1];
        insert new Form_Section__c (Form__c = f.Id, Name = 'Test section', Sort_number__c = 1);
        Form_Section__c sec = [SELECT Id FROM Form_Section__c LIMIT 1];
        insert new Form_Item__c (Form_Section__c = sec.Id, Type__c = 'Standard', Sort_number__c = 1);
        Form_Item__c item = [SELECT Id FROM Form_Item__c LIMIT 1];
        insert new Form_Component__c (Form_Item__c = item.Id, Sort_number__c = 1);
        Form_Component__c comp = [SELECT Id FROM Form_Component__c LIMIT 1];
        insert new Form_Component__c (Form_Item__c = item.Id, Sort_number__c = 2);
        Form_Component__c comp2 = [SELECT Id FROM Form_Component__c WHERE Sort_number__c = 2 LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp.Id);
        Form_Data__c fd = [SELECT Id FROM Form_Data__c LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp2.Id);
        // Clone the form and use that as the target form for the fi move.
        FormClone.cloneForm(f.Id);
        Form__c fClone = [SELECT Id FROM Form__c WHERE Id <> : f.Id LIMIT 1];
        // Remove the second form component to test that its form data is deleted in the move.
        Form_Component__c comp2Clone = [
            SELECT Id 
            FROM Form_Component__c 
            WHERE Form_Item__r.Form_Section__r.Form__c = : fClone.Id 
            AND Sort_number__c = 2 LIMIT 1
        ];
        delete comp2Clone;
        Test.StartTest();
        // Move the form instance to the cloned form.
        Map<Id, Id> formCompsMap = FormInstanceController.buildFormComponentMap(f.Id, fClone.Id);
        FormInstanceController.formInstanceMove(new List<Id> {fi.Id}, fClone.Id, formCompsMap);
        Test.StopTest();
        
        fi = [SELECT Id, Form__c FROM Form_Instance__c WHERE Id = : fi.Id];
        system.assertEquals(fClone.Id, fi.Form__c);
        Form_Data__c[] fds = [SELECT Id, Form_Component__c FROM Form_Data__c];
        system.assertEquals(1, fds.size()); // The second form data should have been deleted in the move.
        system.assertNotEquals(comp.Id, fds[0].Form_Component__c);
        
    }
    
    // Test formInstanceRelinkApplicant method.
    static testmethod void FormInstanceControllerTest2a () {
        // Build new records
        insert new Applicant__c (Name = 'Test applicant');
        Applicant__c appl = [SELECT Id FROM Applicant__c LIMIT 1];
        insert new Applicant__c (Name = 'Test applicant 1');
        Applicant__c appl1 = [SELECT Id FROM Applicant__c WHERE Name = 'Test applicant 1' LIMIT 1];
        insert new Form__c (Name = 'Profile_Initial', Type__c = 'Profile');
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Applicant__c = appl.Id, Date_submitted__c = date.today());
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c LIMIT 1];
        insert new Form_Section__c (Form__c = f.Id, Name = 'Test section', Sort_number__c = 1);
        Form_Section__c sec = [SELECT Id FROM Form_Section__c LIMIT 1];
        insert new Form_Item__c (Form_Section__c = sec.Id, Type__c = 'Standard', Sort_number__c = 1);
        Form_Item__c item = [SELECT Id FROM Form_Item__c LIMIT 1];
        insert new Form_Component__c (Form_Item__c = item.Id, Sort_number__c = 1);
        Form_Component__c comp = [SELECT Id FROM Form_Component__c LIMIT 1];
        insert new Form_Component__c (Form_Item__c = item.Id, Sort_number__c = 2);
        Form_Component__c comp2 = [SELECT Id FROM Form_Component__c WHERE Sort_number__c = 2 LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp.Id);
        Form_Data__c fd = [SELECT Id FROM Form_Data__c LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp2.Id);
        Test.StartTest();
        // Relink the form instance to the other applicant.
        FormInstanceController.formInstanceRelinkApplicant(new List<Id> {fi.Id}, appl1.Id);
        Test.StopTest();
        
        fi = [SELECT Id, Applicant__c FROM Form_Instance__c WHERE Id = : fi.Id];
        system.assertEquals(appl1.Id, fi.Applicant__c);
        // Ensure that the form data records moved over.
        Form_Data__c[] fds = [SELECT Id FROM Form_Data__c WHERE Applicant__c = : appl1.Id];
        system.assertEquals(2, fds.size());
        
    }
    
    // Test anonymize method.
    static testmethod void FormInstanceControllerTest2b () {
        // Build new records
        BuildTestProposals.InitTestObjects(1, 1);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Applicant__c (Name = 'Test applicant');
        Applicant__c appl = [SELECT Id FROM Applicant__c LIMIT 1];
        insert new Applicant__c (Name = 'Test anonymous applicant 1');
        Applicant__c appl1 = [SELECT Id FROM Applicant__c WHERE Name = 'Test anonymous applicant 1' LIMIT 1];
        insert new Form__c (Name = 'Profile_Initial', Type__c = 'Profile', Anonymous_applicant__c = appl1.Id);
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];   
        insert new Form_Section__c (Form__c = f.Id, Name = 'Test section', Sort_number__c = 1);
        Form_Section__c sec = [SELECT Id FROM Form_Section__c LIMIT 1];
        insert new Form_Item__c (Form_Section__c = sec.Id, Type__c = 'Standard', Sort_number__c = 1);
        Form_Item__c item = [SELECT Id FROM Form_Item__c LIMIT 1];
        insert new Form_Phrase__c (Name = 'test checkbox');
        Form_Phrase__c phrase = [SELECT Id FROM Form_Phrase__c LIMIT 1];
        insert new Form_Component__c (Form_Item__c = item.Id, Sort_number__c = 1);
        Form_Component__c comp = [SELECT Id FROM Form_Component__c LIMIT 1];
        insert new Form_Component__c (
            Form_Item__c = item.Id, 
            Sort_number__c = 2, 
            Prefill_object_name__c = 'Proposal__c',
            Prefill_field_name__c = 'Is_first_grant__c', 
            Type__c = 'checkbox',
            Form_Phrase__c = phrase.Id
        );
        Form_Component__c compPrefill = [SELECT Id FROM Form_Component__c LIMIT 1];
        Test.StartTest();
        // Creating the new form instance should trigger prefill in an auto-constructed form data record.
        insert new Form_Instance__c (Form__c = f.Id, Applicant__c = appl.Id, Date_submitted__c = date.today(), Proposal__c = p.Id);
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c LIMIT 1];
        
        Test.StopTest();
        Form_Data__c[] fds = [SELECT Id, Applicant__c, Form_Instance__c, Data_text__c FROM Form_Data__c];
        system.assertEquals(1, fds.size());
        system.assertEquals(null, fds[0].Data_text__c); // Blank because proposal is not a grant.
        // Now flip form data value to true.
        fds[0].Data_text__c = 'true';
        update fds[0];
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp.Id, Data_text__c = 'aaa');
        Form_Data__c fd = [SELECT Id, Form_Component__c FROM Form_Data__c LIMIT 1];
        insert new Form_Log_Entry__c (Form_Instance__c = fi.Id);
        Form_Log_Entry__c fle = [SELECT Id FROM Form_Log_Entry__c LIMIT 1];
        // Anonymize the form instance (and form data) to the other applicant.
        FormInstanceController.anonymize(fi.Id, appl1.Id);
        
        Form_Instance__c[] fis = [SELECT Id, Applicant__c, Proposal__c FROM Form_Instance__c];
        system.assertEquals(1, fis.size()); // Only the cloned form instance is left.
        Form_Instance__c fi1 = fis[0];
        system.assertEquals(appl1.Id, fi1.Applicant__c);
        system.assertEquals(null, fi1.Proposal__c);
        // Ensure that only the two form data records remain.
        fds = [SELECT Id, Applicant__c, Form_Instance__c, Data_text__c, Data_textarea__c FROM Form_Data__c];
        system.assertEquals(2, fds.size());
        Form_Data__c fd0 = fds[0];
        system.assertNotEquals(null, fd0.Data_textarea__c); // Should contain a notification that value of form data is incorrect.
        system.debug('FormInstanceControllerTest2b: fd0.Data_textarea__c = ' +fd0.Data_textarea__c);
        Form_Data__c fd1 = fds[1];
        system.assertEquals(appl1.Id, fd1.Applicant__c);
        system.assertEquals(fi1.Id, fd1.Form_Instance__c);
        system.assertEquals('aaa', fd1.Data_text__c);
        // No form log entries remain.
        Form_Log_Entry__c[] fles = [SELECT Id FROM Form_Log_Entry__c];
        system.assertEquals(0, fles.size());
        // Invoke invocable class for coverage.
        FormInstanceAnonymizeInvocable.Request req = new FormInstanceAnonymizeInvocable.Request ();
        req.formInstanceId = fi1.Id;
        req.applicantId = appl1.Id;
        FormInstanceAnonymizeInvocable.anonymize(new List<FormInstanceAnonymizeInvocable.Request> {req});
        
        // Invoke from schedule classes for coverage, also for batch class.
        insert new Form_Instance__c (Form__c = f.Id, Applicant__c = appl.Id, Date_submitted__c = date.today(), Proposal__c = p.Id);
        Database.executeBatch(new FormInstanceAnonymizeBatch(), 5);
        System.schedule('AnonymizeTest', '0 0 0 15 3 ? 2022', new FormInstanceAnonymizeSchedule());
    }
    
    // Test delete of expired anonymizing form instances.
    static testmethod void FormInstanceControllerTest2c () {
        // Build new records
        BuildTestProposals.InitTestObjects(1, 1);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Applicant__c (Name = 'Test applicant');
        Applicant__c appl = [SELECT Id FROM Applicant__c LIMIT 1];
        insert new Applicant__c (Name = 'Test anonymous applicant 1');
        Applicant__c appl1 = [SELECT Id FROM Applicant__c WHERE Name = 'Test anonymous applicant 1' LIMIT 1];
        insert new Form__c (Name = 'Profile_Initial', Type__c = 'Profile', Anonymous_applicant__c = appl1.Id);
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];   
        insert new Form_Instance__c (
            Form__c = f.Id, 
            Applicant__c = appl.Id, 
            Date_submitted__c = null,
            Expiration_date__c = date.today().addDays(-10), // Expired more than a week ago
            Proposal__c = p.Id
        );
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c LIMIT 1];
        insert new Form_Section__c (Form__c = f.Id, Name = 'Test section', Sort_number__c = 1);
        Form_Section__c sec = [SELECT Id FROM Form_Section__c LIMIT 1];
        insert new Form_Item__c (Form_Section__c = sec.Id, Type__c = 'Standard', Sort_number__c = 1);
        Form_Item__c item = [SELECT Id FROM Form_Item__c LIMIT 1];
        insert new Form_Component__c (Form_Item__c = item.Id, Sort_number__c = 1);
        Form_Component__c comp = [SELECT Id FROM Form_Component__c LIMIT 1];
        insert new Form_Data__c (Form_Instance__c = fi.Id, Form_Component__c = comp.Id, Data_text__c = 'aaa');
        Form_Data__c fd = [SELECT Id, Form_Component__c FROM Form_Data__c LIMIT 1];
        insert new Form_Log_Entry__c (Form_Instance__c = fi.Id);
        Form_Log_Entry__c fle = [SELECT Id FROM Form_Log_Entry__c LIMIT 1];
        
        Test.StartTest();
        // Delete form instance and child records.
        FormInstanceController.deleteExpiredAnonymizingFormInstances();
        Test.StopTest();
        
        // Check that records are gone.
        Form_Instance__c[] fis = [SELECT Id FROM Form_Instance__c];
        system.assertEquals(0, fis.size()); 
        Form_Data__c[] fds = [SELECT Id FROM Form_Data__c];
        system.assertEquals(0, fds.size());
        Form_Log_Entry__c[] fles = [SELECT Id FROM Form_Log_Entry__c];
        system.assertEquals(0, fles.size());
        
        // Invoke from schedule class for coverage.
        System.schedule('AnonymizeTest', '0 0 0 15 3 ? 2022', new FormInstanceAnonymizeSchedule());
    }
    
    // Test auto-sending reminder/overdue emails.
    static testmethod void FormInstanceControllerTest3 () {
        // Build new records
        insert new Template__c (Name = 'Prop template', Source_object__c = 'Proposal__c');
        Template__c t1 = [SELECT Id FROM Template__c LIMIT 1];
        insert new Template__c (Name = 'GranteeReport template', Source_object__c = 'Grantee_Report__c');
        Template__c t2 = [SELECT Id FROM Template__c WHERE Source_object__c = 'Grantee_Report__c' LIMIT 1];
        insert new Program__c (Name = 'Program test');
        Program__c prog = [SELECT Id FROM Program__c LIMIT 1];
        insert new Account (Name = 'test account', GM_Program__c = prog.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Applicant__c (Name = 'Test applicant DONOTUSE', Account__c = a.Id);
        Applicant__c appl = [SELECT Id FROM Applicant__c LIMIT 1];
        insert new Proposal__c (
            Applicant__c = appl.Id, 
            Account__c = a.Id, 
            Proposal_submit_deadline__c = Date.today()-5,
            Date_awarded__c = Date.today()
        );
        Proposal__c p = [SELECT Id, Status_numeric__c FROM Proposal__c LIMIT 1];
        
        Test.StartTest();
        ProposalUpdate.updateProposal(p.Id, true); // Update prop status and build grantee report
        Test.StopTest();
        
        // Build payment and update grantee report.
        insert new Payment__c (Proposal__c = p.Id, Payment_ref__c = 'ck1', Date_paid__c = Date.today(), Date_payment_letter_sent__c = Date.today());
        Payment__c pay = [SELECT Id FROM Payment__c LIMIT 1];
        PaymentController.buildGranteeReports(pay.Id);
        Grantee_Report__c g = [SELECT Id, Date_due__c FROM Grantee_Report__c LIMIT 1];
        ProposalUpdate.updateProposal(p.Id, true); // Update prop status.
        p = [SELECT Id, Status_numeric__c FROM Proposal__c LIMIT 1]; // Get updated status.
        system.debug('FormInstanceControllerTest3: p.Status_numeric__c = ' +p.Status_numeric__c+ '; g = ' +JSON.serialize(g));
        insert new Form__c (Name = 'Prop Application', Type__c = 'Application', Overdue_template__c = t1.Id, Reminder_overdue_number_of_days__c = '-10, 5');
        Form__c f1 = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form__c (
            Name = 'Grantee Report Qs', 
            Type__c = 'Reporting', 
            Reminder_template__c = t2.Id, 
            Reminder_overdue_number_of_days__c = String.valueOf(g.Date_due__c.daysBetween(Date.today()))
        );
        Form__c f2 = [SELECT Id FROM Form__c WHERE Name = 'Grantee Report Qs' LIMIT 1];
        insert new Form_Instance__c (Form__c = f1.Id, Applicant__c = appl.Id, Proposal__c = p.Id);
        insert new Form_Instance__c (Form__c = f2.Id, Applicant__c = appl.Id, Proposal__c = p.Id, Grantee_Report__c = g.Id);
        ProposalUpdate.updateProposal(p.Id, true); // Update prop status.
        // Now run the code to generate and email reminders/overdues.
        RemindersOverduesInvocable.emailRemindersOverdues(new List<Boolean> {true});
        // Should have generated one prop reminder and one grantee report overdue letter.
        Letter__c[] propLets = [SELECT Id, Template__c FROM Letter__c WHERE Grantee_Report__c = null];
        system.assertEquals(1, propLets.size());
        system.assertEquals(t1.Id, propLets[0].Template__c);
        Letter__c[] grepLets = [SELECT Id, Template__c FROM Letter__c WHERE Grantee_Report__c <> null];
        system.assertEquals(1, grepLets.size());
        system.assertEquals(t2.Id, grepLets[0].Template__c);
        
        // Schedule test of reminders/overdues. 
        String cronExp = '0 0 0 15 3 ? 2022';
        String jobId = System.schedule('ScheduleApexClassTest', cronExp, new RemindersOverduesSchedule());
    }

    // Test withdraw props with inactive form instances.
    static testmethod void FormInstanceControllerTest4 () {
        // Build new records
        insert new Program__c (Name = 'Program test');
        Program__c prog = [SELECT Id FROM Program__c LIMIT 1];
        insert new Account (Name = 'test account', GM_Program__c = prog.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Applicant__c (Name = 'Test applicant DONOTUSE', Account__c = a.Id);
        Applicant__c appl = [SELECT Id FROM Applicant__c LIMIT 1];
        insert new Proposal__c (
            Applicant__c = appl.Id, 
            Account__c = a.Id
        );
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Form__c (Name = 'Test form', Type__c = 'Admin', Inactivity_threshold_in_days__c = -1); // Negative threshold since recent save date must be today.
        Form__c f = [SELECT Id FROM Form__c LIMIT 1];
        insert new Form_Instance__c (Form__c = f.Id, Applicant__c = appl.Id, Proposal__c = p.Id);
        Form_Instance__c fi = [SELECT Id FROM Form_Instance__c LIMIT 1];
        insert new Form_Log_Entry__c (Form_Instance__c = fi.Id, Operation__c = 'Save', Applicant__c = appl.Id);
        ProposalUpdate.updateProposal(p.Id); // Update prop status.
        
        Test.StartTest();
        // Now run the code to withdraw props for inactive form instances.
        FormInstanceController.withdrawPropsWithInactiveFormInstances();
        Test.StopTest();
        
        // The proposal should now be withdrawn.
        p = [SELECT Id, Date_request_withdrawn__c FROM Proposal__c LIMIT 1];
        system.assertEquals(Date.today(), p.Date_request_withdrawn__c);  
        // Exercise the schedulable class.
        String cronExp = '0 0 0 15 3 ? 2022';
        String jobId = System.schedule('ScheduleApexClassTest', cronExp, new FormInstanceWithdrawPropsSchedule());
    }

}