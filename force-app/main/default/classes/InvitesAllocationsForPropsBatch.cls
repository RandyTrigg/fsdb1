// Build invite and allocation records for proposals returned from given query.
global class InvitesAllocationsForPropsBatch implements Database.Batchable<sObject> {
    private String query;

    global InvitesAllocationsForPropsBatch(String query) {
        this.query = query;
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<sObject> scope) {
        Map<Id, sObject> scopeMap = new Map<Id, sObject>(scope);
        InviteController.newAllocationsInvitesForProps(scopeMap.keySet());
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
            Utilities.BatchErrorEmail('InvitesAllocationsForPropsBatch', a);
    }
}