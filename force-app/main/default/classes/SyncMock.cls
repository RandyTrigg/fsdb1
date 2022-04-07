@isTest
global class SyncMock implements HttpCalloutMock {

    // Full response body from callout for Account record from GFW.
    private String responseBodyAccountFull = '' +
    '{' +
    '"done" : true, ' +
    '"totalSize" : 14,' +
    '"records" : ' +
    '[ { "attributes" : ' +
    '{"type" : "Account",' +
    '"url" : "/services/data/v54.0/sobjects/Account/001D000000IRFmaIAH"},' +  
    '"Name" : "Test 1"},' + 
    '{ "attributes" : ' +
    '{"type" : "Account",' +
    '"url" : "/services/data/v54.0/sobjects/Account/001D000000IomazIAB"},' +
    '"Name" : "Test 2"}' +
    ']}';

    // Full response body from callout for Account record from GFW.
    private String responseBodyFull = '' +
    '{' +
    '"done" : true, ' +
    '"totalSize" : 14,' +
    '"records" : ' +
    '[ { "attributes" : ' +
    '{"type" : "Account",' +
    '"url" : "/services/data/v54.0/sobjects/Account/001D000000IRFmaIAH"},' +  
    '"Name" : "Test 1",' + 
    // Added a bunch of fields from transactions
    '"AQB__Amount__c":125.0,"AQB__ChartofAccounts__c":"a0I1Y00000vkWFrUAM",' +
    '"AQB__Date__c":"2022-03-13","AQB__Gift__c":"a0D5d00001CTEh8EAH","AQB__Posted__c":true,' +
    '"AQB__Gift__r":{"AQB__AccountId__c":"0015d00003V5f0SAAR","AQB__CreditedOpportunity__c":"a0c5d00000gA6QLAA0","attributes":{"url":"/services/data/v48.0/sobjects/AQB__Gift__c/a0D5d00001CTEh8EAH","type":"AQB__Gift__c"}},'+
    '"Id":"a0c5d00000gA6QLAA0","AQB__CampaignAppealId__c":"7011Y000002BRjHQAW","Recurring_Donations__c":null},' +
    // Next record
    '{ "attributes" : ' +
    '{"type" : "Account",' +
    '"url" : "/services/data/v54.0/sobjects/Account/001D000000IomazIAB"},' +
    '"Name" : "Test 2",' +
    // Transaction fields
    '"AQB__Amount__c":125.0,"AQB__ChartofAccounts__c":"a0I1Y00000vkWFrUAM",' +
    '"AQB__Date__c":"2022-03-13","AQB__Gift__c":"a0D5d00001CTEh8EAH","AQB__Posted__c":true,' +
    '"AQB__Gift__r":{"AQB__AccountId__c":"0015d00003V5f0SAAR","AQB__CreditedOpportunity__c":null,"attributes":{"url":"/services/data/v48.0/sobjects/AQB__Gift__c/a0D5d00001CTEh8EAH","type":"AQB__Gift__c"}},'+
    '"Id":"a0c5d00000gA6QLAA0","AQB__CampaignAppealId__c":"7011Y000002BRjHQAW","Recurring_Donations__c":null}' +
    ']}';

    // Response body from callout that retrieves an Account record from GFW.
    private String responseBodyAccount = '' +
        '{"Name":"John Doe","RecordType":{' +
        '"DeveloperName":"Household","attributes":{' +
        '"url":"/services/data/v48.0/sobjects/RecordType/012i0000000HNlOAAW","type":"RecordType"}},' +
        '"AQB__AccountType__c":"Household","Id":"0011Y00002LvEcKQAV","attributes":'+
        '{"url":"/services/data/v48.0/sobjects/Account/0011Y00002LvEcKQAV","type":"Account"}}';


    global HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        if(req.getBody().contains('Account')) {
            res.setBody(responseBodyAccount);
        } else {
            res.setBody(responseBodyFull);
        }
        return res;
    }
}
