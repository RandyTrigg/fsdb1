@isTest
public with sharing class ProfileClassificationsInvocableTest {
    static testMethod void ProfileClassificationsInvocableTest() {
        // Build new records
        insert new Profile__c();
        Profile__c p = [SELECT Id FROM Profile__c LIMIT 1];
        Id pId = p.Id;
        insert new Classification_Category__c(Name = 'Age');
        Id ccId = [SELECT Id FROM Classification_Category__c LIMIT 1].Id;
        insert new Classification__c(
            Name = 'Girls',
            Type__c = 'Population',
            Classification_Category__c = ccId
        );
        Id cId = [SELECT Id FROM Classification__c LIMIT 1].Id;
        insert new Classification_Profile_Assign__c(
            Profile__c = pId,
            Classification__c = cId
        );
        insert new Classification__c(
            Name = 'Adult men',
            Type__c = 'Population',
            Classification_Category__c = ccId
        );

        Test.StartTest();
        // Update profile to have two joins.
        ProfileClassificationsInvocable.UpdateClassificationsRequest req = new ProfileClassificationsInvocable.UpdateClassificationsRequest();
        req.categoryName = 'Age';
        req.classificationType = 'Population';
        req.profileId = pId;
        req.selectedNames = 'Girls||AdultMen';
        ProfileClassificationsInvocable.updateProfileClassifications(
            new List<ProfileClassificationsInvocable.UpdateClassificationsRequest>{
                req
            }
        );
        Integer numJoins = [
            SELECT COUNT()
            FROM Classification_Profile_Assign__c
            WHERE Profile__c = :pId
        ];
        system.assertEquals(2, numJoins);
        // Update profile to have no joins.
        req.selectedNames = '||';
        ProfileClassificationsInvocable.handleRequest(req);
        numJoins = [
            SELECT COUNT()
            FROM Classification_Profile_Assign__c
            WHERE Profile__c = :pId
        ];
        system.assertEquals(0, numJoins);
        // Generate an error with bad classification type.
        req.classificationType = 'BADTYPE';
        req.selectedNames = 'Girls';
        try {
            ProfileClassificationsInvocable.handleRequest(req);
        } catch (exception myException) {
        }
        // Generate an error with unknown classification.
        req.classificationType = 'Population';
        req.selectedNames = 'BADCLASSIFICATION';
        try {
            ProfileClassificationsInvocable.handleRequest(req);
        } catch (exception myException) {
        }
        Test.StopTest();
    }
}