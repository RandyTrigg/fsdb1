SyncController.packageRelatedIds();

// String query='select Name,Id,AQB__Account__c,AQB__Gift__c from AQB__Transaction__c Where AQB__Method__c = \'Check\' and AQB__Type__c != \'Soft Credit\' and AQB__Posted__c = true LIMIT 100000';
// String query='select Name,Id,AQB__Account__c,AQB__Gift__c from AQB__Transaction__c Where AQB__ChartofAccounts__r.Name=\'FS-BFF\' and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';

// List<Object> recs = SyncController.fetchRecords(query);

// To do: test that batch retrieval really works.
// Stick fieldnames in custom metadata and loop thru. 
// Figure out custom metadata type
    /* for (Object rec : recs) {
        Map<String, Object> t = (Map<String, Object>) rec;
        System.debug('>>> ' + t);
        String giftId = (String) t.get('AQB__Gift__c');
        System.debug('GIFT ID: ' + giftId);
    } */

/*
String query='select Name,Id,AQB__Account__c,AQB__Gift__c from AQB__Transaction__c Where AQB__ChartofAccounts__r.Name=\'FS-BFF\' and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';
String jsonResults = SyncController.doQueryCallout(query);
system.debug('Final results: ' + jsonResults);
*/







// String query='select+Name,Id+from+Account+Where+Id=\'001i000000LUcumAAD\'';
// String query='select+Name,Id,AQB__Account__c,AQB__Gift__c+from+AQB__Transaction__c+Where+AQB__ChartofAccounts__r.Name=\'FS-BFF\'+and+AQB__Posted__c=TRUE+and+%28+AQB__Method__c!=\'Pledge\'+or+AQB__Balance__c%3E0+%29';
/*
HttpRequest req = new HttpRequest();
String query='select Name,Id,AQB__Account__c,AQB__Gift__c from AQB__Transaction__c Where AQB__ChartofAccounts__r.Name=\'FS-BFF\' and AQB__Posted__c=TRUE and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';
String encodeQ = EncodingUtil.urlEncode(query, 'UTF-8');
system.debug('Encoded: ' + encodeQ);
req.setEndpoint('callout:GFW_NamedCredential/services/data/v41.0/query/?q='+encodeQ);
// req.setEndpoint('callout:GFW_NamedCredential/services/data/v25.0/sobjects/Account/001i000000LUcumAAD');
req.setMethod('GET');
Http http = new Http();
HTTPResponse resp = http.send(req);
system.debug('Response status code: ' + resp.getStatusCode());
system.debug('Body:'+resp.getBody());
String response = resp.getBody();
queryReturnResponseWrapper QRRW = (queryReturnResponseWrapper)Json.deserialize(response, queryReturnResponseWrapper.class);
*/
// And then we fetch any required value from this de-serialised response as shown below:
/*
System.debug('QRRW.records[0].Name -> ' +QRRW.records[0].Name);
System.debug('QRRW.totalSize -> '+QRRW.totalSize);
System.debug('QRRW.records[0].attributes.url -> ' +QRRW.records[0].attributes.url);
*/
