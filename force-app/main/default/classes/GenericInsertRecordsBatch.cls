/* Insert a list of records already created in memory.
 * Alternately can include a second set of records (and a batch size) to insert in the 'finish' method.
 */
global class GenericInsertRecordsBatch implements Database.Batchable<sObject> {
    private List<sObject> recs, recs2;
    private Integer batchSize;

    global GenericInsertRecordsBatch(List<sObject> recs) {
        this.recs = recs;
    }

    global GenericInsertRecordsBatch(
        List<sObject> recs,
        List<sObject> recs2,
        Integer batchSize
    ) {
        this.recs = recs;
        this.recs2 = recs2;
        this.batchSize = batchSize;
    }

    global List<sObject> start(Database.BatchableContext BC) {
        return recs;
    }

    global void execute(Database.BatchableContext BC, List<sObject> scope) {
        insert scope;
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
            Utilities.BatchErrorEmail('GenericInsertRecordsBatch', a);
        else if (recs2 != null && recs2.size() > 0 && batchSize > 0) {
            // Launch another batch insert for the second set of records.
            system.debug(
                'GenericInsertRecordsBatch in finish method launching new batch insert: recs2.size() = ' +
                recs2.size()
            );
            Database.executeBatch(
                new GenericInsertRecordsBatch(recs2),
                batchSize
            );
        }
    }
}