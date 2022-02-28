public without sharing class SyncController {
    
    // Public variables for this FS SyncController instance.
    public Set<Id> acctIds = new Set<Id>();
    public Set<Id> ctIds = new Set<Id>();
    public Set<Id> transIds = new Set<Id>();
    public Set<Id> giftIds = new Set<Id>();
    public Set<Id> oppIds = new Set<Id>();
    public Set<Id> recDonIds = new Set<Id>();
    public List<Account> upsAcctList = new List<Account>();
    public List<Contact> upsCtList = new List<Contact>();
    public List<Object> upsGCList = new List<Object>();
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

    // Retrieve object mapping for querying GFW
    public Map<String,String> getObjectMappings(String mdtObjName) {
        Map<String,String> objMap = new Map<String,String>();
        String objName = 'GFW_Sync_Object_Mapping__mdt';
        String whereClause = 'WHERE DeveloperName = \'' + mdtObjName + '\'';
        GFW_Sync_Object_Mapping__mdt objectMDT = (GFW_Sync_Object_Mapping__mdt)Utilities.fetchRecords(
            objName,
            whereClause,
            null)[0];
        objMap.put(objectMDT.GFW_Object_Name__c, objectMDT.FSDB_Object_Name__c);
        System.debug('objMap: '+ objMap);
        return objMap;
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
            System.debug('GFW Field Name: ' + fmMDT.GFW_Field_API_Name__c + '; FSDB Field Name: ' + fmMDT.FSDB_Field_API_Name__c);
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

    public void LaunchSync() {
        System.debug('fsCOA: ' + fsCOA);
        String mdtObjName = 'AQB_Transaction_c';
        // Soft credits: Included in query but don't create transaction records for them. Assume we have everything linked.
        String query='select Name,Id,AQB__Account__c,AQB__Gift__c,AQB__CreditedOpportunity__c,Recurring_Donations__c from AQB__Transaction__c Where AQB__ChartofAccounts__r.Name=\'' + fsCOA + '\' and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';
        // List<Object> records = queryGFWObjectForRecords(mdtObjName);
        List<Object> records = queryRecords(query);
        if (records != null && records.size()>0) {
            for (Object rec : records) {
                Map<String, Object> t = (Map<String, Object>) rec;
                System.debug('>>> ' + t);
                transIds.add((Id)t.get('Id'));
                giftIds.add((Id)t.get('AQB__Gift__c'));
                acctIds.add((Id)t.get('AQB__Account__c'));
                if (t.get('AQB__CreditedOpportunity__c') != null) { oppIds.add((Id)t.get('AQB__CreditedOpportunity__c')); }
                if (t.get('Recurring_Donations__c') != null) { recDonIds.add((Id)t.get('Recurring_Donations__c')); }
            }
        }
        System.debug('recDonIds: '+recDonIds);
        // Retrieve gift credits and related account and contact Ids
        gatherGiftCredits();
        // gather Opportunities linked to COA (and not to Transactions?)
        upsertAcctsAndContacts();
        upsertRecurringDonations();
        // upsert gift/opps and then transactions
        // upsert gift credits
    }

    public void gatherGiftCredits() {
        // Retrieve gift credits and their linked accounts/contacts from giftIds. Partial credit?
        // Convert giftIds to string for WHERE IN clause.
        String inIDsStr = packageIdsForQuery(giftIds);
        String query='select Id,AQB__DonorAccount__c,AQB__ContactId__c,AQB__ContactId__r.AccountId,AQB__SecondaryGiftCreditAmount__c,AQB__PrimaryGiftRecognitionCreditPercent__c FROM AQB__GiftCredit__c WHERE AQB__GiftId__c IN ' + inIDsStr;
        // Retrieve AQB_DonorAccount__c, not Credited Account. And AQB__ContactId__c, not AQB__ContactCredited__c (deprecated master/detail).
        List<Object> records = queryRecords(query);
        Map<String, Object> pAcct;
        if (records != null && records.size()>0) {
            upsGCList.add(records);
            for (Object rec : records) {
                Map<String, Object> gc = (Map<String, Object>)rec;
                System.debug('>>> ' + gc);
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
        // System.debug('giftcredits: ' + upsGCList);
        // System.debug('acctIds: ' + acctIds);
    }

    public void upsertAcctsAndContacts() {

    }

    public void upsertRecurringDonations() {
        // Query related Recurring Donations and relevant field mappings
        // Is there a way to genericize this if we can declaratively set fields?
        String inIDsStr = packageIdsForQuery(recDonIds);
        String objName = 'Recurring_Donations'; // Custom mdt name
        Map<String,String> objMap = getObjectMappings(objName);
        Map<String,GFW_Sync_Field_Mapping__mdt> fieldMap = getFieldMappings(objName);
        if ( !objMap.isEmpty() && !fieldMap.isEmpty() ) {
            String gfwObj = new List<String>(objMap.keySet())[0];
            List<String> gfwfieldList = new List<String>(fieldMap.keySet());
            String gfwFields = String.join(gfwfieldList, ',');
            System.debug('RD objname: ' + gfwObj + '; RD fields: ' + gfwFields);
            String query='select ' + gfwFields + ' FROM ' + gfwObj + ' WHERE Id IN ' + inIDsStr;
            List<Object> records = queryRecords(query);
            String fsdbObj = objMap.get(gfwObj);
            System.debug('fsdb obj name: ' + fsdbObj);
            if (!records.isEmpty()) {
                sObject sObj = Schema.getGlobalDescribe().get(fsdbObj).newSObject();
                for (Object rec : records) {
                    Map<String, Object> rd = (Map<String, Object>) rec;
                    System.debug('>>> ' + rd);
                    for (String gfwFieldName : gfwfieldList) {
                        GFW_Sync_Field_Mapping__mdt fieldmapMDT = fieldMap.get(gfwFieldName);
                        // Set actual FSDB field with value from json
                        // fieldmapMDT.FSDB_Field_API_Name__c = rd.get(gfwFieldName);
                        // Figure out how to compose this declaratively.
                        // Schema.DisplayType fielddataType = fieldMap.get(fieldmapMDT.FSDB_Field_API_Name__c).getDescribe().getType();
                        // String fieldType;
                        /*if (fielddataType == Schema.DisplayType.Integer) {
                            // How to cast data correctly?
                            // fieldType = 'Integer';
                            System.debug('field type: ' + fieldmapMDT.FSDB_Field_API_Name__c + ' is integer.');
                        } else {
                            System.debug('field type: ' + fieldmapMDT.FSDB_Field_API_Name__c + ' is not an integer.');
                        } */
                        System.debug('Set this field in FSDB: ' + fieldmapMDT.FSDB_Field_API_Name__c + ' to this value: ' + rd.get(gfwFieldName));
                    }
                }

            }
        }


    }
}
