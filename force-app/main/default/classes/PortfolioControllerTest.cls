@isTest
public with sharing class PortfolioControllerTest {
    /**********************************
     * Test the component-related methods
     * *******************************/

    static testMethod void PortfolioControllerTest() {
        // Build new records
        insert new Portfolio__c(Name = 'Test portfolio');
        Id portId = [
            SELECT Id
            FROM Portfolio__c
            WHERE Name = 'Test portfolio'
            LIMIT 1
        ]
        .Id;
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'test account',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Id aId = [SELECT Id FROM Account LIMIT 1].Id;
        insert new Proposal__c(Account__c = aId);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new Portfolio_Assignment__c(
            Portfolio__c = portId,
            Proposal__c = p.Id
        );

        Test.StartTest();
        List<Portfolio__c> ports = PortfolioController.getPortfolios();
        Portfolio__c port = PortfolioController.getPortfolio(portId);
        PortfolioController.savePortfolio(port);
        List<Proposal__c> props = PortfolioController.getPropsForPortfolio(
            portId
        );
        system.assertEquals(ports.size(), 1);
        system.assertEquals(props.size(), 1);
        system.assertEquals((String) portId, port.Id);
        Test.StopTest();
    }
}