@isTest
public with sharing class ProposalControllerClassificationsTest {
    static testMethod void ProposalControllerClassificationsTest() {
        // Build one new proposal and account, plus some classifications and linked join records.
        BuildTestProposals.InitTestObjects(1, 1);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];
        BuildClassifications(p.Id, 2); // Second argument (number of classifications) should be at least 2!!
        // Build new standard controller.
        ApexPages.StandardController sc = new ApexPages.StandardController(p);

        Test.StartTest();
        // Gather classifications and assigns.
        List<Classification__c> cs = new List<Classification__c>(
            [SELECT Name FROM Classification__c ORDER BY Name]
        );
        List<Classification_Assign__c> cas = new List<Classification_Assign__c>(
            [
                SELECT classification__c, Classification__r.Name
                FROM Classification_Assign__c
                ORDER BY Classification__r.Name
            ]
        );
        // Build a new proposal controller, and check initial conditions.
        ProposalControllerClassifications pc = new ProposalControllerClassifications(
            sc
        );
        List<ProposalControllerClassifications.CCheckbox> pops = pc.getPopulations();
        system.debug('pops = ' + JSON.serialize(pops));
        pc.selectedIds = cs[0].Id + ';';
        system.debug('pc.selectedIds = ' + pc.selectedIds);
        system.assertEquals(pops.size(), cs.size()); // Have we built checkboxes for all classifications?
        system.assertEquals(cas.size(), 1); // Only one assign record.
        system.assertEquals(cas[0].classification__c, cs[0].Id); // Check that first classification is the one that's assigned.
        system.assert(
            pc.selectedIds.contains(String.valueof(cas[0].classification__c))
        ); // Is the one that we linked also the checkbox that's selected?
        // Change selection from first to second classification and save the change.
        pc.selectedIds = cs[1].Id + ';';
        PageReference pr = pc.doSave();
        // Re-fetch the assign records.
        cas = new List<Classification_Assign__c>(
            [
                SELECT classification__c, Classification__r.Name
                FROM Classification_Assign__c
                ORDER BY Classification__r.Name
            ]
        );
        // Swap should have caused one assign record to be created, and one deleted.
        system.assertEquals(cas.size(), 1); // Still only one assign record.
        system.assertEquals(cas[0].classification__c, cs[1].Id); // Now the second classification is the one that's assigned.
        Test.StopTest();
    }

    // Build desired number of classifications, and link first one to given proposal.
    // Note that the numClassifications parameter should be at least 2.
    static void BuildClassifications(Id propId, Integer numClassifications) {
        List<Classification__c> cs = new List<Classification__c>();
        for (Integer x = 0; x < numClassifications; x++) {
            cs.add(
                new Classification__c(
                    Name = 'ptest_class_' + String.valueOf(x),
                    Type__c = 'Population'
                )
            );
        }
        if (cs.size() > 0)
            insert cs;
        cs = new List<Classification__c>(
            [SELECT Id FROM Classification__c ORDER BY Name]
        );
        insert (new Classification_Assign__c(
            Classification__c = cs[0].Id,
            Proposal__c = propId
        ));
    }
}