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
        String AQB__Account__c;
        String AQB__Gift__c;
        public recordWrapper (){
            attributes = new attributesWrapper();
        }
    }
        
    public class queryReturnResponseWrapper{
        String done;
        String totalSize;
        list<recordWrapper> records;
    }
        

    @TestVisible private class ContactInfo {
        @TestVisible String DedupeKey;
        @TestVisible Boolean isMaster;
        @TestVisible Boolean ShouldMerge;
        @TestVisible Id Id;
        @TestVisible Id AccountId;
    }
    @TestVisible private class AccountMerges {
        @TestVisible List<AccountInfo> rows;
    }
    // NOTE: Apex doesn't allow double underscore in variable names. So we'll need to modify the column name from Dedupe_key__c to Dedupe_key.
    @TestVisible private class AccountInfo {
        @TestVisible String DedupeKey;
        @TestVisible String Dedupe_key;
        @TestVisible Boolean isMaster;
        @TestVisible Boolean ShouldMerge;
        @TestVisible Id Id;
    }


    public static String doQueryCallout(String queryStr) {
        // NOTE: Need to add in batch processing:
        // https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_query.htm
        
        // Performs GET request using SOQL query parameter
        // Returns JSON result or error starting with response status code
        
        // Instantiate callout service for named credential GFWQuery
        HTTPCalloutService service = new HTTPCalloutService('GFWQuery');
        System.debug(service.getRequest());
        
        // Set query parameter in URL and sends request
        // Sample queryStr: 'select Name from AQB__Transaction__c Where...'
        String encodeQ = EncodingUtil.urlEncode(queryStr, 'UTF-8');
        Service.setURLParameter('q', encodeQ);
        // System.debug(service.getRequest());
        HTTPResponse response = service.sendRequest();
        // System.debug(response.getStatusCode());
        // System.debug(response.getBody());
        if (response.getStatusCode() == service.getSuccessStatusCode()) {
            return response.getBody();
        } else
        {
            return 'Error: ' + string.valueof(response.getStatusCode() + '; Callout = ' + service.getRequest());
        }
    }

    public static void packageRelatedIds() {
        String query='select Name,Id,AQB__Account__c,AQB__Gift__c from AQB__Transaction__c Where AQB__ChartofAccounts__r.Name=\'FS-BFF\' and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';
        String jsonResults = doQueryCallout(query);
        system.debug('Final results: ' + jsonResults);
        queryReturnResponseWrapper qryResponse  = (queryReturnResponseWrapper)JSON.deserialize(jsonResults, queryReturnResponseWrapper.class);
        system.debug('Done response: ' + qryResponse.done);
        List<recordWrapper> relRecords = qryResponse.records;
        for (recordWrapper rcd : relRecords) {
            System.debug('rcd gift Id: ' + rcd.AQB__Gift__c);
            // NOTE: Have to figure out how to deal with the double underscores??!
        }


    }


}
