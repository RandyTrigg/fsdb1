public class Sync_BatchableUpsert implements Database.batchable<sObject>, Database.Stateful{
    // Carries out upserts in batch sizes set in executable

    // Class variables set in start method and used in execute
    // Database.Stateful allows instance member variables to retain their values between transactions. 
    private Schema.SObjectField extIdFieldReference;
    private String mdtObjName;

    public Sync_BatchableUpsert(String strParam) {
        mdtObjName = strParam;
        system.debug('parameter: ' + mdtObjName);
    }

    public Iterable<sObject> start(Database.BatchableContext bc) {
        // Instantiate new SyncController to build records of type mdtObjName
        // Returns records to execute method for upserting
        SyncController scThisFS = new SyncController();
        List<sObject> recs = new List<sObject>(scThisFS.buildRecsToUpsert(mdtObjName));
        extIdFieldReference = scThisFS.extIdFieldReference;
        return recs;
    }
    
    public void execute(Database.BatchableContext bc, List<sObject> recs) {
        if (recs != null && recs.size() > 0) {
            Database.UpsertResult[] upsResults = Database.upsert( recs, extIdFieldReference, false);
            System.debug('upsResults: ' + upsResults);
            for(Database.upsertResult result:upsResults) {
                if (result.isSuccess() && result.isCreated()) {
                    System.debug('Success!!' + (Id)result.getId());
                } else {
                    System.debug('Error: ' + result.getErrors());
                }
             }
        }
    }

    public void finish(Database.BatchableContext bc) {
        Id batchInstanceId = Database.executeBatch(new Sync_BatchableUpsert('Contact'), 5);
        System.debug('batchInstanceId: ' + batchInstanceId);
    }

    
}
