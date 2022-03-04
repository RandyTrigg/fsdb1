public without sharing class SyncController {
    
    // Public variables for this FS SyncController instance.
    public Set<Id> acctIds = new Set<Id>();
    public Set<Id> ctIds = new Set<Id>();
    public Set<Id> giftIds = new Set<Id>();
    public Set<Id> oppIds = new Set<Id>();
    public Set<Id> recDonIds = new Set<Id>();
    public List<Object> transactionsJSON = new List<Object>();
    public List<Object> gcsJSON = new List<Object>();
    public List<Object> oppsJSON = new List<Object>();
    public List<Account> upsAcctList = new List<Account>();
    public List<Contact> upsCtList = new List<Contact>();
    
    // Initialized on
    Map<String,String> extIdFieldNamesMap = new Map<String, String>();
    List<GFW_Sync_Object_Mapping__mdt> mdts = new List<GFW_Sync_Object_Mapping__mdt>();

    public String fsCOA;
    public String fsRole;

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
        // 'nextRecordsUrl' like "/services/data/v54.0/query/01gD0000002HU6KIAW-2000"
        // https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_query.htm
        HTTPCalloutService service = new HTTPCalloutService('GFWQueryNextBatch');
        String nextRecsEndpoint = service.getEndpointURL() + nextRecordsURL;
        service.setEndpointURL(nextRecsEndpoint);
        String results = sendHTTPRequest(service);
        return results;
    }

    public List<Object> queryRecords(String queryStr) {
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
                // Remaining records must be retrieved in batches
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

    // MAY DITCH
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
            records = queryRecords(query);
        } catch (Exception e) {
            System.debug('Unable to retrieve GFW Sync Query custom metadata. Make sure you\'ve passed the correct developer name.');
            // throw new HTTPCalloutFrameworkException(HTTPCalloutFrameworkException.CUSTOM_METADATA_NOT_FOUND);
        }
        return records;
    }

    /*******************
     * CUSTOM METADATA OBJECT/FIELD MAPPINGS
     *******************/
    // Retrieve all object mappings

    // HOW to initialize this
    public List<GFW_Sync_Object_Mapping__mdt> getObjectMappingsList() {
        String objName = 'GFW_Sync_Object_Mapping__mdt';
        GFW_Sync_Object_Mapping__mdt[] mdts = Utilities.fetchAllRecords(
            objName,
            null);
        return mdts;
    }

    // Retrieve object mapping by mdt name
    public Map<String,GFW_Sync_Object_Mapping__mdt> getObjectMapping(String mdtObjName) {
        List<GFW_Sync_Object_Mapping__mdt> objMDTs = new List<GFW_Sync_Object_Mapping__mdt>(getObjectMappingsList());
        Map<String,GFW_Sync_Object_Mapping__mdt> objMap = new Map<String,GFW_Sync_Object_Mapping__mdt>();
        for (GFW_Sync_Object_Mapping__mdt objMDT : objMDTs) {
            if (objMDT.DeveloperName == mdtObjName) {
                objMap.put(objMDT.GFW_Object_Name__c, objMDT);
            }
        }
        return objMap;
    }

    // Initialize map of FSDB External Id field name to ObjectMapping mdt Name
    public void getExternalIdFieldNames() {
        List<GFW_Sync_Object_Mapping__mdt> objMDTs = new List<GFW_Sync_Object_Mapping__mdt>(getObjectMappingsList());
        Map<String,String> extIdFieldNamesMap = new Map<String,String>();
        for (GFW_Sync_Object_Mapping__mdt objMDT : objMDTs) {
            extIdFieldNamesMap.put(objMDT.DeveloperName, objMDT.FSDB_External_Id_Field_API_Name__c);
        }
    }

    // Retrieve External Id field name from ObjectMapping mdt Name
    public String externalIdFieldName(String mdtObjName) {
        return (String)extIdFieldNamesMap.get(mdtObjName);
    }

    // Retrieve field mappings for querying GFW
    public Map<String,GFW_Sync_Field_Mapping__mdt> getFieldMappings(String mdtObjName) {
        String objName = 'GFW_Sync_Field_Mapping__mdt';
        String whereClause = 'WHERE GFW_Sync_Object_Mapping__r.DeveloperName = \'' + mdtObjName + '\'';
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = new Map<String,GFW_Sync_Field_Mapping__mdt>();
        GFW_Sync_Field_Mapping__mdt[] fieldsMDTs = Utilities.fetchRecords(
            objName,
            whereClause,
            null);
        for (GFW_Sync_Field_Mapping__mdt fmMDT : fieldsMDTs ) {
            if (fmMDT.GFW_Field_API_Name__c != null && fmMDT.GFW_Field_API_Name__c != '') fieldMap.put(fmMDT.GFW_Field_API_Name__c, fmMDT);
            // System.debug('GFW Field Name: ' + fmMDT.GFW_Field_API_Name__c + '; FSDB Field Name: ' + fmMDT.FSDB_Field_API_Name__c);
        }
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

    // Generate and run query based on mdt record
    public List<Object> queryForRecords(String mdtObjName, Set<Id> idsForQuery, String whereClauseCustom) {
        // Retrieve mappings: which GFW object corresponds to which FSDB object; GFW fields that correspond to FSDB fields
        Map<String,GFW_Sync_Object_Mapping__mdt> objMap = getObjectMapping(mdtObjName);
        System.debug('objMap: ' + objMap);
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = getFieldMappings(mdtObjName);
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
            String query='select ' + gfwFields + ' FROM ' + gfwObjName + whereClause;
            records = queryRecords(query);
        }
        return records;
    }

    public Set<Id> recIdsToInsert(String mdtObjName, Set<Id> idsGathered) {
        String gfwObjName = new List<String>(getObjectMapping(mdtObjName).keySet())[0];
        String inIDsStr = packageIdsForQuery(idsGathered);
        String extIdFieldName = externalIdFieldName(mdtObjName);
        String whereClause = 'WHERE ' + externalIdFieldName(mdtObjName) + ' IN ' + inIDsStr; 
        Set<Id> idsToQuery = new Set<Id>();
        List<sObject> exstRecs = Utilities.fetchRecords(
            gfwObjName, whereClause, null);
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

    // Upsert records based on Object and field mappings
    public void upsertRecs(String mdtObjName, Set<Id> idsToQuery) {
        // Retrieve object and field mappings
        Map<String,GFW_Sync_Object_Mapping__mdt> objMap = getObjectMapping(mdtObjName);
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = getFieldMappings(mdtObjName);
        if ( !objMap.isEmpty() && !fieldMap.isEmpty() ) {
            // Query GFW for records in Ids list
            String gfwObjName = new List<String>(objMap.keySet())[0];
            List<String> gfwfieldList = new List<String>(fieldMap.keySet());
            String gfwFields = String.join(gfwfieldList, ',');
            String inIDsStr = packageIdsForQuery(recDonIds);
            String query='select ' + gfwFields + ' FROM ' + gfwObjName + ' WHERE Id IN ' + inIDsStr;
            List<Object> records = queryRecords(query);
            String fsdbObjName = objMap.get(gfwObjName).FSDB_Object_Name__c;
            String fieldType, fsdbFieldName;
            List<sObject> objs = new List<sObject>();
            if (!records.isEmpty()) {
                // Loop through Recurring Donation JSON records
                for (Object rec : records) {
                    sObject sObj = Utilities.newRecord(fsdbObjName);
                    Map<String, Object> gfwInfo = (Map<String, Object>) rec;
                    System.debug('>>> Recurring Donations' + gfwInfo);
                    for (String gfwFieldName : gfwfieldList) {
                        GFW_Sync_Field_Mapping__mdt fieldmapMDT = fieldMap.get(gfwFieldName);
                        // Retrieve field type
                        fsdbFieldName = fieldmapMDT.FSDB_Field_API_Name__c;
                        fieldType = Utilities.fieldTypeOfField(fsdbObjName, fsdbFieldName);
                        System.debug('fieldtype: ' + fieldType);
                        if (gfwInfo.get(gfwFieldName)!= null) {
                            if (fieldType == 'STRING' || fieldType == 'TEXTAREA' || fieldType == 'EMAIL' || fieldType == 'PICKLIST') {
                                sObj.put(fieldmapMDT.FSDB_Field_API_Name__c, (String)gfwInfo.get(gfwFieldName));
                            } else if ( fieldType == 'CURRENCY' ) {
                                sObj.put(fieldmapMDT.FSDB_Field_API_Name__c, (Decimal)gfwInfo.get(gfwFieldName));
                            } else if (fieldType == 'INTEGER') {
                                sObj.put(fieldmapMDT.FSDB_Field_API_Name__c, (Integer)gfwInfo.get(gfwFieldName));
                            } else if (fieldType == 'DATE') {
                                Date dt = date.valueOf((String)gfwInfo.get(gfwFieldName));
                                sObj.put(fieldmapMDT.FSDB_Field_API_Name__c, dt); 
                            } else if (fieldType == 'REFERENCE') {
                                if (fieldmapMDT.MasterLabel.contains('Account')) {
                                    Account accountReference = new Account();
                                    System.debug('external id field name: ' + externalIdFieldName('Account') + 'value: ' + (Id)gfwInfo.get(gfwFieldName));
                                    accountReference.put(externalIdFieldName('Account'), (Id)gfwInfo.get(gfwFieldName));
                                    // GFW_Account_ID__c=(Id)gfwInfo.get(gfwFieldName));
                                    sObj.putSObject(fieldmapMDT.FSDB_Field_API_Name__c.replace('__c', '__r'), accountReference);
                                    // npe03__Recurring_Donation__c rdon = (npe03__Recurring_Donation__c)sObj;
                                    // rdon.npe03__Organization__r = accountReference;
                                    // sObj = (sObject)rdon;
                                }

                            }
                        }
                        System.debug('FSDB Field Type for ' + fsdbFieldName + ': ' + fieldType);
                        System.debug('Set this field in FSDB: ' + fieldmapMDT.FSDB_Field_API_Name__c + ' to this value: ' + gfwInfo.get(gfwFieldName));
                    }
                    System.debug('sObj to add: ' + sObj);
                    objs.add(sObj);
                } // For loop

                System.debug('Recurring donations to upsert: ' + objs);
                // upsert objs;
                // Database.UpsertResult[] resultsRC = Database.upsert( objs, Unit_of_Service__c.Fields.KLAS_MatRequestLineObj__c, false);

            } // If
        } // If fieldmap not empty
    }
 

    /*******************
     * MAIN METHOD
     *******************/
    public void LaunchSync() {
        // Initialize vars
        getExternalIdFieldNames();
        // Retrieve children records and parent Ids
        gatherTransactions();
        gatherGiftCredits();
        gatherOpportunities(); 
        // Add parent accounts/contacts not already in system
        addNewAcctsAndContacts();

        // Upsert all children records
        System.debug('recDonIds: '+recDonIds);
        upsertRecurringDonations();
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

    public void addNewAcctsAndContacts() {
        // Only add Accounts and Contacts in FSDB that have no matching GFW External Ids from queried records 
        System.debug('inside upsert accounts and contacts');
        String mdtObjName = 'Account';
        upsertRecs(mdtObjName, recIdsToInsert(mdtObjName, acctIds));
        // handle the result? Or just log it!

        mdtObjName = 'Contact';
        upsertRecs(mdtObjName, recIdsToInsert(mdtObjName, ctIds));
        // handle the result? Or just log it!
    }

    // Add/update FSDB recurring donations
    public void upsertRecurringDonations() {
        // Query related Recurring Donations and relevant field mappings
        // Genericize if we can dynamically set fields (parameters: mdtObjName and IdsList)
        // Assumes subset of fields for all those objects would be controlled exclusively by sync and GFW as source
        String mdtObjName = 'Recurring_Donations'; // Custom mdt name
        upsertRecs(mdtObjName, recDonIds);

    }
}
