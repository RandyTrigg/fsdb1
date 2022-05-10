@isTest
global class OFACLookupMock implements HttpCalloutMock {
    
    // Response body from an API that pulls down entire SDN list, which we're no longer using.
    /*
    private String responseBody = '' +
            '{"total":1,"offset":0,"sources_used":' +
            '[{"source":"Specially Designated Nationals (SDN) - Treasury Department","source_last_updated":"2016-05-11T15:03:58+00:00","last_imported":"2016-05-12T22:03:05+00:00"}]' +
            ',"search_performed_at":"2016-05-12T22:23:36+00:00","results":' +
            '[{"id":"7504","addresses":[],' +
            '"alt_names":["SMITH, John", "SMITH, Johno"],' +
            '"citizenships":[],"dates_of_birth":["1944-04-28"],"entity_number":"7504","ids":[],' +
            '"name":"DOE, John","nationalities":[],"places_of_birth":[],"programs":["ZIMBABWE"],"remarks":null,' +
            '"source":"Specially Designated Nationals (SDN) - Treasury Department","source_information_url":"http://1.usa.gov/1Xia3eH","source_list_url":"http://1.usa.gov/1lBPYV1",' +
            '"title":"Dummy title","type":"Individual"}]}';
	*/
    
    // Response body from an API that looks up a single name at SDN.
    private String responseBody = '' +
    	'{"error": false, "matches": [' +
    	'{"entry": {"uid": 7504,"firstName": "John","lastName": "Doe",' +
    	'"title": "Deputy Secretary for Disabled and Disadvantaged","sdnType": "Individual",' +
    	'"programList": {"program": ["ZIMBABWE"]},' +
    	'"dateOfBirthList": {"dateOfBirthItem": [{"uid": 1625,"dateOfBirth": "28 Apr 1944","mainEntry": true}]}},' +
    	'"score": 94.0,"dob": "28 Apr 1944"}]}';
    
    global HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(responseBody);
        res.setStatusCode(200);
        return res;
    }
}