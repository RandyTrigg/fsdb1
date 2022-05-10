@isTest
public class CustomReqsControllerTest {
    static testMethod void CustomReqsControllerTest1() {
        insert new Custom_Reqs__c(Name = 'test custom reqs');
        Custom_Reqs__c cr = [SELECT Id FROM Custom_Reqs__c LIMIT 1];
        insert new Milestone_Spec__c(
            Custom_Reqs__c = cr.Id,
            Type__c = 'Report',
            Num_months_due__c = 12
        );
        Milestone_Spec__c r = [SELECT Id FROM Milestone_Spec__c LIMIT 1];
        insert new Template__c(Name = 'test template');
        Template__c t = [SELECT Id FROM Template__c LIMIT 1];
        insert new Template_Piece__c(
            Name = 'test template piece',
            Custom_Reqs__c = cr.Id,
            Template__c = t.Id
        );
        Template_Piece__c tp = [SELECT Id FROM Template_Piece__c LIMIT 1];

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(cr);
        customReqsController crc = new customReqsController(sc);
        crc.deepClone();
        crc.doCancel();
        Test.stopTest();

        Custom_Reqs__c crNew = [
            SELECT Id
            FROM Custom_Reqs__c
            WHERE Name = 'test custom reqs (Copy)'
            LIMIT 1
        ];
        system.assertNotEquals(null, crNew);
        system.assertNotEquals(cr.Id, crNew.Id);
        Milestone_Spec__c[] rsNew = [
            SELECT Id
            FROM Milestone_Spec__c
            WHERE Custom_Reqs__c = :crNew.Id
        ];
        system.assertEquals(1, rsNew.size());
        system.assertNotEquals(r.Id, rsNew[0].Id);
        Template_Piece__c[] tpsNew = [
            SELECT Id, Revise__c
            FROM Template_Piece__c
            WHERE Custom_Reqs__c = :crNew.Id
        ];
        system.assertEquals(1, tpsNew.size());
        system.assertNotEquals(tp.Id, tpsNew[0].Id);
        system.assert(tpsNew[0].Revise__c);
    }
}