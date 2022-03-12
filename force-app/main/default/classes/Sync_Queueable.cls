public class Sync_Queueable implements Queueable, Database.AllowsCallouts {
		
        // Launch sync and logs actions
        public void execute(QueueableContext context) { 
		 
        // Initialize variables
        String fsRole;
        List<FS_Group_Settings__mdt> fsGroups;

 

        // Run sync for each FS COA
        fsGroups = [SELECT GFW_COA_Name__c, Designated_Role_for_Ownership__c
            FROM FS_Group_Settings__mdt
        ];

        if (fsGroups != null && !fsGroups.isEmpty()) {
            // For each FS, set vars and launch sync
            for (FS_Group_Settings__mdt fs : fsGroups) {
                // Create sync log
                Id newSyncLogId = SyncController.newSyncLog();

                SyncController scThisFS = new SyncController();
                scThisFS.syncLogId = newSyncLogId;
                system.debug('New sync log id from queueable: ' + scThisFS.syncLogId); 
                scThisFS.fsCOA = fs.GFW_COA_Name__c;
                scThisFS.fsRole = fs.Designated_Role_for_Ownership__c;


                scThisFS.LaunchSync();
            }    
        }  
    }        
}
