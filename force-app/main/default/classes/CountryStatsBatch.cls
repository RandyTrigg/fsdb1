global class CountryStatsBatch implements Database.Batchable<sObject>{
    global final String query;
   
    global CountryStatsBatch(String q){
        system.debug('CountryStatsBatch create: q = ' +q);
        query = q;
    }
   
    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('CountryStatsBatch start: query = ' +query);
        return Database.getQueryLocator(query);
    }
   
    global void execute(Database.BatchableContext BC, List<sObject> scope){
        system.debug('CountryStatsBatch execute: scope = ' +JSON.serialize(scope));
        Map<Id, Country__c> cMap = new Map<Id, Country__c>((List<Country__c>) scope);
        // Update stats fields in countries in scope.
        CountryController.updateStatsFields(new List<Id> (cMap.keySet()));
    }
    
    global void finish(Database.BatchableContext BC){
        AsyncApexJob a = [Select Id, Status, NumberOfErrors, JobItemsProcessed,
                          TotalJobItems, CreatedBy.Email
                          from AsyncApexJob where Id = :BC.getJobId()];
        system.debug('CountryStatsBatch finish: a = ' +JSON.serialize(a));
        // Send error email if there were errors.
        if (a.NumberOfErrors > 0) Utilities.BatchErrorEmail('CountryStatsBatch', a);
    }
}