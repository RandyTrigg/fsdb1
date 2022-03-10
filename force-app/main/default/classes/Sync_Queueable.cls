public class Sync_Queueable implements Queueable, Database.AllowsCallouts {
		
        // Launch sync and logs actions
        public void execute(QueueableContext context) { 
		 
        // Initialize variables
        String fsRole;
        List<FS_Group_Settings__mdt> fsGroups;
        Datetime startDateTime = datetime.now();
        system.debug('New startDateTime: ' + startDateTime);  

        // Run sync for each FS COA
        try {
            fsGroups = [
                SELECT GFW_COA_Name__c, Designated_Role_for_Ownership__c
                FROM FS_Group_Settings__mdt
            ];
        } catch (Exception e) {
            System.debug('Unable to retrieve FS Group Settings custom metadata.');
            // throw new HTTPCalloutFrameworkException(HTTPCalloutFrameworkException.CUSTOM_METADATA_NOT_FOUND);
        }

        for (FS_Group_Settings__mdt fs : fsGroups) {
            // For each FS, grab COA and role to assign record ownership
            SyncController scThisFS = new SyncController();
            scThisFS.fsCOA = fs.GFW_COA_Name__c;
            scThisFS.fsRole = fs.Designated_Role_for_Ownership__c;
            scThisFS.LaunchSync();
            
            // Create Sync Log record.
            Datetime endDateTime = datetime.now();
            String notes = 'Sync completed for ' + fs.GFW_COA_Name__c;
            // String status = (sync.syncStatus == '' || sync.syncStatus == null) ? 'Completed Successfully' : sync.syncStatus;
            // Retrieve synclogaction recs from sync controller 
            // List<Sync_Log__c> lActions = new List<Sync_Log__c>(scThisFS.lsLogAction);
            // .newSyncLog(klasRecType, startDateTime, endDateTime, notes, status, lActions);
        }      

    }        
}
