@isTest
public class ProfileClassificationsCloneInvocableTest {
    static testMethod void ProfileClassificationsCloneInvocableTest() {
        // Build new records
        BuildTestProposals.InitTestObjects(1, 1);
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
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
        ProfileClassificationsCloneInvocable.CloneClassificationsRequest req = new ProfileClassificationsCloneInvocable.CloneClassificationsRequest();
        req.profileId = pId;
        req.proposalId = prop.Id;
        //ProfileClassificationsCloneInvocable.handleRequest(req);
        ProfileClassificationsCloneInvocable.cloneProfileClassifications(
            new List<ProfileClassificationsCloneInvocable.CloneClassificationsRequest>{
                req
            }
        );
        Integer numProfJoins = [
            SELECT COUNT()
            FROM Classification_Profile_Assign__c
            WHERE Profile__c = :pId
        ];
        Integer numPropJoins = [
            SELECT COUNT()
            FROM Classification_Assign__c
            WHERE Proposal__c = :prop.Id
        ];
        system.assertEquals(numProfJoins, numPropJoins);
        Test.StopTest();
    }
}