/*
 * Touch collections of records determined by SOQL queries found in custom settings.
 * Run this on a regular basis, by using the Schedule button from the Setup/apex classes/ interface.
 */
global with sharing class TouchRecordsSchedulable implements Schedulable {
    global void execute(SchedulableContext scMain) {
        // Look for active queries to run from custom settings.
        // Note that the max length of a query is 255 characters.
        Map<String, Periodic_touch_queries__c> ptqs = Periodic_touch_queries__c.getAll();
        for (Periodic_touch_queries__c ptq : ptqs.values()) {
            if (ptq.Active__c) {
                Database.executeBatch(
                    new GenericTouchRecordsBatch(ptq.Query__c),
                    (Integer) ptq.Batch_size__c
                );
            }
        }
    }
}