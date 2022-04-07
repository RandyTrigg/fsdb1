/*
* Invoke sync from GFW to FSDB for each fiscal sponsor group.
*/
global class Sync_QueueableSchedule implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Run sync for each FS COA
        List<FS_Group_Settings__mdt> fsGroups = [SELECT GFW_COA_Name__c, Designated_Role_for_Ownership__c
            FROM FS_Group_Settings__mdt WHERE Active__c = TRUE];

        System.enqueueJob(new Sync_Queueable(fsGroups));
    }
}
