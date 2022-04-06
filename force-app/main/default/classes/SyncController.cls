public without sharing class SyncController {

    /* -----------------
    Runs donations sync from GFW to FSDB in 2 parts:
    Part 1: LauchSync fetches json from GFW and stashes in Sync Log Records
    Part 2: BuildRecs returns List<sObject> for upsert in calling code

    Main methods appear at the bottom; below variables and supporting methods.

    Part 1 triggered by Sync_Queueable for each FS group;
    Sync_Queueable then launches Sync_BatchableUpsert, which activates Part 2 by object.
    -------------------- */
    
    /*******************
     * VARIABLES
     *******************/

    // Class variables set upon instantiation for sync launch
    public String fsCOA;
    public String fsRole;
    public Datetime startDateTime;
    public Id syncLogId;
    public List<Id> syncLogRecIds = new List<Id>();
    
    // Class variables set for building recs for upsert
    public Schema.SObjectField extIdFieldReference;

    // Class variables for this FS SyncController instance.
    Set<Id> acctIds = new Set<Id>();
    Set<Id> ctIds = new Set<Id>();
    Set<Id> giftIds = new Set<Id>();
    Set<Id> campIds = new Set<Id>();
    Set<Id> giftOppIds = new Set<Id>();  // OpportunityIds linked to gifts
    Set<Id> giftOppIdsToUpdate = new Set<Id>(); // Non-GiftOpportunities in FSDB with matching ExtOppIds to incoming GiftOpportunities
    Set<Id> oppIds = new Set<Id>(); // Unlinked Opportunities
    Set<Id> recDonIds = new Set<Id>();
    List<Object> coasJSON = new List<Object>();
    List<Object> acctsJSON = new List<Object>();
    List<Object> ctsJSON = new List<Object>();
    List<Object> rdsJSON = new List<Object>();
    List<Object> giftsJSON = new List<Object>();
    List<Object> giftOppsJSON = new List<Object>();
    List<Object> campsJSON = new List<Object>();
    List<Object> transactionsJSON = new List<Object>();
    List<Object> gcsJSON = new List<Object>();
    List<Object> oppsJSON = new List<Object>(); // 'Floating' opportunities with no transactions
    Map<Id,Id> GiftIdToGiftOppId = new Map<Id, Id>();
    List<sObject> giftToOppsToDelete = new List<sObject>();
    Map<String, Schema.SObjectField> fieldMapFSDB;
    
    // Initialized upon launch / buildrecs
    Id fsOwnerId;
    List<GFW_Sync_Picklist_Mapping__mdt	> picklistMapping = new List<GFW_Sync_Picklist_Mapping__mdt>();
    Map<Id, List<GFW_Sync_Picklist_Mapping__mdt>> picklistMap = new Map<Id, List<GFW_Sync_Picklist_Mapping__mdt>>();
    Map<String,String> extIdFieldNamesMap = new Map<String, String>();
    Map<String,Map<String,GFW_Sync_Field_Mapping__mdt>> gfwFieldMapByMDTName = new Map<String,Map<String,GFW_Sync_Field_Mapping__mdt>>();
    Map<String,Map<String,GFW_Sync_Field_Mapping__mdt>> fsdbFieldMapByMDTName = new Map<String,Map<String,GFW_Sync_Field_Mapping__mdt>>();
    List<GFW_Sync_Object_Mapping__mdt> mdts = new List<GFW_Sync_Object_Mapping__mdt>();
    Map<String,Id> recTypeMapDevNameId;

    public class attributesWrapper {
        string type;
        string url;
    }
        
    public class recordWrapper {
        attributesWrapper attributes;
        String Name;
        String Id;
        public recordWrapper (){
            attributes = new attributesWrapper();
        }
    }
        
    public class queryReturnResponseWrapper{
        Boolean done;
        String totalSize;
        String nextRecordsURL;
        list<recordWrapper> records;
    }

    /*******************
     * CALLOUTS TO GFW
     *******************/
    public String sendHTTPRequest (HTTPCalloutService service) {
        System.debug('HTTPRequest request: ' + service.getRequest());
        HTTPResponse response = service.sendRequest();
        // System.debug(response.getStatusCode());
        // System.debug(response.getBody());
        if (response.getStatusCode() == service.getSuccessStatusCode()) {
            return response.getBody();
        } else {
            return 'Error: ' + string.valueof(response.getStatusCode() + '; Callout = ' + service.getRequest());
        }
    }

    public String doQueryCallout(String queryStr) {        
        // Instantiates callout service for named credential GFWQuery with method set to GET
        // Returns JSON result or error starting with response status code
        HTTPCalloutService service = new HTTPCalloutService('GFWQuery');
        // System.debug(service.getRequest());
        // Encode SOQL queryStr for URL (handles special characters: quotes, spaces, etc.)
        String encodeQ = EncodingUtil.urlEncode(queryStr, 'UTF-8');
        service.setURLParameter('q', encodeQ);
        String results = sendHTTPRequest(service);
        return results;
    }

    public String doQueryNextBatchCallout(String nextRecordsURL) {
        // If there are batches, 'done' should be false;
        // Example of 'nextRecordsUrl': "/services/data/v54.0/query/01gD0000002HU6KIAW-2000"
        // https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_query.htm
        HTTPCalloutService service = new HTTPCalloutService('GFWQueryNextBatch');
        String nextRecsEndpoint = service.getEndpointURL() + nextRecordsURL;
        service.setEndpointURL(nextRecsEndpoint);
        String results = sendHTTPRequest(service);
        return results;
    }

    public List<Object> doQuery(String queryStr) {
        // Perform query callout and return records
        String jsonResults = doQueryCallout(queryStr);
        system.debug('Final results: ' + jsonResults);
        List<Object> records;
        if (!jsonResults.startsWith('Error:')) {
            queryReturnResponseWrapper qryResponse  = (queryReturnResponseWrapper)JSON.deserialize(jsonResults, queryReturnResponseWrapper.class);
            Boolean done = qryResponse.done;
            // system.debug('Done response: ' + done);
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(jsonResults);
            records = (List<Object>) m.get('records');
            String nextResults;
            if (!done) {
                // Retrieve remaining records in batches
                do {
                    String nextRecordsURL = qryResponse.nextRecordsURL;
                    // String nextRecordsURL = (String) m.get('nextRecordsUrl');
                    System.debug('nextRecordsURL: ' + nextRecordsURL);
                    nextResults = doQueryNextBatchCallout(nextRecordsURL);
                    System.debug('nextResults: ' + nextResults);
                    qryResponse  = (queryReturnResponseWrapper)JSON.deserialize(nextResults, queryReturnResponseWrapper.class);
                    system.debug('Done response: ' + qryResponse.done);
                    done = qryResponse.done;
                    m = (Map<String, Object>) JSON.deserializeUntyped(nextResults);
                    records.add((List<Object>)m.get('records'));
                } while (!done && !nextResults.startsWith('Error:'));
            }
        } else {
            System.debug('error results: ' + jsonResults); // Figure out how to handle error/throw exception.
        }
        return records;
    }

    /*******************
     * INITIALIZE CLASS VARIABLES and CUSTOM METADATA OBJECT/FIELD MAPPINGS
     *******************/

    // Retrieve FS User Id who should be Owner of all records created
    public void setFSOwnerId() {
        System.debug('Role for ownership: ' + fsRole);
        if (fsRole != null && fsRole != '') fsOwnerId = 
            [SELECT Id FROM User WHERE UserRole.DeveloperName =: fsRole AND IsActive = TRUE LIMIT 1].Id;
        system.debug('fsOwnerId: ' + fsOwnerId);
    }

    // Retrieve all object mappings
    public void setObjMappingsList() {
        String objName = 'GFW_Sync_Object_Mapping__mdt';
        mdts = Utilities.fetchRecords(
            objName,
            null,
            null);
        System.debug('mdts: ' + mdts);
    }

    // Retrieve object mapping by mdt name
    public GFW_Sync_Object_Mapping__mdt getObjectMapping(String mdtObjName) {
        GFW_Sync_Object_Mapping__mdt objMap = new GFW_Sync_Object_Mapping__mdt();
        for (GFW_Sync_Object_Mapping__mdt objMDT : mdts) {
            if (objMDT.DeveloperName == mdtObjName) {
                objMap = objMDT;
            }
        }
        return objMap;
    }

    // Initialize map of FSDB External Id field name to ObjectMapping mdt Name
    public void setExternalIdFieldNames() {
        for (GFW_Sync_Object_Mapping__mdt objMDT : mdts) {
            extIdFieldNamesMap.put(objMDT.DeveloperName, objMDT.FSDB_External_Id_Field_API_Name__c);
        }
    }

    // Retrieve External Id field name by ObjectMapping mdt Name
    public String externalIdFieldName(String mdtObjName) {
        return (String)extIdFieldNamesMap.get(mdtObjName);
    }

    // Retrieve all field mappings
    public void setFieldMappings() {
        String objName = 'GFW_Sync_Field_Mapping__mdt';
        String mdtObjName = '';
        String[] relFieldNames = new String[]{
            'GFW_Sync_Object_Mapping__r.DeveloperName',
            'GFW_Sync_Object_Mapping__r.FSDB_External_Id_Field_API_Name__c', 
            'GFW_Sync_Object_Mapping__r.FSDB_Object_Name__c', 
            'GFW_Sync_Object_Mapping__r.GFW_Object_Name__c',
            'LookupRelTo_SyncObjectMapping__r.FSDB_External_Id_Field_API_Name__c'};
        Map<String,GFW_Sync_Field_Mapping__mdt> gfwFieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>();
        Map<String,GFW_Sync_Field_Mapping__mdt> fsdbFieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>();
        String orderByClause = 'ORDER BY GFW_Sync_Object_Mapping__c';
        GFW_Sync_Field_Mapping__mdt[] fieldsMDTs = Utilities.fetchRecords(
            objName, orderByClause, relFieldNames);
        System.debug('fieldsMDTs: ' + fieldsMDTs);
        
        // Build field mapping for each object map
        for (GFW_Sync_Field_Mapping__mdt fmMDT : fieldsMDTs ) {
            // Initialize mdtObjName on first iteration
            if (mdtObjName == '') mdtObjName = fmMDT.GFW_Sync_Object_Mapping__r.DeveloperName;

            // On next objMap. Populate field mappings for last object and clear map.
            if (mdtObjName != fmMDT.GFW_Sync_Object_Mapping__r.DeveloperName) {
                if (gfwFieldMap != null && !gfwFieldMap.isEmpty()) {
                    gfwFieldMapByMDTName.put(mdtObjName, gfwFieldMap);
                    System.debug('gfwFieldMapByMDTName: ' + gfwFieldMapByMDTName);
                }
                if (fsdbFieldMap != null && !fsdbFieldMap.isEmpty()) {
                    fsdbFieldMapByMDTName.put(mdtObjName, fsdbFieldMap);
                    System.debug('SetFieldMappings inside loop if statement: ' + mdtObjName);
                }
                gfwFieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>();
                fsdbFieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>();
            }
            mdtObjName = fmMDT.GFW_Sync_Object_Mapping__r.DeveloperName;
            if (fmMDT.GFW_Field_API_Name__c != null && fmMDT.GFW_Field_API_Name__c != '') gfwFieldMap.put(fmMDT.GFW_Field_API_Name__c, fmMDT);
            System.debug('gfwfieldMap: ' + gfwFieldMap);
            if (fmMDT.FSDB_Field_API_Name__c != null && fmMDT.FSDB_Field_API_Name__c != '') fsdbFieldMap.put(fmMDT.FSDB_Field_API_Name__c, fmMDT);
            if (mdtObjName == 'ChartOfAccounts') System.debug('COA field mappings');
            System.debug('fsdbFieldMap: ' + fsdbFieldMap);
            System.debug('GFW Field Name: ' + fmMDT.GFW_Field_API_Name__c + '; FSDB Field Name: ' + fmMDT.FSDB_Field_API_Name__c);
        }
        // Add last set of fieldmappings
        if (gfwFieldMap != null && !gfwFieldMap.isEmpty()) {
            gfwFieldMapByMDTName.put(mdtObjName, gfwFieldMap);
        }
        if (fsdbFieldMap != null && !fsdbFieldMap.isEmpty()) {
            fsdbFieldMapByMDTName.put(mdtObjName, fsdbFieldMap);
            System.debug('SetFieldMappings outside loop if statement: ' + mdtObjName);
            System.debug('COA fsdbFieldMap: ' + fsdbFieldMap);
        }
        System.debug('gfwFieldMapByMDTName FINAL: ' + gfwFieldMapByMDTName);
        System.debug('fsdbFieldMapByMDTName FINAL: ' + fsdbFieldMapByMDTName);
    }

    // Retrieve field mappings by ObjectMapping mdt Name
    public Map<String,GFW_Sync_Field_Mapping__mdt> getFieldMappingsGFW(String mdtObjName) {
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>(
            gfwFieldMapByMDTName.get(mdtObjName)
        );
        return fieldMap;
    }

    public Map<String,GFW_Sync_Field_Mapping__mdt> getFieldMappingsFSDB(String mdtObjName) {
        System.debug('getFieldMappingsFSDB mdtObjName: ' + mdtObjName);
        System.debug('fsdbFieldMapByMDTName: ' + fsdbFieldMapByMDTName);
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>(
            fsdbFieldMapByMDTName.get(mdtObjName)
        );
        return fieldMap;
    }

    // Retrieve picklist mappings by mdt name
    public void setPicklistMappingsList() {
        String objName = 'GFW_Sync_Picklist_Mapping__mdt';
        String[] relatedFieldNames = new String[]{
            'GFW_Sync_Field_Mapping__r.GFW_Sync_Object_Mapping__r.DeveloperName',
            'GFW_Sync_Field_Mapping__r.FSDB_Field_API_Name__c'};
        String orderByClause = 'ORDER BY GFW_Sync_Field_Mapping__c';
        picklistMapping = Utilities.fetchRecords(
            objName,
            orderByClause,
            relatedFieldNames
            );
        System.debug('picklistmapping: ' + picklistMapping);
        Id storeId;
        List<GFW_Sync_Picklist_Mapping__mdt> addPicklists = new List<GFW_Sync_Picklist_Mapping__mdt>();
        for (GFW_Sync_Picklist_Mapping__mdt pList : picklistMapping) {
            if (storeId == null) storeId = pList.GFW_Sync_Field_Mapping__c;
            if (storeId != pList.GFW_Sync_Field_Mapping__c) {
                picklistMap.put(storeId, addPicklists);
                storeId = pList.GFW_Sync_Field_Mapping__c;
                addPicklists = new List<GFW_Sync_Picklist_Mapping__mdt>();
            }
            addPicklists.add(pList);
        }
        // Add last set of picklistmappings
        picklistMap.put(storeId, addPicklists);
    }



    /*******************
     * RETRIEVE RECORDS FROM GFW
     *******************/

    // Build set of Ids for records not already in FSDB to insert 
    public Set<Id> recIdsToInsert(String mdtObjName, Set<Id> idsGathered) {
        System.debug('idsGathered: ' + idsGathered);
        GFW_Sync_Object_Mapping__mdt objMDT = getObjectMapping(mdtObjName);
        String gfwObjName = objMDT.GFW_Object_Name__c;
        String fsdbObjName = objMDT.FSDB_Object_Name__c;
        String inIDsStr = Utilities.packageIdsForQuery(idsGathered);
        String extIdFieldName = externalIdFieldName(mdtObjName);
        System.debug('external id fieldname for ' + mdtObjName + ': ' + extIdFieldName);
        String whereClause = 'WHERE ' + externalIdFieldName(mdtObjName) + ' IN ' + inIDsStr; 
        Set<Id> idsToQuery = new Set<Id>();
        List<sObject> exstRecs = Utilities.fetchRecords(
            fsdbObjName, whereClause, null);
        System.debug('Existing recs: ' + exstRecs);
        if (exstRecs!=null && !exstRecs.IsEmpty()) {
            // Remove existing ids from list
            for (sObject extRec : exstRecs) {
                idsGathered.remove((Id)extRec.get(extIdFieldName));
            }
        }
        idsToQuery.addAll(idsGathered);
        System.debug('idsToQuery: ' + idsToQuery);
        return idsToQuery;
    }

    // Generate and query GFW by mdt record
    public List<Object> queryForRecords(String mdtObjName, Set<Id> idsForQuery, String whereClauseCustom) {
        // Retrieve object and field mappings
        GFW_Sync_Object_Mapping__mdt objMap = getObjectMapping(mdtObjName);
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = getFieldMappingsGFW(mdtObjName);
        System.debug('objMap: ' + objMap);
        List<Object> records;
        if ( !fieldMap.isEmpty() ) {
            // Query GFW for records in Ids list
            String gfwObjName = objMap.GFW_Object_Name__c;
            List<String> gfwfieldList = new List<String>(fieldMap.keySet());
            String gfwFields = String.join(gfwfieldList, ',');
            String whereClause = '';
            if (idsForQuery != null && !idsForQuery.isEmpty()) {
                String inIDsStr = Utilities.packageIdsForQuery(idsForQuery);
                whereClause = ' WHERE Id IN ' + inIDsStr;
            } else if (whereClauseCustom != null && whereClauseCustom != '') {
                whereClause = whereClauseCustom;
            }
            String query='SELECT ' + gfwFields + ' FROM ' + gfwObjName + whereClause;
            records = doQuery(query);
        }
        return records;
    }

    /*******************
     * SYNC LOG ACTIONS
     *******************/

    // Create new Sync Log
    public void newSyncLog() {
        Sync_Log__c sLog = new Sync_Log__c(
            Type__c = 'Gifts: GFW to FSDB',
            DateTime_Start__c = startDateTime,
            Status__c = 'Pending'
        );
        insert sLog;
        syncLogId = sLog.Id;
    }

    // Stash json 'records' in separate Sync Log Records
    public void logRecords(String mdtObjName, List<Object> records) {
        List<Sync_Log_Record__c> slRecList = new List<Sync_Log_Record__c>();
        if (records != null && !records.isEmpty()) {
            for (Object rec : records) {
                Sync_Log_Record__c slRec = (Sync_Log_Record__c)Utilities.newRecord('Sync_Log_Record__c');
                slRec.RecordInfo__c = JSON.serialize(rec);
                System.debug('JSON serialized: ' + JSON.serialize(rec));
                slRec.Sync_Log__c = syncLogId;
                slRec.Status__c = 'Pending';
                slRec.Type__c = mdtObjName;
                slRecList.add(slRec);
                slRec.FSGroupOwnerId__c = fsOwnerId;
                slRec.FS_Group__c = fsCOA;
            }
        }
        if (slRecList != null && slRecList.size() > 0) {
            insert slRecList;
            System.debug('Inserted list of sync log records: ' + mdtObjName);
        }
    }

    // Deletes sObj recs and logs results in separate Sync Log Records
    public void deleteAndLog(String mdtObjName, List<sObject> recsToDelete) {
        if (recsToDelete != null && !recsToDelete.isEmpty()) {
            List<Sync_Log_Record__c> slRecList = new List<Sync_Log_Record__c>();
            Database.DeleteResult[] drList = Database.delete(recsToDelete, false);
            for (Database.DeleteResult dr : drList) {
                Sync_Log_Record__c slRec = (Sync_Log_Record__c)Utilities.newRecord('Sync_Log_Record__c');
                slRec.RecordInfo__c = JSON.serialize(recsToDelete);
                System.debug('JSON serialized: ' + JSON.serialize(recsToDelete));
                slRec.Sync_Log__c = syncLogId;
                slRec.Type__c = mdtObjName + '_delete';
                slRec.Status__c = dr.isSuccess() ? 'Success' : 'Error';
                slRec.Results__c = dr.isSuccess() ? 'Deleted: ' + dr.getId() : 'Error: ' + String.join(dr.getErrors(), ';');
                slRecList.add(slRec);
                slRec.FS_Group__c = fsCOA;
            }
            if (slRecList != null && slRecList.size() > 0) {
                insert slRecList;
                System.debug('Inserted list of delete sync log records');
            }
        }
    }


    public List<sObject> retrievePendingLogRecs(String mdtObjName) {
        List<sObject> objList = new List<sObject>(Utilities.fetchRecords(
            'Sync_Log_Record__c',
            'WHERE Type__c = \'' + mdtObjName + '\' AND Status__c = \'Pending\'',
            null
        ));
        return objList;
    }

    /*******************
     * GATHER RECORDS IN GFW
     *******************/

    public void gatherTransactions() {
        // Retrieve transactions incl soft credit types (don't upsert as Payment records). Assume we have everything linked.
        // Assumes account and opportunity lookups on the Transaction can be relied upon exclusively for gift's account/opportunity.
        Map<String, Object> relGift;
        System.debug('fsCOA: ' + fsCOA);
        String mdtObjName = 'Transaction_to_Payment';
        String whereClause = ' WHERE AQB__ChartofAccounts__r.Name LIKE \'' + fsCOA + '%\' and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';
        List<Object> records = queryForRecords(mdtObjName, null, whereClause);
        if (records != null && records.size()>0) {
            transactionsJSON = records;
            for (Object rec : records) {
                // Grab all parent/related Ids
                Map<String, Object> t = (Map<String, Object>) rec;
                System.debug('>>> Transactions: ' + t);
                Id giftId = (Id)t.get('AQB__Gift__c');
                giftIds.add(giftId);
                if (t.get('Recurring_Donations__c') != null) recDonIds.add((Id)t.get('Recurring_Donations__c'));
                if (t.get('AQB__CampaignAppealId__c') != null) campIds.add((Id)t.get('AQB__CampaignAppealId__c'));
                // Retrieve parent gift's account and opportunity from nested json: AQB__Gift__r={AQB__CreditedOpportunity__c=0065d00000wWBdeAAG...
                relGift = (Map<String, Object>)t.get('AQB__Gift__r');
                acctIds.add((Id)relGift.get('AQB__AccountId__c'));
                if (relGift.get('AQB__CreditedOpportunity__c') != null) {
                    Id oppId = (Id)relGift.get('AQB__CreditedOpportunity__c');
                    giftOppIds.add(oppId);
                    // Build map of GifIds to OppIds for gatherGiftOpportunities (to identify GiftOpps that need merging).
                    if (!GiftIdToGiftOppId.containsKey(giftId)) GiftIdToGiftOppId.put(giftId, oppId);
                }
            }
        }
        System.debug('giftOppIds: ' + giftOppIds);
        System.debug('GiftIdToGiftOppId: ' + GiftIdToGiftOppId);
        System.debug('campIds: ' + campIds);
    }
    
    public void gatherGiftCredits() {
        // Retrieve gift credits and their linked accounts/contacts from giftIds.
        // TO DO: Only gather gift credits where Contact's Account not equal to gift's Account
        // AQB__SecondaryGiftCreditAmount__c,AQB__PrimaryGiftRecognitionCreditPercent__c
        // Retrieve AQB_DonorAccount__c, not Credited Account. Retrieve AQB__ContactId__c, not AQB__ContactCredited__c (deprecated master/detail).
        if (!giftIds.isEmpty()) {
            String mdtObjName = 'GiftCredit_to_OppContactRole';
            String inIDsStr = Utilities.packageIdsForQuery(giftIds);
            String whereClause = ' WHERE AQB__GiftId__c IN ' + inIDsStr;
            List<Object> records = queryForRecords(mdtObjName, null, whereClause);
            Map<String, Object> pAcct;
            Map<Id, Id> extGiftContactIdMap = new Map<Id, Id>();
            if (records != null && records.size()>0) {
                // Stash gc record json and gather parent/related Ids
                gcsJSON.add(records);
                for (Object rec : records) {
                    Map<String, Object> gc = (Map<String, Object>)rec;
                    System.debug('>>> Gift Credits: ' + gc);
                    if (gc.get('AQB__DonorAccount__c') != null) { acctIds.add((Id)gc.get('AQB__DonorAccount__c')); }
                    if (gc.get('AQB__ContactId__c') != null) { 
                        // Retrieve contact's parent account from nested json: AQB__ContactId__r={AccountId=0011Y00003HzuHRQAZ, attributes={type=Contact...
                        ctIds.add((Id)gc.get('AQB__ContactId__c')); 
                        System.debug('GiftCredit contactIds: ' + ctIds);
                        pAcct = (gc.get('AQB__ContactId__r') != null) ? (Map<String, Object>)gc.get('AQB__ContactId__r') : null;
                        if (pAcct != null) acctIds.add((Id)pAcct.get('AccountId'));
                        // Package GCs for OppContactRoles - GFWGiftExternalId on Opp and GFWContactExternalId.
                        // System.debug('giftid: ' + (Id)gc.get('AQB__GiftId__c') + '; contactId: ' + (Id)gc.get('AQB__ContactId__c'));
                        extGiftContactIdMap.put((Id)gc.get('AQB__GiftId__c'), (Id)gc.get('AQB__ContactId__c'));   
                    }
                    // System.debug('AccountId: ' + (Id)gc.get('AQB__DonorAccount__c'));
                    // System.debug('ContactId: ' + (Id)gc.get('AQB__ContactId__c'));
                    // System.debug('GC Contact Parent AccountId: ' + (Id)pAcct.get('AccountId'));
                }
            }
        }
    }

    public void gatherGiftOpportunities() {
        // Identify floating Opportunities in FSDB that match GFW GiftOpportunities.
        // Set Ext Gift Ids so gift upsert will update those Opps without creating dupes.
        if (!giftOppIds.isEmpty()) {
            Set<Id> extGiftIdsToDelete = new Set<Id>();
            String inIDsStr = Utilities.packageIdsForQuery(giftOppIds);
            String whereClauseFetch = 'WHERE GFW_Gift_ID__c = null AND GFW_Opportunity_ID__c IN ' + inIDsStr;
            Opportunity[] exstRecs = Utilities.fetchRecords(
                'Opportunity', whereClauseFetch, null);
            for (Opportunity rec : exstRecs) {
                giftOppIdsToUpdate.add(rec.GFW_Opportunity_ID__c);
            }
            System.debug('Inside gatherGiftOpportunities. giftOppIdsToUpdate: ' + giftOppIdsToUpdate);
            if (!giftOppIdsToUpdate.isEmpty()) {
                // Retrieve json records for setting ext gift ids in these Opportunities.
                String mdtObjName = 'GiftOpportunity';
                String inIDsStrToUpdate = Utilities.packageIdsForQuery(giftOppIdsToUpdate);
                String whereClauseQuery = ' WHERE AQB__CreditedOpportunity__c IN ' + inIDsStrToUpdate;
                giftOppsJSON = queryForRecords(mdtObjName, null, whereClauseQuery);
                // Retrieve existing FSDB Opps that match those ext gift ids to delete
                for (Id extGiftId : GiftIdToGiftOppId.keyset()) {
                    System.debug('Inside gatherGiftOpportunities - GiftIdToGiftOppId map loop: ' + extGiftId);
                    if (giftOppIdsToUpdate.contains(GiftIdToGiftOppId.get(extGiftId))) extGiftIdsToDelete.add(extGiftId);
                }
                System.debug('extGiftIdsToDelete: ' + extGiftIdsToDelete);
                if (extGiftIdsToDelete != null && !extGiftIdsToDelete.isEmpty()) {
                    String idsToQuery = Utilities.packageIdsForQuery(extGiftIdsToDelete);
                    String whereQuery = 'WHERE GFW_Gift_ID__c IN ' + idsToQuery;
                    giftToOppsToDelete = Utilities.fetchRecords('Opportunity', whereQuery, null);
                }
            }
            System.debug('gatherGiftOpportunities giftOppsJSON: ' + giftOppsJSON);
        }
    }

    // Retrieve 'floating' (non-gift) Opportunities linked to COA
    // Add to OppId set and parent Accounts acctId set
    public void gatherOpportunities() {
        String mdtObjName = 'Opportunity';
        String inIDsStr = giftOppIds.isEmpty() ? '' : ' AND Id NOT IN ' + Utilities.packageIdsForQuery(giftOppIds);
        String whereClause = ' WHERE Chart_of_Accounts__r.Name LIKE \'' + fsCOA + '\'' + inIDsStr;
        List<Object> records = queryForRecords(mdtObjName, null, whereClause);
        if (records != null && records.size()>0) {
            for (Object rec : records) {
                Map<String, Object> opp = (Map<String, Object>)rec;
                System.debug('>>> Opportunities: ' + opp);
                acctIds.add((Id)opp.get('AccountId'));
                oppIds.add((Id)opp.get('Id'));
            }
        System.debug('AccountIdsAfterOpps: ' + acctIds);
        System.debug('OppIdsAfterOpps: ' + oppIds);
        }
    }

    public void gatherCOAs() {
        String mdtObjName = 'ChartofAccounts';
        String whereClause = ' WHERE Name LIKE \'' + fsCOA + '\'';
        coasJSON = queryForRecords(mdtObjName, null, whereClause);
        System.debug('COA: ' + fsCOA + '; coasJSON: ' + coasJSON);
    }

    /*******************
     * BUILD RECORDS IN FSDB
     *******************/

    // Retrieve Sync Log Records by type and upsert
    public List<sObject> recsFromSyncLogRecs(String mdtObjName) {
        // Iterate through FSDB fieldmappings to populate fsdb records with either GFW-queried values or default values if GFW field api name is blank.

        // Retrieve object and field mappings
        GFW_Sync_Object_Mapping__mdt objMap = getObjectMapping(mdtObjName);
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = getFieldMappingsFSDB(mdtObjName);
        String gfwObjName = objMap.GFW_Object_Name__c;
        List<String> fsdbFieldList = new List<String>(fieldMap.keySet());
        String fsdbObjName = objMap.FSDB_Object_Name__c;
        recTypeMapDevNameId = Utilities.recTypeMapForObject(fsdbObjName);
        fieldMapFSDB = Utilities.fieldMapForObject(fsdbObjName);
        
        // Set public class variable to field reference for external id (required for upsert operation)
        String fsdbExternalIdFieldName = objMap.FSDB_External_Id_Field_API_Name__c;
        extIdFieldReference = fieldMapFSDB.get(fsdbExternalIdFieldName); 
        
        // Declare method variables
        String fieldType, gfwFieldName;
        List<sObject> objs = new List<sObject>();

        // Retrieve Sync Log Records for json
        List<sObject> objList = new List<sObject>(retrievePendingLogRecs(mdtObjName));

        // Loop through Sync Log records to retrieve and deserialize json; create new records
        for (sObject obj : objList) {
            Sync_Log_Record__c slRec = (Sync_Log_Record__c)obj;

            System.debug('Record info: ' + slRec.RecordInfo__c);
            // Cast json as map of fieldname(string) to fieldvalue(object)
            Map<String, Object> gfwInfo = (Map<String, Object>)JSON.deserializeUntyped(slRec.RecordInfo__c);
            System.debug('map gfwInfo: ' + gfwInfo);
            
            // Build new FSDB record
            sObject sObj = Utilities.newRecord(fsdbObjName);
            System.debug('>>> ' + gfwObjName + ': ' + gfwInfo);
            
            // Loop through FSDB fields in mdt to set with GFW values
            for (String fsdbFieldName : fsdbFieldList) {
                System.debug('fsdbFieldName: ' + fsdbFieldName);
                GFW_Sync_Field_Mapping__mdt fieldmapMDT = fieldMap.get(fsdbFieldName);
                // Retrieve field type
                fieldType = String.valueof(fieldMapFSDB.get(fsdbFieldName).getDescribe().getType());        
                System.debug('fieldtype: ' + fieldType);
                gfwFieldName = fieldmapMDT.GFW_Field_API_Name__c;
                if (fsdbFieldName == 'RecordTypeId') {
                    // Special handling required:
                    // JSON for record type contains related info about record type
                    // Extract DeveloperName from record type info
                    Map<String,Object> rTypeMap = (Map<String,Object>)gfwInfo.get('RecordType');
                    sObj = populateFields(sObj, fieldType, fieldmapMDT, rTypeMap.get('DeveloperName'));
                    System.debug('This is the recordtype name field in GFW for mapping to FSDB record type Id: ' + fieldmapMDT.FSDB_Field_API_Name__c + ' to this value: ' + gfwInfo.get('RecordType'));
                } else if (gfwFieldName != null) {
                    System.debug('FSDB Field Type for ' + fsdbFieldName + ': ' + fieldType);
                    System.debug('Set this field in FSDB: ' + fieldmapMDT.FSDB_Field_API_Name__c + ' to this value: ' + gfwInfo.get(gfwFieldName));
                    sObj = populateFields(sObj, fieldType, fieldmapMDT, gfwInfo.get(gfwFieldName));
                } else if (fsdbFieldName == 'OwnerId') {
                    sObj.put(fsdbFieldName, slRec.FSGroupOwnerId__c);
                } else {
                    // Set field to default value in cmdt - TO DO: Cast type?
                    sObj.put(fsdbFieldName, fieldmapMDT.DefaultValue__c);
                }
            } // End for each FSDB field
            // Add link to Sync Log Record
            sObj.put('Sync_Log_Record__c', slRec.Id);
            System.debug('sObj to add: ' + sObj);
            // syncLogRecIds.add(slRec.Id);
            objs.add(sObj);
        } // End for each sync log record
        System.debug('List of objs to insert: ' + objs);
        return objs;
    }

    // Set value in given field 
    public sObject populateFields(sObject sObj, String fieldType, GFW_Sync_Field_Mapping__mdt fieldmapMDT, Object gfwValue) {
        String fsdbFieldName = fieldmapMDT.FSDB_Field_API_Name__c;
        String relName;
        // Check for picklist map
        List<GFW_Sync_Picklist_Mapping__mdt> pLVals = new List<GFW_Sync_Picklist_Mapping__mdt>(picklistMap.get(fieldmapMDT.Id));
        System.debug('pLVals for ' + fsdbFieldName + ': ' + pLVals);
        if (pLVals != null && !pLVals.IsEmpty()) {
            System.debug('Picklists not null!');
            // Look up picklist value from map
            // For record type, retrieve record type Name from record json
            for (GFW_Sync_Picklist_Mapping__mdt pL : pLVals ) {
                // Set gfwValue based on picklist mapping
                if ((String)gfwValue == pL.GFW_Picklist_Value__c) gfwValue = (Object)pL.FSDB_Picklist_Value__c;
            }
        }
        // Cast value based on fieldType and set field.
        if (gfwValue == null) {
            sObj.put(fsdbFieldName, null);
        } else if (fieldType == 'STRING' || fieldType == 'TEXTAREA' || fieldType == 'EMAIL' || fieldType == 'PICKLIST') {
            sObj.put(fsdbFieldName, (String)gfwValue);
        } else if ( fieldType == 'CURRENCY' ) {
            sObj.put(fsdbFieldName, (Decimal)gfwValue);
        } else if (fieldType == 'INTEGER') {
            sObj.put(fsdbFieldName, (Integer)gfwValue);
        } else if (fieldType == 'BOOLEAN') {
            sObj.put(fsdbFieldName, (Boolean)gfwValue);
        } else if (fieldType == 'DATE') {
            Date dt = date.valueOf((String)gfwValue);
            sObj.put(fsdbFieldName, dt); 
        } else if (fieldType == 'REFERENCE') {
            system.debug('reference fsdbFieldName: ' + fsdbFieldName);
            if (fsdbFieldName == 'RecordTypeId') {
                // gfwValue contains DeveloperName of record type in fsdb. 
                // Look up recordtypeid by DeveloperName to set RecordTypeId.
                sObj.put(fsdbFieldName, recTypeMapDevNameId.get((String)gfwValue));
            }
            else {
                // Create dynamic reference for lookup/master-detail relationships via that lookup's GFW external id 
                // Instantiate new lookup/reference sObject and set lookup reference to it using putSObject.
                Schema.sObjectType reference = fieldMapFSDB.get(fsdbFieldName).getDescribe().getReferenceTo()[0];
                String refObjName = reference.getDescribe().getName();
                // Create new instance of related sObject with its External Id set to GFW Id.
                sObject refSObj = Schema.getGlobalDescribe().get(refObjName).newSObject();
                String extIdFieldNameByMDT = fieldmapMDT.LookupRelTo_SyncObjectMapping__c != null ? 
                    fieldmapMDT.LookupRelTo_SyncObjectMapping__r.FSDB_External_Id_Field_API_Name__c : 
                    externalIdFieldName(refObjName);
                System.debug('external id field name: ' + extIdFieldNameByMDT + 'value: ' + (Id)gfwValue);
                refSObj.put(extIdFieldNameByMDT, (Id)gfwValue);
                relName =  String.valueof(fieldMapFSDB.get(fsdbFieldName).getDescribe().getRelationshipName());
                // Set relationship (e.g., LookupRelationship__r) to refSObj (sObject reference)
                sObj.putSObject(relName, refSObj);
                System.debug('Relationship name: ' + relName);
            }
        }
        System.debug('sObj from populatefields: ' + sObj);
        return sObj;
    }

    /*******************
     * 
     * 
     * MAIN METHOD 1: LAUNCH SYNC
     * 
     * 
     *******************/

    public void LaunchSync() {
        // Initialize class vars
        setFSOwnerId();
        setObjMappingsList();
        setExternalIdFieldNames();
        setFieldMappings();

        // Retrieve children records and parent Ids
        gatherCOAs();
        gatherTransactions();
        gatherGiftCredits();
        gatherGiftOpportunities();
        gatherOpportunities();

        // Gather json records for each set of Ids.
        Set<Id> idsToUpsert;
        List<Object> records;
        Map<String, Set<Id>> objNamesIdsMap = new Map<String, Set<Id>>{
            'Account' => acctIds,
            'Contact' => ctIds,
            'Recurring_Donations' => recDonIds,
            'Gift_to_Opportunity' => giftIds,
            'Opportunity' => oppIds,
            'Campaign' => campIds
        };
        for (String thisObjName : objNamesIdsMap.keyset()) {
            // For Contacts, Accounts, floating Opportunities, only upsert those not already in fsdb.
            idsToUpsert = thisObjName == 'Contact' || thisObjName == 'Account' || thisObjName == 'Opportunity' ? recIdsToInsert(thisObjName, objNamesIdsMap.get(thisObjName)) : objNamesIdsMap.get(thisObjName);
            System.debug('thisObjName: ' + thisObjName + '; idsToUpsert: ' + idsToUpsert);
            if (!idsToUpsert.IsEmpty()) {
                records = queryForRecords(thisObjName, idsToUpsert, null);
                System.debug('Launch sync: ' + thisObjName + ' records to create: ' + records);
                switch on thisObjName {
                    when 'Account' {
                        acctsJSON = records;
                    } when 'Contact' {
                        ctsJSON = records;
                    } when 'Recurring_Donations' {
                        rdsJSON = records;
                    } when 'Gift_to_Opportunity' {
                        giftsJSON = records;
                    } when 'Opportunity' {
                        oppsJSON = records;
                    } when 'Campaign' {
                        campsJSON = records;
                    }
                }
            }
        }

        // Generate Sync Log and Sync Log Records (DML operations must be done AFTER all callouts)
        // Stash each json 'record' in Sync Log Record
        newSyncLog();
        Map<String, List<Object>> objNamesJSONMap = new Map<String, List<Object>>{
            'Account' => acctsJSON,
            'Contact' => ctsJSON,
            'ChartofAccounts' => coasJSON,
            'Recurring_Donations' => rdsJSON,
            'Campaign' => campsJSON,
            'GiftOpportunity' => giftOppsJSON,
            'Gift_to_Opportunity' => giftsJSON,
            'Opportunity' => oppsJSON,
            'Transaction_to_Payment' => transactionsJSON
        };
        for (String objName : objNamesJSONMap.keySet()) {
            logRecords(objName, objNamesJSONMap.get(objName));
        }
        // Delete any GiftToOpportunities newly linked to existing floating Opportunities.
        deleteAndLog('Gift_to_Opportunity', giftToOppsToDelete); 
    }


    /*******************
     * 
     * 
     * MAIN METHOD 2: BUILD RECORDS TO UPSERT IN FSDB
     * 
     * 
     *******************/
    
     public List<sObject> buildRecsToUpsert(String mdtObjName) {
        // Initialize class vars
        // setFSOwnerId(); This is on GFW side. Now we're exclusively in fsdb.
        setObjMappingsList();
        setExternalIdFieldNames();
        setFieldMappings();
        setPicklistMappingsList();
        return recsFromSyncLogRecs(mdtObjName);
    }

}
