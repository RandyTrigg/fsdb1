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

    public List<Object> fetchRecords(String queryStr) {
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
            records = fetchRecords(query);
        } catch (Exception e) {
            System.debug('Unable to retrieve GFW Sync Query custom metadata. Make sure you\'ve passed the correct developer name.');
            // throw new HTTPCalloutFrameworkException(HTTPCalloutFrameworkException.CUSTOM_METADATA_NOT_FOUND);
        }
        return records;
    }

    // MAY DITCH
    public List<String> getFieldNamesForGFWObject(String mdtObjName) {
        List<String> fldNames;
        GFW_Sync_Query__mdt queryMDT;
        try {
            queryMDT = [
                SELECT MasterLabel, Field_List__c, Where_Clause__c
                FROM GFW_Sync_Query__mdt
                WHERE DeveloperName =:mdtObjName
            ];
            fldNames = queryMDT.Field_List__c.split(',');
        } catch (Exception e) {
            System.debug('Unable to retrieve GFW Sync Query custom metadata. Make sure you\'ve passed the correct developer name.');
            // throw new HTTPCalloutFrameworkException(HTTPCalloutFrameworkException.CUSTOM_METADATA_NOT_FOUND);
        }
        return fldNames;
    }


    public void LaunchSync() {
        System.debug('fsCOA: ' + fsCOA);
        String mdtObjName = 'AQB_Transaction_c';
        // Soft credits: Included in query but don't create transaction records for them. Assume we have everything linked.
        String query='select Name,Id,AQB__Account__c,AQB__Gift__c,AQB__CreditedOpportunity__c,Recurring_Donations__c from AQB__Transaction__c Where AQB__ChartofAccounts__r.Name=\'' + fsCOA + '\' and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';
        // List<Object> records = queryGFWObjectForRecords(mdtObjName);
        List<Object> records = fetchRecords(query);
        if (records.size()>0) {
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
        // Retrieve gift credits and gather related accounts and contacts
        gatherGiftCredits();
        // Upsert Recurring Donations
    }

    public void gatherGiftCredits() {
        // Retrieve gift credits and their linked accounts/contacts from giftIds. Partial credit?
        
        // Package list of giftIds for WHERE IN clause:
        // Ids in quotes, separated by commas, and encased as a whole in parentheses: '(\'a0D1Y000017aM9WUAU\',\'a0D1Y000017aMAYUA2\')'
        String inIDsStr = '(';
        List<Id> giftIdsList = new List<Id>(giftIds);
        // Integer i = 0;
        for (Id giftId : giftIdsList) {
            inIDsStr = inIDsStr + '\'' + giftId + '\',';
            // System.debug(i+1);
            // i++;
        }
        inIDsStr = inIDsStr.removeEnd(',') + ')';

        String query='select Id,AQB__DonorAccount__c,AQB__ContactId__c,AQB__ContactId__r.AccountId,AQB__SecondaryGiftCreditAmount__c,AQB__PrimaryGiftRecognitionCreditPercent__c FROM AQB__GiftCredit__c WHERE AQB__GiftId__c IN ' + inIDsStr;
        // Retrieve AQB_DonorAccount__c, not Credited Account. And AQB__ContactId__c, not AQB__ContactCredited__c (deprecated master/detail).
        List<Object> records = fetchRecords(query);
        Map<String, Object> pAcct;
        if (records != null && records.size()>0) {
            upsGCList.add(records);
            for (Object rec : records) {
                Map<String, Object> gc = (Map<String, Object>) rec;
                System.debug('>>> ' + gc);
                if (gc.get('AQB__DonorAccount__c') != null) { acctIds.add((Id)gc.get('AQB__DonorAccount__c')); }
                if (gc.get('AQB__ContactId__c') != null) { ctIds.add((Id)gc.get('AQB__ContactId__c')); }
                // Retrieve contact's parent account from nested json: AQB__ContactId__r={AccountId=0011Y00003HzuHRQAZ, attributes={type=Contact...
                pAcct = (gc.get('AQB__ContactId__r') != null) ? (Map<String, Object>)gc.get('AQB__ContactId__r') : null;
                if (pAcct != null) { acctIds.add((Id)pAcct.get('AccountId')); }
                System.debug('AccountId: ' + (Id)gc.get('AQB__DonorAccount__c'));
                System.debug('ContactId: ' + (Id)gc.get('AQB__ContactId__c'));
                System.debug('GC Contact Parent AccountId: ' + (Id)pAcct.get('AccountId'));
            }
        }
        System.debug('giftcredits: ' + upsGCList);
        System.debug('acctIds: ' + acctIds);
    }
}
