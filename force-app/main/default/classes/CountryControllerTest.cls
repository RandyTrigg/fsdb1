@isTest
public class CountryControllerTest {
    static testMethod void CountryControllerTest() {
        // Build new records
        ProposalUpdateTest.buildTemplateMacros();
        insert new Region__c(Name = 'test region');
        Id rId = [SELECT Id FROM Region__c LIMIT 1].Id;
        insert new Country__c(Name = 'test country', Region__c = rId);
        Id cId = [SELECT Id FROM Country__c LIMIT 1].Id;
        insert new Account(
            Name = 'test account',
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'),
            GM_country__c = cId,
            GM_region__c = rId
        );
        Id aId = [SELECT Id FROM Account LIMIT 1].Id;
        Date date1 = Date.today();
        Date date2 = date1.addDays(1);
        insert new Proposal__c(
            Account__c = aId,
            Date_awarded__c = date1,
            Amount_awarded__c = 100
        );
        insert new Proposal__c(
            Account__c = aId,
            Date_awarded__c = date2,
            Amount_awarded__c = 50
        );
        Proposal__c[] ps = [SELECT Id, Country__c FROM Proposal__c];
        //system.debug('CountryControllerTest: ps = ' + JSON.serialize(ps));
        ProposalUpdate.updateProposal(ps[0].Id, true);
        ProposalUpdate.updateProposal(ps[1].Id, true);
        insert new Profile__c();

        Test.StartTest();
        CountryController.updateStatsFields(new List<Id>{ cId });
        Country__c c = [
            SELECT
                Id,
                Num_proposals__c,
                Num_grants__c,
                Num_profiles__c,
                Date_of_first_grant__c,
                Date_of_last_grant__c,
                Total_awarded__c
            FROM Country__c
            WHERE Id = :cId
            LIMIT 1
        ];
        system.assertEquals(2, c.Num_proposals__c);
        system.assertEquals(2, c.Num_grants__c);
        system.assertEquals(date1, c.Date_of_first_grant__c);
        system.assertEquals(date2, c.Date_of_last_grant__c);
        system.assertEquals(150, c.Total_awarded__c);

        // Schedule test of country stats update.
        String cronExp = '0 0 0 15 3 ?';
        String jobId = System.schedule(
            'ScheduleApexClassTest',
            cronExp,
            new CountryStatsSchedule()
        );

        Test.StopTest();
    }
}