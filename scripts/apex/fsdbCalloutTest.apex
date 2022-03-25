// For each COA retrieved...
  
        String fsRole;
        List<FS_Group_Settings__mdt> fsGroups;
        
        // Run sync for each FS COA
        fsGroups = [SELECT GFW_COA_Name__c, Designated_Role_for_Ownership__c
            FROM FS_Group_Settings__mdt
        ];

        if (fsGroups != null && !fsGroups.isEmpty()) {
            for (FS_Group_Settings__mdt fs : fsGroups) {
                // For each FS, grab COA and role to assign record ownership             
                SyncController scThisFS = new SyncController();
 
                scThisFS.startDateTime = datetime.now();
                scThisFS.fsCOA = fs.GFW_COA_Name__c;
                scThisFS.fsRole = fs.Designated_Role_for_Ownership__c;
                scThisFS.LaunchSync();

                // , 'Recurring_Donations'
/*        
                List<sObject> ls = new List<sObject>();               
                ls = scThisFS.buildRecsToUpsert('Recurring_Donations');
                system.debug('Here is the final list: ' + ls);
*/
            }
        }   



/*
        // BATCHABLE
        List<String> objNames = new List<String>{'Account', 'Contact', 'Recurring_Donations'};
        Id batchInstanceId = Database.executeBatch(new Sync_BatchableUpsert(objNames), 5);
        System.debug('batchInstanceId: ' + batchInstanceId);
*/



        // QUEUEABLE
        // System.enqueueJob(new Sync_Queueable());


        // String relName = Utilities.relationshipNameForField('npe03__Recurring_Donation__c', 'npe03__Organization__c');
        // System.debug('relname: ' + relName);
        


        /*
        SyncController scThisFS = new SyncController();
        List<GFW_Sync_Object_Mapping__mdt> newList = new List<GFW_Sync_Object_Mapping__mdt>(SyncController.getObjectMappingsList());
        System.debug('list: ' + newList);
        */


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
