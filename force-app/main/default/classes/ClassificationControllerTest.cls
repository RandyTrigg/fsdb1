@isTest
public class ClassificationControllerTest {
    static testmethod void ClassificationControllerTest1 () {
        // Build new records
        insert new Region__c (Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account (
            Name = 'test account', 
            GM_Region__c = reg.Id, 
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
            );
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Profile__c (Account__c = a.Id);
        Profile__c pr = [SELECT Id FROM Profile__c LIMIT 1];
        insert new Proposal__c (Account__c = a.Id, Profile__c = pr.Id);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Classification__c (Name = 'Test Issue 1', Type__c = 'Issue');
        Classification__c ci1 = [SELECT Id FROM Classification__c WHERE Name = 'Test Issue 1' LIMIT 1];
        insert new Classification__c (Name = 'Test Issue 2', Type__c = 'Issue');
        Classification__c ci2 = [SELECT Id FROM Classification__c WHERE Name = 'Test Issue 2' LIMIT 1];
        insert new Classification__c (Name = 'Test Issue 3', Type__c = 'Issue');
        Classification__c ci3 = [SELECT Id FROM Classification__c WHERE Name = 'Test Issue 3' LIMIT 1];
        insert new Classification_Assign__c (Proposal__c = p.Id, Classification__c = ci1.Id);
        insert new Classification_Profile_Assign__c (Profile__c = pr.Id, Classification__c = ci1.Id);
        insert new Classification_Profile_Assign__c (Profile__c = pr.Id, Classification__c = ci2.Id);
        insert new Classification_Profile_Assign__c (Profile__c = pr.Id, Classification__c = ci3.Id);

        Test.StartTest();
        ClassificationController.updateClassificationAssigns(p.Id, 'Issue', new List<String>{'Test Issue 1', 'Test Issue 2'});
        ClassificationController.updateClassificationAssigns(pr.Id, 'Issue', new List<String>());
        Test.stopTest();

        // Check that only one new assign added to proposal.
        Classification_Assign__c[] propClassAssigns = [SELECT Id FROM Classification_Assign__c];
        system.assertEquals(2, propClassAssigns.size());
        // Check that all assigns for the profile are removed.
        Classification_Profile_Assign__c[] profClassAssigns = [SELECT Id FROM Classification_Profile_Assign__c];
        system.assertEquals(0, profClassAssigns.size());
    }

    // Test updating from vertical bar separated list of form phrase names
    static testmethod void ClassificationControllerTest2 () {
        // Build new records
        insert new Region__c (Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account (
            Name = 'test account', 
            GM_Region__c = reg.Id, 
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
            );
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Profile__c (Account__c = a.Id);
        Profile__c pr = [SELECT Id FROM Profile__c LIMIT 1];
        insert new Proposal__c (Account__c = a.Id, Profile__c = pr.Id);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Classification__c (Name = 'Test Issue 1', Type__c = 'Issue');
        Classification__c ci1 = [SELECT Id FROM Classification__c WHERE Name = 'Test Issue 1' LIMIT 1];
        insert new Classification__c (Name = 'Test Issue 2', Type__c = 'Issue');
        Classification__c ci2 = [SELECT Id FROM Classification__c WHERE Name = 'Test Issue 2' LIMIT 1];
        insert new Form_Phrase__c (Name = 'TestIssue1');
        Form_Phrase__c fp1 = [SELECT Id FROM Form_Phrase__c WHERE Name = 'TestIssue1' LIMIT 1];
        insert new Form_Phrase_Translation__c (Form_Phrase__c = fp1.Id, Language__c = 'English', Text__c = 'Test Issue 1');
        insert new Form_Phrase__c (Name = 'TestIssue2');
        Form_Phrase__c fp2 = [SELECT Id FROM Form_Phrase__c WHERE Name = 'TestIssue2' LIMIT 1];
        insert new Form_Phrase_Translation__c (Form_Phrase__c = fp2.Id, Language__c = 'English', Text__c = 'Test Issue 2');

        Test.StartTest();
        ClassificationController.updateClassificationAssignsFromFormPhrases(p.Id, 'Issue', 'TestIssue1|TestIssue2');
        Test.stopTest();
        
        // Check that two new assigns were added to the proposal.
        Classification_Assign__c[] propClassAssigns = [SELECT Id FROM Classification_Assign__c];
        system.assertEquals(2, propClassAssigns.size());
    }

}