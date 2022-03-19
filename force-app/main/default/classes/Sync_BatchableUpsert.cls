public class Sync_BatchableUpsert implements Database.batchable<sObject>, Database.Stateful{

    private Schema.SObjectField extIdFieldReference;
    private String mdtObjName;
    // Pass mdtObjName in as parameter from calling method
    public Sync_BatchableUpsert(String strParam) {
        mdtObjName = strParam;
        system.debug('parameter: ' + mdtObjName);
    }

    public Iterable<sObject> start(Database.BatchableContext bc) {

        SyncController scThisFS = new SyncController();
        // List<sObject> recs = new List<sObject>(scThisFS.buildRecsToUpsert(mdtObjName));
        List<sObject> recs = new List<sObject>(scThisFS.buildRecsToUpsert('Account'));
        // recs = scThisFS.buildRecsToUpsert(mdtObjName);
        extIdFieldReference = scThisFS.extIdFieldReference;
        return recs;
    }
    
    public void execute(Database.BatchableContext bc, List<sObject> recs) {
        if (recs != null && recs.size() > 0) {
            // BOOKMARK: extIdFieldReference is null? (argument 2 is null)
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
    }

    
}
