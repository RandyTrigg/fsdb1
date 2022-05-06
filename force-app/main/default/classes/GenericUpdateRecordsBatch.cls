/* Update a list of records already created in memory.
 * Alternately can include a second set of records (and a batch size) to update in the 'finish' method.
 */
global class GenericUpdateRecordsBatch implements Database.Batchable<sObject> {
    private List<sObject> recs, recs2;
    private Integer batchSize;

    global GenericUpdateRecordsBatch(List<sObject> recs) {
        this.recs = recs;
    }

    global GenericUpdateRecordsBatch(
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
            Utilities.BatchErrorEmail('GenericUpdateRecordsBatch', a);
        else if (recs2 != null && recs2.size() > 0 && batchSize > 0)
            // Launch another batch update for the second set of records.
            Database.executeBatch(
                new GenericUpdateRecordsBatch(recs2),
                batchSize
            );
    }
}