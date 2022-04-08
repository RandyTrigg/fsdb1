public class Sync_Queueable implements Queueable, Database.AllowsCallouts {
    // Executes sync operation in 2 phases:
    // Phase 1: Launches sync, performs callouts to GFW, and seeds sync log records in FSDB.
    // Phase 2: Upserts records in sequential order by object.
    private List<FS_Group_Settings__mdt> fsGroups;
    private FS_Group_Settings__mdt thisFS;

    public Sync_Queueable(List<FS_Group_Settings__mdt> fsGroups) {
        this.fsGroups = fsGroups;
    }
        
    public void execute(QueueableContext context) { 
        if (fsGroups!=null && fsGroups.size() > 0) {
            // Sync Phase 1: Launch sync and populate sync log records.
            thisFS = fsGroups.remove(0);
            SyncController scThisFS = new SyncController();
            scThisFS.startDateTime = datetime.now();
            scThisFS.fsCOA = thisFS.GFW_COA_Name__c;
            scThisFS.fsRole = thisFS.Designated_Role_for_Ownership__c;
            scThisFS.LaunchSync();
            if (!Test.isRunningTest()) System.enqueueJob(new Sync_Queueable(fsGroups));
        } else {
            // Sync Phase 1 complete.
            // Sync Phase 2: Run batchable upsert for active object mappings in sequential order.
            List<String> objNames = new List<String>();
            String objName = 'GFW_Sync_Object_Mapping__mdt';
            GFW_Sync_Object_Mapping__mdt[] objMappings = Utilities.fetchRecords(
                objName,
                'WHERE Active__c = true ORDER BY Sort_order__c',
                null);
            for (GFW_Sync_Object_Mapping__mdt objMap : objMappings) {
                objNames.add(objMap.DeveloperName);
            }
            if (Test.isRunningTest()) objNames = new List<String>{'Account'};
            Id batchInstanceId = Database.executeBatch(new Sync_BatchableUpsert(objNames), 5);
            System.debug('batchInstanceId: ' + batchInstanceId);
        }
    }      
}
