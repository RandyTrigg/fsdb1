public with sharing class SyncController {
    
    public SyncController() {

    }


    public static String doQueryCallout(String queryStr) {
        HTTPCalloutService service = new HTTPCalloutService('GFWQuery');
        System.debug(service.getRequest());
        // String query='select Name,Id,AQB__Account__c,AQB__Gift__c from AQB__Transaction__c Where AQB__ChartofAccounts__r.Name=\'FS-BFF\' and (AQB__Method__c!=\'Pledge\' or AQB__Balance__c>0)';
        String encodeQ = EncodingUtil.urlEncode(queryStr, 'UTF-8');
        Service.setURLParameter('q', encodeQ);
        System.debug(service.getRequest());
        HTTPResponse response = service.sendRequest();
        System.debug(response.getStatusCode());
        System.debug(response.getBody());
        return response.getBody();
        
        /*
        // Instantiate a new http object
        Http http = new Http();	
    	// Instantiate new HTTP request, specify the method (GET) as well as the endpoint with Named Credential
    	HttpRequest req = new HttpRequest();
        system.debug(logginglevel.WARN, 'Callout: ' + getRequest);
        req.setEndpoint('callout:NamedCredential_KLAS/' + getRequest);
        req.setMethod('GET');
        // Send request and return the response
		HTTPResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            return res.getBody();
        } else
        {
            return 'Error: ' + string.valueof(res.getStatusCode() + '; Callout = ' + getRequest);
        }
        */
    }

}
