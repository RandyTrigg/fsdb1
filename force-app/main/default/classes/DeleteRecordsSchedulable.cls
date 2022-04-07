/*
 * Delete collections of records determined by SOQL queries found in custom settings.
 * Run this on a regular basis, by using the Schedule button from the Setup/apex classes/ interface.
 */
global with sharing class DeleteRecordsSchedulable implements Schedulable {
    global void execute(SchedulableContext scMain) {
        // Look for active queries to run from custom settings.
        // Note that the max length of a query is 255 characters.
        Map<String, Periodic_delete_queries__c> pdqs = Periodic_delete_queries__c.getAll();
        for (Periodic_delete_queries__c pdq : pdqs.values()) {
            if (pdq.Active__c) {
                Database.executeBatch(
                    new DeleteRecordsBatch(pdq.Query__c, pdq.Hard_delete__c),
                    (Integer) pdq.Batch_size__c
                );
            }
        }
    }
}