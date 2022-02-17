// This batch class should always use batch size = 1, because there's a callout for each prop id.
global class OFACLookupBatch implements Database.Batchable<Id>, Database.AllowsCallouts, Database.Stateful{
    global final List<Id> propIds;
    global String resultingHits;
   
    global OFACLookupBatch(Set<Id> ids){
        propIds = new List<Id>(ids);
    }
   
    global Iterable<Id> start(Database.BatchableContext BC){
        return propIds;
    }
   
    global void execute(Database.BatchableContext BC, List<Id> scope){  
        // Do the OFAC lookup, and gather any resulting hits.
        if (scope.size() > 0) {
            String result = OFACLookup.lookupProposals(new Set<Id>(scope));
            if (result != null) resultingHits = resultingHits == null ? result : resultingHits + '\n' + result;
        }
    }
   
    global void finish(Database.BatchableContext BC){   
        AsyncApexJob a = [Select Id, Status, NumberOfErrors, JobItemsProcessed,
                          TotalJobItems, CreatedBy.Email
                          from AsyncApexJob where Id = :BC.getJobId()];
        system.debug('OFACLookupBatch finish: resultingHits = ' +resultingHits);
        system.debug('OFACLookupBatch finish: a = ' +JSON.serialize(a));
        // Send an email if there were hits.
        if(resultingHits != null) OFACLookup.OFACLookupNotificationEmail(resultingHits);
        // Send error email if there were errors.
        if (a.NumberOfErrors > 0) Utilities.BatchErrorEmail('OFACLookupBatch', a);
    }
}