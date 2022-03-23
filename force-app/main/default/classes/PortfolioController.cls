public with sharing class PortfolioController {
    /**********************************
     * For use in Lightning components
     *********************************/

    @AuraEnabled
    public static Portfolio__c[] getPortfolios() {
        String objName = 'Portfolio__c';
        String[] fieldNames = Utilities.fieldNamesForObject(objName);
        String q =
            'SELECT ' +
            String.join(fieldNames, ', ') +
            ' FROM ' +
            objName;
        return Database.query(q);
    }

    @AuraEnabled
    public static Portfolio__c getPortfolio(Id recordId) {
        String objName = 'Portfolio__c';
        String[] fieldNames = Utilities.fieldNamesForObject(objName);
        String q =
            'SELECT ' +
            String.join(fieldNames, ', ') +
            ' FROM ' +
            objName +
            ' WHERE Id = : recordId';
        system.debug('apex get method for ' + objName + ': q = ' + q);
        return Database.query(q);
    }

    @AuraEnabled
    public static Proposal__c[] getPropsForPortfolio(Id portfolioId) {
        // Fetch proposals that are linked from the join records for the given portfolio.
        return [
            SELECT
                Id,
                Name,
                Account__c,
                Account__r.Name,
                Status_numeric__c,
                Amount_awarded__c,
                Date_awarded__c
            FROM Proposal__c
            WHERE
                Id IN (
                    SELECT Proposal__c
                    FROM Portfolio_Assignment__c
                    WHERE Portfolio__c = :portfolioId
                )
        ];
    }

    @AuraEnabled
    public static Portfolio__c savePortfolio(Portfolio__c record) {
        update record;
        return record;
    }
}