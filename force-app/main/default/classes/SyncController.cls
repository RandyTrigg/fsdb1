public with sharing class SyncController {
    
    public SyncController() {

    }

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

    public static String sendHTTPRequest (HTTPCalloutService service) {
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

    public static String doQueryCallout(String queryStr) {        
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

    public static String doQueryNextBatchCallout(String nextRecordsURL) {
        // If there are batches, 'done' should be false;
        // 'nextRecordsUrl' like "/services/data/v54.0/query/01gD0000002HU6KIAW-2000"
        // https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_query.htm
        HTTPCalloutService service = new HTTPCalloutService('GFWQueryNextBatch');
        String nextRecsEndpoint = service.getEndpointURL() + nextRecordsURL;
        service.setEndpointURL(nextRecsEndpoint);
        String results = sendHTTPRequest(service);
        return results;
    }

    public static List<Object> fetchRecords(String queryStr) {
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
        }
        return records;
    }

    public static List<Object> queryGFWObjectForRecords(String objName) {
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

    public static List<String> getFieldNamesForGFWObject(String mdtObjName) {
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



    public static void packageRelatedIds() {
        // For each COA retrieved...
        String fsCOA;
        String fsRole;
        List<FS_Group_Settings__mdt> fsGroups;
        try {
            fsGroups = [
                SELECT GFW_COA_Name__c, Designated_Role_for_Ownership__c
                FROM FS_Group_Settings__mdt
            ];
        } catch (Exception e) {
            System.debug('Unable to retrieve FS Group Settings custom metadata.');
            // throw new HTTPCalloutFrameworkException(HTTPCalloutFrameworkException.CUSTOM_METADATA_NOT_FOUND);
        }
        for (FS_Group_Settings__mdt fs : fsGroups) {
            // For each FS, grab COA and role to assign record ownership
            fsCOA = fs.GFW_COA_Name__c;
            System.debug('fsCOA: ' + fsCOA);
            fsRole = fs.Designated_Role_for_Ownership__c;
            String mdtObjName = 'AQB_Transaction_c';
            // ADD: Not soft credit!
            String query='select Name,Id,AQB__Account__c,AQB__Gift__c,AQB__CreditedOpportunity__c,Recurring_Donations__c from AQB__Transaction__c Where AQB__ChartofAccounts__r.Name=\'' + fsCOA + '\' and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';
            // List<Object> records = queryGFWObjectForRecords(mdtObjName);
            List<Object> records = fetchRecords(query);
            List<Id> transIds = new List<Id>();
            List<Id> giftIds = new List<Id>();
            List<Id> acctIds = new List<Id>();
            List<Id> oppIds = new List<Id>();
            List<Id> recDonId = new List<Id>();
            if (records.size()>0) {
                for (Object rec : records) {
                    Map<String, Object> t = (Map<String, Object>) rec;
                    System.debug('>>> ' + t);
                    transIds.add((Id)t.get('Id'));
                    giftIds.add((Id)t.get('AQB__Gift__c'));
                    acctIds.add((Id)t.get('AQB__Account__c'));
                    oppIds.add((Id)t.get('AQB__CreditedOpportunity__c'));
                    recDonId.add((Id)t.get('Recurring_Donations__c'));
                }
            }
            System.debug('transIds: ' + transIds);
            System.debug('giftIds: ' + giftIds);
            System.debug('acctIds: ' + acctIds);
        }

        // List<Map<String,Object>> recList = (List<Map<String,Object>>)records;

        // recMap = (Map<String, Object>) JSON.deserializeUntyped(nextResults);
        // records.add((List<Object>)m.get('records'));
        
        // jsonResults: {"totalSize":136,"done":true,"records":[{"attributes":{"type":"AQB__Transaction__c","url":"/services/data/v48.0/sobjects/AQB__Transaction__c/a0c1Y00000doofpQAA"},"Name":"000378053","Id":"a0c1Y00000doofpQAA","AQB__Account__c":"0011Y00003HzTDoQAN","AQB__Gift__c":"a0D1Y000017aM9WUAU"}
        
        // Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(jsonResults);
        // Boolean done = (Boolean) m.get('done');

        /* 
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(jsonResults);

        List<Object> records = (List<Object>) m.get('records');
        for (Object rec : records) {
            Map<String, Object> t = (Map<String, Object>) rec;
            System.debug('>>> ' + t);
            String giftId = (String) t.get('AQB__Gift__c');
            System.debug('GIFT ID: ' + giftId);
        }
        */   
        
        /* queryReturnResponseWrapper qryResponse  = (queryReturnResponseWrapper)JSON.deserialize(jsonResults, queryReturnResponseWrapper.class);
        system.debug('Done response: ' + qryResponse.done);
        List<recordWrapper> relRecords = qryResponse.records;
        for (recordWrapper rcd : relRecords) {
            // System.debug('rcd gift Id: ' + rcd.AQB__Gift__c);
            // NOTE: Have to figure out how to deal with the double underscores??!
        } */
    
    }


}
