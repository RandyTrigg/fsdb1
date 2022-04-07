/* Found on stackoverflow.  Generic way to touch a bunch of records of arbitrary type in a batch process.
 * Handy for running a trigger over existing records.
 * Invoke, for example, over all contacts, by typing this at Execute Anonymous:
 *     Id batchInstanceId = Database.executeBatch(new GenericTouchRecordsBatch('select id from Contact'));
 */
global with sharing class GenericTouchRecordsBatch implements Database.Batchable<sObject> {
    private String query;

    global GenericTouchRecordsBatch(String query) {
        this.query = query;
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<sObject> scope) {
        update scope;
    }

    global void finish(Database.BatchableContext BC) {
        AsyncApexJob a = [
            SELECT
                Id,
                Status,
                NumberOfErrors,
                JobItemsProcessed,
                TotalJobItems,
                CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :BC.getJobId()
        ];

        // Send error email if there were errors.
        if (a.NumberOfErrors > 0)
            Utilities.BatchErrorEmail('GenericTouchRecordsBatch', a);
    }
}