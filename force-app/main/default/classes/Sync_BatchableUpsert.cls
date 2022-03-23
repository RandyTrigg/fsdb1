public class Sync_BatchableUpsert implements Database.batchable<sObject>, Database.Stateful{
    // Carries out upserts in batch sizes set in executable

    // Class variables set in start method and used in execute
    // Database.Stateful allows instance member variables to retain their values between transactions. 
    private Schema.SObjectField extIdFieldReference;
    private List<String> mdtObjNames;
    private List<Id> syncLogRecIds;

    public Sync_BatchableUpsert(List<String> strListParam) {
        mdtObjNames = strListParam;
        system.debug('parameter: ' + mdtObjNames);
    }

    public Iterable<sObject> start(Database.BatchableContext bc) {
        // Instantiate new SyncController to build records of type mdtObjName
        // Returns records to execute method for upserting
        List<sObject> recs;
        if (mdtObjNames.size() > 0) {
            System.debug('Batch START top mdtObjNames: ' + mdtObjNames);
            String mdtObjName = mdtObjNames.remove(0);
            SyncController scThisFS = new SyncController();
            recs = new List<sObject>(scThisFS.buildRecsToUpsert(mdtObjName));
            extIdFieldReference = scThisFS.extIdFieldReference;
            syncLogRecIds = scThisFS.syncLogRecIds;
            system.debug('Batch START this mdtObjName: ' + mdtObjName);
            System.debug('Batch START bottom mdtObjNames: ' + mdtObjNames);
        }
        return recs; 
    }
    
    public void execute(Database.BatchableContext bc, List<sObject> recs) {
        if (recs != null && recs.size() > 0) {
            Database.UpsertResult[] upsResults = Database.upsert( recs, extIdFieldReference, false);
            System.debug('upsResults: ' + upsResults);
            Integer i = 0;
            Map<Id, String> syncLogRecIdToResults = new Map<Id,String>();
            for(Database.upsertResult result:upsResults) {
                if (result.isSuccess() && result.isCreated()) {
                    System.debug('Success!!' + (Id)result.getId());
                } else {
                    System.debug('Error: ' + result.getErrors());
                }
                String resultMsg = result.isSuccess() ? 'Success; new record: ' + (String)result.getId() : 'Error: ' + result.getErrors();
                // upsertResult list should be in the same order as syncLogRecIds
                syncLogRecIdToResults.put(syncLogRecIds[i], resultMsg);
                i++;
             }
             // Fetch sync log records where ids in list
             if (syncLogRecIdToResults != null && !syncLogRecIdToResults.IsEmpty()) {
                Set<Id> slrIds = new Set<Id>(syncLogRecIds);
                String idsToQuery = Utilities.packageIdsForQuery(slrIds);
                String whereClause = 'WHERE Id IN ' + idsToQuery;
                List<sObject> slRecs = Utilities.fetchRecords('Sync_Log_Record__c', whereClause, null);
                List<Sync_Log_Record__c> slRecsToUpdate = new List<Sync_Log_Record__c>();
                for (sObject rec : slRecs) {
                    Sync_Log_Record__c slRec = (Sync_Log_Record__c)rec;
                    String resultString = syncLogRecIdToResults.get(slRec.Id);
                    if (resultString != null && resultString != '') {
                        slRec.Status__c = resultString.contains('Success') ? 'Success' : 'Error';
                        slRec.Results__c = resultString;
                        slRecsToUpdate.add(slRec);
                    }
                }
                if (slRecsToUpdate.size()>0) {
                    update slRecsToUpdate;
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Cycle thru list and check for empty - do nothing. Otherwise we're in a loop!
        system.debug('Batch FINISH before if');
        if (mdtObjNames.size() > 0) {
            system.debug('Batch FINISH inside if. mdtObjNames: ' + mdtObjNames);
            Id batchInstanceId = Database.executeBatch(new Sync_BatchableUpsert(mdtObjNames), 15);
            System.debug('batchInstanceId: ' + batchInstanceId);
        }
    }

    
}
