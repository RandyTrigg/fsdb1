public without sharing class SyncController {
    
    // Public variables for this FS SyncController instance.
    public Set<Id> acctIds = new Set<Id>();
    public Set<Id> ctIds = new Set<Id>();
    public Set<Id> giftIds = new Set<Id>();
    public Set<Id> oppIds = new Set<Id>();
    public Set<Id> recDonIds = new Set<Id>();
    public List<Object> transactionsJSON = new List<Object>();
    public List<Object> gcsJSON = new List<Object>();
    public List<Account> upsAcctList = new List<Account>();
    public List<Contact> upsCtList = new List<Contact>();

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
        // system.debug('Final results: ' + jsonResults);
        List<Object> records;
        if (!jsonResults.startsWith('Error:')) {
            queryReturnResponseWrapper qryResponse  = (queryReturnResponseWrapper)JSON.deserialize(jsonResults, queryReturnResponseWrapper.class);
            Boolean done = qryResponse.done;
            system.debug('Done response: ' + done);
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
            System.debug('error results: ' + jsonResults);
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

    // Retrieve all object mappings
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

    // Retrieve map of FSDB External Id field name to ObjectMapping mdt Name
    public Map<String,String> getExternalIdFieldNames() {
        List<GFW_Sync_Object_Mapping__mdt> objMDTs = new List<GFW_Sync_Object_Mapping__mdt>(getObjectMappingsList());
        Map<String,String> extIdFieldNamesMap = new Map<String,String>();
        for (GFW_Sync_Object_Mapping__mdt objMDT : objMDTs) {
            extIdFieldNamesMap.put(objMDT.DeveloperName, objMDT.FSDB_External_Id_Field_API_Name__c);
        }
        return extIdFieldNamesMap;
    }

    // Retrieve External Id field name from ObjectMapping mdt Name
    public String externalIdFieldName(String mdtObjName) {
        return (String)getExternalIdFieldNames().get(mdtObjName);
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
            fieldMap.put(fmMDT.GFW_Field_API_Name__c, fmMDT);
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

    /****** MAIN METHOD ******/
    public void LaunchSync() {
        // Retrieve children records and parent Ids
        gatherTransactions();
        gatherGiftCredits();
        gatherOpportunities(); 
        // Upsert (?)/ Add parent accounts/contacts not already in system (soql query where external id in list)
        upsertAcctsAndContacts();

        // Upsert all children records
        System.debug('recDonIds: '+recDonIds);
        upsertRecurringDonations();
        // upsert gift/opps, then transactions
        // upsert gift/oppcredits
    }

    public void gatherTransactions() {
        System.debug('fsCOA: ' + fsCOA);
        String mdtObjName = 'AQB_Transaction_c';
        // Query of transactions includes soft credit types (don't upsert as Payment records). Assume we have everything linked.
        // To do: Create Transactions mdt field mappings and gather string of query fields from there.
        // Retrieve field and object names from mdt
        String query='select Name,Id,AQB__Account__c,AQB__Gift__c,AQB__CreditedOpportunity__c,Recurring_Donations__c from AQB__Transaction__c Where AQB__ChartofAccounts__r.Name=\'' + fsCOA + '\' and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';
        List<Object> records = queryRecords(query);
        if (records != null && records.size()>0) {
            transactionsJSON.add(records);
            for (Object rec : records) {
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
        // Partial credit?
        String inIDsStr = packageIdsForQuery(giftIds);
        String query='select Id,AQB__DonorAccount__c,AQB__ContactId__c,AQB__ContactId__r.AccountId,AQB__SecondaryGiftCreditAmount__c,AQB__PrimaryGiftRecognitionCreditPercent__c FROM AQB__GiftCredit__c WHERE AQB__GiftId__c IN ' + inIDsStr;
        // Retrieve AQB_DonorAccount__c, not Credited Account. Retrieve AQB__ContactId__c, not AQB__ContactCredited__c (deprecated master/detail).
        // Add this to mdts
        List<Object> records = queryRecords(query);
        Map<String, Object> pAcct;
        if (records != null && records.size()>0) {
            gcsJSON.add(records);
            // Build Map<Id, AQB__GiftCredit__c(json)> for building OppCredits? External Id for OppCredits?
            for (Object rec : records) {
                Map<String, Object> gc = (Map<String, Object>)rec;
                System.debug('>>> Gift Credits: ' + gc);
                if (gc.get('AQB__DonorAccount__c') != null) { acctIds.add((Id)gc.get('AQB__DonorAccount__c')); }
                if (gc.get('AQB__ContactId__c') != null) { ctIds.add((Id)gc.get('AQB__ContactId__c')); }
                // Retrieve contact's parent account from nested json: AQB__ContactId__r={AccountId=0011Y00003HzuHRQAZ, attributes={type=Contact...
                pAcct = (gc.get('AQB__ContactId__r') != null) ? (Map<String, Object>)gc.get('AQB__ContactId__r') : null;
                if (pAcct != null) { acctIds.add((Id)pAcct.get('AccountId')); }
                // System.debug('AccountId: ' + (Id)gc.get('AQB__DonorAccount__c'));
                // System.debug('ContactId: ' + (Id)gc.get('AQB__ContactId__c'));
                // System.debug('GC Contact Parent AccountId: ' + (Id)pAcct.get('AccountId'));
            }
        }
        // System.debug('giftcredits: ' + gcsJSON);
        // System.debug('acctIds: ' + acctIds);
    }

    // Retrieve all Opportunities linked to COA; add to OppId set and parent Accounts to acctId set
    public void gatherOpportunities() {

    }

    public void upsertAcctsAndContacts() {
        System.debug('inside upsert accounts and contacts');
    }

    // Add/update FSDB recurring donations
    public void upsertRecurringDonations() {
        // Query related Recurring Donations and relevant field mappings
        // Genericize if we can dynamically set fields (parameters: mdtObjName and IdsList)
        // Assumes subset of fields for all those objects would be controlled exclusively by sync and GFW as source
        String mdtObjName = 'Recurring_Donations'; // Custom mdt name
        // Retrieve mappings: which GFW object corresponds to which FSDB object; GFW fields that correspond to FSDB fields
        Map<String,GFW_Sync_Object_Mapping__mdt> objMap = getObjectMapping(mdtObjName);
        System.debug('objMap: ' + objMap);
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = getFieldMappings(mdtObjName);
        if ( !objMap.isEmpty() && !fieldMap.isEmpty() ) {
            // Query GFW for Recurring Donations in Ids list
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
                }

                System.debug('Recurring donations to upsert: ' + objs);
                // upsert objs;
                // Database.UpsertResult[] resultsRC = Database.upsert( objs, Unit_of_Service__c.Fields.KLAS_MatRequestLineObj__c, false);

            }
        }


    }
}
