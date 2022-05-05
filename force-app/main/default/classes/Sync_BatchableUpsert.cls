public without sharing class Sync_BatchableUpsert implements Database.batchable<sObject>, Database.Stateful{
    // Carries out upserts in batch sizes set in executable

    // Class variables set in start method and used in execute
    // Note: Database.Stateful allows instance member variables to retain their values between transactions. 
    Schema.SObjectField extIdFieldReference;
    List<String> mdtObjNames;
    GFW_Sync_Object_Mapping__mdt objMap;
    String mdtObjName;

    public Sync_BatchableUpsert(List<String> strListParam) {
        mdtObjNames = strListParam;
        system.debug('parameter: ' + mdtObjNames);
    }

    public Iterable<sObject> start(Database.BatchableContext bc) {
        // Instantiates new SyncController to build records of type mdtObjName
        // Returns records to execute method for upserting
        List<sObject> recs;
        if (mdtObjNames.size() > 0) {
            System.debug('Batch START top mdtObjNames: ' + mdtObjNames);
            mdtObjName = mdtObjNames.remove(0);
            SyncController scThisFS = new SyncController();
            recs = new List<sObject>(scThisFS.buildRecsToUpsert(mdtObjName));
            extIdFieldReference = scThisFS.extIdFieldReference;
            objMap = scThisFS.getObjectMapping(mdtObjName);
            system.debug('Batch START this mdtObjName: ' + mdtObjName);
            System.debug('Batch START bottom mdtObjNames: ' + mdtObjNames);
        }
        return recs; 
    }
    
    public void execute(Database.BatchableContext bc, List<sObject> recs) {
        String resultMsg;
        String status;
        Id slRecId;
        List<Sync_Log_Record__c> upSLRs = new List<Sync_Log_Record__c>();
        String slrLookupFieldName;
        // Loop through results to update Sync Log Records.
        if (recs != null && recs.size() > 0) {
            slrLookupFieldName = objMap.SyncLogRecordLookupFieldName__c;
            Database.UpsertResult[] upsResults;
            if (mdtObjName == 'GiftCredit_to_OppContactRole') {
                upsResults = Database.upsert( recs );
            } else {
                upsResults = Database.upsert( recs, extIdFieldReference, false);
            }
            System.debug('upsResults: ' + upsResults);
            // Upsert results are in the same order as original list of records. 
            for(Integer index = 0, size = upsResults.size(); index < size; index++) {
                Sync_Log_Record__c slrecUpdate = new Sync_Log_Record__c();
                slrecUpdate.Id = (Id)recs[index].get('Sync_Log_Record__c');
                if(upsResults[index].isSuccess()) {
                    status = 'Success';
                    resultMsg = upsResults[index].isCreated() ? 
                        (String)upsResults[index].getid() + ' was created' : 
                        (String)upsResults[index].getid() + ' was updated';
                    if (mdtObjName != 'GiftCredit_to_OppContactRole') slrecUpdate.put(slrLookupFieldName, upsResults[index].getid());
                } else {
                    status = 'Error';
                    resultMsg = String.join(upsResults[index].getErrors(), ';');
                }
                slrecUpdate.Status__c = status;
                slrecUpdate.Results__c = resultMsg;
                upSLRs.add(slrecUpdate);
            }
            if (upSLRs != null && !upSLRs.IsEmpty()) {
                update upSLRs;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Cycle thru list and check for empty - do nothing. Otherwise we're in a loop!
        system.debug('Batch FINISH before if');
        if (mdtObjNames.size() > 0 && !Test.isRunningTest()) {
            system.debug('Batch FINISH inside if. mdtObjNames: ' + mdtObjNames);
            Id batchInstanceId = Database.executeBatch(new Sync_BatchableUpsert(mdtObjNames), 5);
            System.debug('batchInstanceId: ' + batchInstanceId);
        }
    }

    
}