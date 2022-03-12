public without sharing class SyncController {
    
    // Class variables set upon instantiation
    public String fsCOA;
    public String fsRole;
    // public List<Sync_Log_Action__c> lAction = new List<Sync_Log_Action__c>();

    // Class variables for this FS SyncController instance.
    Set<Id> acctIds = new Set<Id>();
    Set<Id> ctIds = new Set<Id>();
    Set<Id> giftIds = new Set<Id>();
    Set<Id> oppIds = new Set<Id>();
    Set<Id> recDonIds = new Set<Id>();
    List<Object> transactionsJSON = new List<Object>();
    List<Object> gcsJSON = new List<Object>();
    List<Object> oppsJSON = new List<Object>();

    // Need these?
    public List<Account> upsAcctList = new List<Account>();
    public List<Contact> upsCtList = new List<Contact>();
    
    // Initialized upon launch
    Id fsOwnerId;
    List<GFW_Sync_Object_Mapping__mdt> mdts = new List<GFW_Sync_Object_Mapping__mdt>();
    Map<String,String> extIdFieldNamesMap = new Map<String, String>();
    Map<String,Map<String,GFW_Sync_Field_Mapping__mdt>> gfwFieldMapByMDTName = new Map<String,Map<String,GFW_Sync_Field_Mapping__mdt>>();
    Map<String,Map<String,GFW_Sync_Field_Mapping__mdt>> fsdbFieldMapByMDTName = new Map<String,Map<String,GFW_Sync_Field_Mapping__mdt>>();

    public class attributesWrapper {
        string type;
        string url;
    }
        
    public class recordWrapper {
        attributesWrapper attributes;
        String Name;
        String Id;
        // String AQB__Account__c;
        // String AQB__Gift__c;
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

    // DITCH
    public List<Object> queryGFWObjectForRecords(String objName) {
        GFW_Sync_Query__mdt queryMDT;
        List<Object> records;
        try {
            queryMDT = [
                SELECT MasterLabel, Field_List__c, Where_Clause__c
                FROM GFW_Sync_Query__mdt
                WHERE DeveloperName =:objName
            ];
            String whereClause = !String.isBlank(queryMDT.Where_Clause__c) ? ' ' + queryMDT.Where_Clause__c : '';
            String query='SELECT ' + queryMDT.Field_List__c + ' FROM ' + queryMDT.MasterLabel + whereClause;
            records = doQuery(query);
        } catch (Exception e) {
            System.debug('Unable to retrieve GFW Sync Query custom metadata. Make sure you\'ve passed the correct developer name.');
            // throw new HTTPCalloutFrameworkException(HTTPCalloutFrameworkException.CUSTOM_METADATA_NOT_FOUND);
        }
        return records;
    }

    /*******************
     * INITIALIZE CLASS VARIABLES and CUSTOM METADATA OBJECT/FIELD MAPPINGS
     *******************/
    
    // Retrieve FS User Id who should be Owner of all records created
    public void setFSOwnerId() {
        if (fsRole != null && fsRole != '') fsOwnerId = 
            [SELECT Id FROM User WHERE UserRole.DeveloperName =: fsRole AND IsActive = TRUE LIMIT 1].Id;
    }

    // Retrieve all object mappings
    public void setObjMappingsList() {
        String objName = 'GFW_Sync_Object_Mapping__mdt';
        mdts = Utilities.fetchAllRecords(
            objName,
            null,
            null);
        System.debug('mdts: ' + mdts);
    }

    // Retrieve GFW-based object mapping by mdt name
    public Map<String,GFW_Sync_Object_Mapping__mdt> getObjectMapping(String mdtObjName) {
        Map<String,GFW_Sync_Object_Mapping__mdt> objMap = new Map<String,GFW_Sync_Object_Mapping__mdt>();
        for (GFW_Sync_Object_Mapping__mdt objMDT : mdts) {
            if (objMDT.DeveloperName == mdtObjName) {
                objMap.put(objMDT.GFW_Object_Name__c, objMDT);
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
            'GFW_Sync_Object_Mapping__r.GFW_Object_Name__c'};
        Map<String,GFW_Sync_Field_Mapping__mdt> gfwFieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>();
        Map<String,GFW_Sync_Field_Mapping__mdt> fsdbFieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>();
        String orderByClause = 'ORDER BY GFW_Sync_Object_Mapping__c';
        GFW_Sync_Field_Mapping__mdt[] fieldsMDTs = Utilities.fetchAllRecords(
            objName, relFieldNames, orderByClause);
        // System.debug('fieldsMDTs: ' + fieldsMDTs);
        
        // Build field mapping for each object map
        for (GFW_Sync_Field_Mapping__mdt fmMDT : fieldsMDTs ) {
            // Initialize mdtObjName on first iteration
            if (mdtObjName == '') mdtObjName = fmMDT.GFW_Sync_Object_Mapping__r.DeveloperName;

            if (mdtObjName != fmMDT.GFW_Sync_Object_Mapping__r.DeveloperName) {
            // On next objMap. Populate field mappings for last object and clear map.
                if (gfwFieldMap != null && !gfwFieldMap.isEmpty()) {
                    gfwFieldMapByMDTName.put(mdtObjName, gfwFieldMap);
                    System.debug('gfwFieldMapByMDTName: ' + gfwFieldMapByMDTName);
                }
                if (fsdbFieldMap != null && !fsdbFieldMap.isEmpty()) {
                    fsdbFieldMapByMDTName.put(mdtObjName, fsdbFieldMap);
                }
                gfwFieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>();
                fsdbFieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>();
            }
            mdtObjName = fmMDT.GFW_Sync_Object_Mapping__r.DeveloperName;
            if (fmMDT.GFW_Field_API_Name__c != null && fmMDT.GFW_Field_API_Name__c != '') gfwFieldMap.put(fmMDT.GFW_Field_API_Name__c, fmMDT);
            System.debug('gfwfieldMap: ' + gfwFieldMap);
            if (fmMDT.FSDB_Field_API_Name__c != null && fmMDT.FSDB_Field_API_Name__c != '') fsdbFieldMap.put(fmMDT.FSDB_Field_API_Name__c, fmMDT);
            // System.debug('GFW Field Name: ' + fmMDT.GFW_Field_API_Name__c + '; FSDB Field Name: ' + fmMDT.FSDB_Field_API_Name__c);
        }
        // Add last set of fieldmappings
        if (gfwFieldMap != null && !gfwFieldMap.isEmpty()) {
            gfwFieldMapByMDTName.put(mdtObjName, gfwFieldMap);
        }
        if (fsdbFieldMap != null && !fsdbFieldMap.isEmpty()) {
            fsdbFieldMapByMDTName.put(mdtObjName, fsdbFieldMap);
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
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>(
            fsdbFieldMapByMDTName.get(mdtObjName)
        );
        return fieldMap;
    }

    // Package Ids for WHERE IN query clause.
    public String packageIdsForQuery(Set<Id> Ids) {
        // Ids in quotes, separated by commas, and encased as a whole in parentheses: '(\'a0D1Y000017aM9WUAU\',\'a0D1Y000017aMAYUA2\')'
        String inIDsStr = '(';
        for (Id thisId : Ids) {
            inIDsStr = inIDsStr + '\'' + thisId + '\',';
        }
        inIDsStr = inIDsStr.removeEnd(',') + ')';
        return inIDsStr;
    }

    /*******************
     * RETRIEVE RECORDS FROM GFW AS JSON
     *******************/

    // For Accounts and Contacts, build Ids for records not already in FSDB to insert 
    public Set<Id> recIdsToInsert(String mdtObjName, Set<Id> idsGathered) {
        String gfwObjName = new List<String>(getObjectMapping(mdtObjName).keySet())[0];
        GFW_Sync_Object_Mapping__mdt objMDT = getObjectMapping(mdtObjName).get(gfwObjName);
        String fsdbObjName = objMDT.FSDB_Object_Name__c;
        String inIDsStr = packageIdsForQuery(idsGathered);
        String extIdFieldName = externalIdFieldName(mdtObjName);
        System.debug('external id fieldname for ' + mdtObjName + ': ' + extIdFieldName);
        String whereClause = 'WHERE ' + externalIdFieldName(mdtObjName) + ' IN ' + inIDsStr; 
        Set<Id> idsToQuery = new Set<Id>();
        List<sObject> exstRecs = Utilities.fetchRecords(
            fsdbObjName, whereClause, null);
        System.debug('Existing recs: ' + exstRecs);
        if (exstRecs!=null && !exstRecs.isEmpty()) {
            // Remove existing ids from list
            for (sObject extRec : exstRecs) {
                idsGathered.remove((Id)extRec.get(extIdFieldName));
            }
            idsToQuery.addAll(idsGathered);
        } else {
            // No existing ids - add all recs
            idsToQuery.addAll(idsGathered);
        }
        System.debug('idsToQuery: ' + idsToQuery);
        return idsToQuery;
    }

    // Generate and run query based on mdt record
    public List<Object> queryForRecords(String mdtObjName, Set<Id> idsForQuery, String whereClauseCustom) {
        // Retrieve object and field mappings
        Map<String,GFW_Sync_Object_Mapping__mdt> objMap = getObjectMapping(mdtObjName);
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = getFieldMappingsGFW(mdtObjName);
        System.debug('objMap: ' + objMap);
        List<Object> records;
        if ( !objMap.isEmpty() && !fieldMap.isEmpty() ) {
            // Query GFW for records in Ids list
            String gfwObjName = new List<String>(objMap.keySet())[0];
            List<String> gfwfieldList = new List<String>(fieldMap.keySet());
            String gfwFields = String.join(gfwfieldList, ',');
            String whereClause = '';
            if (idsForQuery != null && !idsForQuery.isEmpty()) {
                String inIDsStr = packageIdsForQuery(idsForQuery);
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
     * BUILD RECORDS IN FSDB
     *******************/

    // Builds records
    public List<sObject> buildRecsWithValues(String mdtObjName, List<Object> records) {
        // Retrieve object and field mappings - somewhat duplicative; could put this together with queryForRecords.
        Map<String,GFW_Sync_Object_Mapping__mdt> objMap = getObjectMapping(mdtObjName);
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = getFieldMappingsFSDB(mdtObjName);
        String gfwObjName = new List<String>(objMap.keySet())[0];
        List<String> fsdbFieldList = new List<String>(fieldMap.keySet());
        // Iterate through FSDB fieldmappings to populate fsdb records with either GFW-queried values or default values if GFW field api name is blank.
        // If merging, do it from here.
        String fsdbObjName = objMap.get(gfwObjName).FSDB_Object_Name__c;
        Map<String, Schema.SObjectField> fieldMapFSDB = Utilities.fieldMapForObject(fsdbObjName);
        String fsdbExternalIdFieldName = objMap.get(gfwObjName).FSDB_External_Id_Field_API_Name__c;
        String fieldType, gfwFieldName;
        List<sObject> objs = new List<sObject>();
        if (records != null && !records.isEmpty()) {
            // Loop through JSON records
            // Retrieve map of objects and record type names in GFW
            for (Object rec : records) {
                sObject sObj = Utilities.newRecord(fsdbObjName);
                Map<String, Object> gfwInfo = (Map<String, Object>) rec;
                System.debug('>>> ' + gfwObjName + ': ' + gfwInfo);
                for (String fsdbFieldName : fsdbFieldList) {
                    GFW_Sync_Field_Mapping__mdt fieldmapMDT = fieldMap.get(fsdbFieldName);
                    // Retrieve field type
                    fieldType = String.valueof(fieldMapFSDB.get(fsdbFieldName).getDescribe().getType());        
                    System.debug('fieldtype: ' + fieldType);
                    gfwFieldName = fieldmapMDT.GFW_Field_API_Name__c;
                    if (gfwFieldName != null) {
                        System.debug('FSDB Field Type for ' + fsdbFieldName + ': ' + fieldType);
                        System.debug('Set this field in FSDB: ' + fieldmapMDT.FSDB_Field_API_Name__c + ' to this value: ' + gfwInfo.get(gfwFieldName));
                        sObj = populateFields(sObj, fieldType, fieldmapMDT, gfwInfo.get(gfwFieldName));
                    } else {
                        // Use default value
                        // TO DO: Cast to type dynamically?
                        sObj.put(fsdbFieldName, fieldmapMDT.DefaultValue__c);
                    }
                } // for each field
                System.debug('sObj to add: ' + sObj);
                objs.add(sObj);
            } // End for each record loop
        } // End if records not empty
        System.debug('List of objs to insert: ' + objs);
        if (objs.size() > 0) {
            List<sObject> testList = new List<sObject>{objs.get(0), objs.get(1), objs.get(2), objs.get(3)};
            Database.UpsertResult[] upsResults = Database.upsert( objs, Utilities.sobjFieldForFieldName(fsdbObjName, fsdbExternalIdFieldName), false);
            System.debug('upsResults: ' + upsResults);
            for(Database.upsertResult result:upsResults) {
                if (result.isSuccess() && result.isCreated()) {
                    System.debug('Success!!' + (Id)result.getId());
                } else {
                    System.debug('Error: ' + result.getErrors());
                }
             }
        }
        return objs;
    }

    // Build records
    // Set value in given field 
    public sObject populateFields(sObject sObj, String fieldType, GFW_Sync_Field_Mapping__mdt fieldmapMDT, Object gfwValue) {
        // TO DO: Add in picklists / record types
        // TO DO: Assign owner? (Add to FieldMapping mdt fsdb Owner field; nothing on GFW field mapping side)
        String fsdbFieldName = fieldmapMDT.FSDB_Field_API_Name__c;
        String relName;
        if (fieldType == 'STRING' || fieldType == 'TEXTAREA' || fieldType == 'EMAIL' || fieldType == 'PICKLIST') {
            // sObj.put(fieldmapMDT.FSDB_Field_API_Name__c, (String)gfwInfo.get(gfwFieldName));
            sObj.put(fsdbFieldName, (String)gfwValue);
        } else if ( fieldType == 'CURRENCY' ) {
            // sObj.put(fieldmapMDT.FSDB_Field_API_Name__c, (Decimal)gfwInfo.get(gfwFieldName));
            sObj.put(fsdbFieldName, (Decimal)gfwValue);
        } else if (fieldType == 'INTEGER') {
            // sObj.put(fieldmapMDT.FSDB_Field_API_Name__c, (Integer)gfwInfo.get(gfwFieldName));
            sObj.put(fsdbFieldName, (Integer)gfwValue);
        } else if (fieldType == 'DATE') {
            // Date dt = date.valueOf((String)gfwInfo.get(gfwFieldName));
            Date dt = date.valueOf((String)gfwValue);
            sObj.put(fsdbFieldName, dt); 
        } else if (fieldType == 'REFERENCE') {
            if (fieldmapMDT.MasterLabel.contains('Account')) {
                // Instantiate new sObject and set that to lookup reference using putSObject 
                Account accountReference = new Account();
                System.debug('external id field name: ' + externalIdFieldName('Account') + 'value: ' + (Id)gfwValue);
                accountReference.put(externalIdFieldName('Account'), (Id)gfwValue);
                relName = Utilities.relationshipNameForField(fieldmapMDT.GFW_Sync_Object_Mapping__r.FSDB_Object_Name__c, fsdbFieldName);
                sObj.putSObject(relName, accountReference);
                System.debug('Relationship name: ' + relName);
            }
        }
        System.debug('sObj from populatefields: ' + sObj);
        return sObj;
    }

    @future
    public static void doUpsert() {

    }

    // HYBRID
    // Upsert records based on Object and field mappings
    public void upsertRecs(String mdtObjName, Set<Id> idsToQuery) {
        // Query GFW for records in Ids list   
        List<Object> records = queryForRecords(mdtObjName, idsToQuery, null);
        System.debug('Query for records: ' + records);

        // THIS IS THE ONE WE NEED FOR BUILDING
        // List<sObject> objsToUpsert = new List<sObject>(buildRecsWithValues(mdtObjName, records));

        // System.debug('Obj to upsert: ' + objs);
        // upsert objs;
    }
 

    /*******************
     * MAIN METHOD
     *******************/
    public void LaunchSync() {
        // Initialize class vars
        setFSOwnerId();
        setObjMappingsList();
        setExternalIdFieldNames();
        setFieldMappings();

        // Retrieve children records and parent Ids
        gatherTransactions();
        gatherGiftCredits();
        gatherOpportunities();

        // Add parent accounts/contacts not already in system
        // gather Account json and Contact json and stash in log records (one for every record?)
        List<Object> records = queryForRecords('Account', recIdsToInsert('Account', acctIds), null);

        // upsertRecs('Account', recIdsToInsert('Account', acctIds));

        // upsertRecs('Contact', recIdsToInsert('Contact', ctIds));

        // Upsert all children records

        // Recurring Donations
        // System.debug('recDonIds: '+recDonIds);
        // upsertRecs('Recurring_Donations', recDonIds);

        // upsert gift/opps and opps, then transactions
        // upsert oppcredits
    }

    public void gatherTransactions() {
        // Retrieve transactions incl soft credit types (don't upsert as Payment records). Assume we have everything linked.
        // Assumes account and opportunity lookups on the Transaction can be relied upon exclusively for gift's account/opportunity.
        System.debug('fsCOA: ' + fsCOA);
        String mdtObjName = 'Transaction_to_Payment';
        String whereClause = ' WHERE AQB__ChartofAccounts__r.Name=\'' + fsCOA + '\' and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';
        List<Object> records = queryForRecords(mdtObjName, null, whereClause);
        if (records != null && records.size()>0) {
            transactionsJSON.add(records);
            for (Object rec : records) {
                // Grab all parent/related Ids
                Map<String, Object> t = (Map<String, Object>) rec;
                System.debug('>>> Transactions: ' + t);
                giftIds.add((Id)t.get('AQB__Gift__c'));
                acctIds.add((Id)t.get('AQB__Account__c'));
                if (t.get('AQB__CreditedOpportunity__c') != null) { oppIds.add((Id)t.get('AQB__CreditedOpportunity__c')); }
                if (t.get('Recurring_Donations__c') != null) { recDonIds.add((Id)t.get('Recurring_Donations__c')); }
            }
        }
    }
    
    // Retrieve gift credits and their linked accounts/contacts from giftIds.
    public void gatherGiftCredits() {
        // Figure out: Account credits, partial credit (amt/percentage)
        // AQB__SecondaryGiftCreditAmount__c,AQB__PrimaryGiftRecognitionCreditPercent__c
        // Retrieve AQB_DonorAccount__c, not Credited Account. Retrieve AQB__ContactId__c, not AQB__ContactCredited__c (deprecated master/detail).
        String mdtObjName = 'GiftCredit_to_OppContactRole';
        String inIDsStr = packageIdsForQuery(giftIds);
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
                    ctIds.add((Id)gc.get('AQB_ContactId__c')); 
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

    // Retrieve Opportunities linked to COA not already gathered via Transactions; add to OppId set and parent Accounts to acctId set
    public void gatherOpportunities() {
        String mdtObjName = 'Opportunity';
        String inIDsStr = packageIdsForQuery(oppIds);
        String whereClause = ' WHERE Chart_of_Accounts__r.Name=\'' + fsCOA + '\' AND Id NOT IN ' + inIDsStr;
        List<Object> records = queryForRecords(mdtObjName, null, whereClause);
        if (records != null && records.size()>0) {
            oppsJSON.add(records);
            for (Object rec : records) {
                Map<String, Object> opp = (Map<String, Object>)rec;
                System.debug('>>> Opportunities: ' + opp);
                acctIds.add((Id)opp.get('AccountId'));
            }
        System.debug('AccountIdsAfterOpps: ' + acctIds);
        }
    }

}
