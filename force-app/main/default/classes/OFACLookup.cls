// Download information from the Treasury Department's OFAC/SDN list.
// Enable lookups against that data.
global with sharing class OFACLookup {
    
    // Perform a search against the SDN database at OFAC.  Return null if not found, else the JSON of the matched entry.
    public static String searchSDN (String name) {
        String result;
        if (name != null && name.length() > 0) {
            // We encode using UTF-8, after first getting rid of accented characters, and dropping non-alphanumericSpace.
            // Otherwise, an accented name won't get the hit it should have at OFAC.
            Pattern nonAlphanumericSpace = Pattern.compile('[^a-zA-Z0-9 ]');
            String nameNoAccents = nonAlphanumericSpace.matcher(removeAccents(name)).replaceAll('');
            String nameNoAccentsEncode = EncodingUtil.URLENCODE(nameNoAccents,'UTF-8');
            system.debug('searchSDN: name = ' +name+ '; nameNoAccents = ' +nameNoAccents+ '; nameNoAccentsEncode = ' +nameNoAccentsEncode);
            // Get custom settings for OFAC search and build URL (aka "endpoint").
            OFAC_search_SDN__c settings = OFAC_search_SDN__c.getValues('OFACSearchSDN');
            String lookupURL = settings.Base_URL__c +
                '?apiKey=' + settings.API_key__c +
                '&minScore=' + Integer.valueOf(settings.Min_score__c) +
                '&name=' + nameNoAccentsEncode;
            String response = performSyncCallout(lookupURL);
            system.debug('searchSDN: lookupURL = ' +lookupURL);
            system.debug('searchSDN: response = ' +response);
            Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response);
            List<Object> matches = (List<Object>) responseData.get('matches');
            // Check each match to see if one of them has an exact (as opposed to fuzzy) match to the given name.
            String nameNorm = nameNoAccents.toUpperCase();
            for (Object match : matches) {
                Map<String, Object> mData = (Map<String, Object>) match;
                Map<String, Object> eData = (Map<String, Object>) mData.get('entry');
                String fName = (String) eData.get('firstName');
                String lName = (String) eData.get('lastName');
                String lNameNorm = lName != null ? lName.toUpperCase() : null;
                String fullNameNorm = fName != null ? (fName.toUpperCase() +' '+ lNameNorm).trim() : lNameNorm;
                //system.debug('searchSDN loop: fName = ' +fName+ '; lName = ' +lName);
                // There's a hit if perfect match between given name and the first/last name fields at OFAC.
                if (nameNorm == lNameNorm || nameNorm == fullNameNorm) 
                    return response;
            }
        }
        return result;
    }
    
    // Return a string with accented characters replaced by equivalent characters without accents.
    public static String removeAccents (String str) {
        String result = '';
        String upperAccents = 'ÃÁÀÂÄÇČĆÉÈÊËÎÏÌÍÚÛÜÙÓÔÕÖÒÑŚŜŞŠÝŹŻŽ';
        String upperNonAccents = 'AAAAACCCEEEEIIIIUUUUOOOOONSSSSYZZZ';
        String accents = upperAccents + upperAccents.toLowerCase();
        String nonAccents = upperNonAccents + upperNonAccents.toLowerCase();
        for (Integer i = 0 ; i < str.length() ; i++) {
            String cOrig = str.substring(i, i+1);
            Boolean isLower = cOrig.isAllLowerCase();
            Integer idx = accents.indexOf(cOrig);
            result += idx > -1 ? nonAccents.substring(idx, idx+1) : cOrig;
        }
        return result;
    } 
    
    // Look for matches for accounts/contacts associated with given set of proposals.
    public static String lookupProposals (Set<Id> propIds) {
        // Fetch proposal info.
        Map<Id, Proposal__c> props = new Map<Id, Proposal__c> ([
            SELECT Id, Prop_num_with_renewal__c, Account__c, Date_OFAC_checked__c, OFAC_match__c
            FROM Proposal__c
            WHERE Id IN : propIds
        ]);
        // Fetch payment methods for those proposals.
        Map<Id, Payment_Method__c> pms = new Map<Id, Payment_Method__c> ([
            SELECT Id, Fiscal_sponsor__c
            FROM Payment_Method__c
            WHERE Proposal__c IN : propIds
        ]);
        // Fetch account info and linked contacts from the proposal's parent accounts as well as linked fiscal sponsor accounts.
        Map<Id, Account> accts = new Map<Id, Account> ([
            SELECT Id, Name, Org_name_GM__c, Date_OFAC_checked__c, OFAC_match__c,
            Org_name_non_English__c, Name_on_bank_account__c,
            (SELECT Id, FirstName, LastName FROM Contacts)
            FROM Account
            WHERE Id IN (SELECT Account__c FROM Proposal__c WHERE Id IN : propIds)
        ]);
        // Gather the fiscal sponsor accounts from payment method records.
        Map<Id, Account> acctsFS = new Map<Id, Account>([
            SELECT Id, Name, Org_name_GM__c, Date_OFAC_checked__c, OFAC_match__c,
            Org_name_non_English__c, Name_on_bank_account__c,
            (SELECT Id, FirstName, LastName FROM Contacts)
            FROM Account
            WHERE Id IN (SELECT Fiscal_sponsor__c FROM Payment_Method__c WHERE Id IN : pms.keySet())
        ]);
        // Maps to stash hits
        Map<Id, String> propHits = new Map<Id, String> ();
        Map<Id, String> acctFSHits = new Map<Id, String> ();
        //Map<Id, String> ctHits = new Map<Id, String> ();
        String ctResult;
        String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
        for (Proposal__c p : props.values()) {
            List<String> hits = new List<String> ();
            // Lookup various account names, and stash OFAC entry(s) if there's a hit.
            Account a = accts.get(p.Account__c);
            if (searchSDN(a.Name) != null) hits.add(a.Name +': '+ baseUrl +'/'+ a.Id);
            if (searchSDN(a.Org_name_GM__c) != null) hits.add(a.Org_name_GM__c +': '+ baseUrl +'/'+ a.Id);
            //if (searchSDN(a.Org_name_non_English__c) != null) hits.add(a.Org_name_non_English__c +': '+ baseUrl +'/'+ a.Id);
            if (searchSDN(a.Name_on_bank_account__c) != null) hits.add(a.Name_on_bank_account__c +': '+ baseUrl +'/'+ a.Id);
            // Lookup names of linked contacts, and stash OFAC entries if there are hits.
            for (Contact c : a.Contacts) {
                String cName = (c.FirstName +' '+ c.LastName).trim();
                ctResult = searchSDN(cName);
                if (ctResult != null) {
                    //ctHits.put(c.Id, ctResult);
                	hits.add(cName +': '+ baseUrl +'/'+ c.Id);
                }
            }
            // Mark date checked in proposal/account.
            p.Date_OFAC_checked__c = date.today();
            a.Date_OFAC_checked__c = date.today();
            // Stash any hits for this proposal/account.
            String hitsJoined = string.join(hits, '; ');
            if (hits.size() > 0) propHits.put(p.Id, hitsJoined);
            // Note that OFAC match field is cleared if no hits.
            p.OFAC_match__c = hitsJoined;
            a.OFAC_match__c = hitsJoined;
        }
        // Check fiscal sponsor accounts/contacts for OFAC hits.
        for (Account a : acctsFS.values()) {
            List<String> hits = new List<String> ();
            // Lookup various account names, and stash OFAC entry(s) if there's a hit.
            if (searchSDN(a.Name) != null) hits.add(a.Name +': '+ baseUrl +'/'+ a.Id);
            if (searchSDN(a.Org_name_GM__c) != null) hits.add(a.Org_name_GM__c +': '+ baseUrl +'/'+ a.Id);
            //if (searchSDN(a.Org_name_non_English__c) != null) hits.add(a.Org_name_non_English__c +': '+ baseUrl +'/'+ a.Id);
            if (searchSDN(a.Name_on_bank_account__c) != null) hits.add(a.Name_on_bank_account__c +': '+ baseUrl +'/'+ a.Id);
            // Lookup names of linked contacts, and stash OFAC entries if there are hits.
            for (Contact c : a.Contacts) {
                String cName = (c.FirstName +' '+ c.LastName).trim();
                ctResult = searchSDN(cName);
                if (ctResult != null) hits.add(cName +': '+ baseUrl +'/'+ c.Id);
            }
            // Mark date checked in FS account.
            a.Date_OFAC_checked__c = date.today();
            // Stash any hits for this FS account.
            String hitsJoined = string.join(hits, '; ');
            if (hits.size() > 0) acctFSHits.put(a.Id, hitsJoined);
            a.OFAC_match__c = hitsJoined; // Note that OFAC match field is cleared if no hits.
        }
        
        // Update records in db.
        if(props.values().size() > 0) update props.values();
        if(accts.values().size() > 0) update accts.values();
        if(acctsFS.values().size() > 0) update acctsFS.values();
        
        // Return description of the hits if any.
        List<String> resultingHits = new List<String> ();
        for (Id pId : propHits.keySet()) {
            resultingHits.add(props.get(pId).Prop_num_with_renewal__c +': '+ propHits.get(pId));
        }
        for (Id aId : acctFSHits.keySet()) {
            resultingHits.add(acctsFS.get(aId).Name +'(FS) : '+ acctFSHits.get(aId));
        }
        if (resultingHits.size() > 0) return string.join(resultingHits, '\n');
        else return null;
    }

    // Send an email notifying recipients of hits following an OFAC search.
    public static void OFACLookupNotificationEmail(String OFACResults) {
        // Get custom settings for OFAC lookup
        OFAC_search_SDN__c settings = OFAC_search_SDN__c.getValues('OFACSearchSDN');
        // Build and send email message.
        if (settings.Recipient_email__c != null) {
            Messaging.SingleEmailMessage mail=new Messaging.SingleEmailMessage();
            mail.setToAddresses(settings.Recipient_email__c.split(','));
            mail.setCcAddresses(new List<String> {Utilities.EmailAddressIM});
            mail.setReplyTo(Utilities.EmailAddressIM);
            mail.setSenderDisplayName('OFAC lookup hits');
            mail.setSubject('Results of OFAC lookup');
            mail.setPlainTextBody(OFACResults);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }      
    
    // Perform a synchronous callout and return the response.
    public static String performSyncCallout(String url) {
        // Instantiate a new http object
        Http h = new Http();
        // Instantiate a new HTTP request, specify the method (GET) as well as the endpoint
        HttpRequest req = new HttpRequest();
        req.setTimeout(30000); // timeout in milliseconds
        req.setEndpoint(url);
        req.setMethod('GET');
        // Send the request, and return a response
        HttpResponse res = h.send(req);
        return res.getBody();
    }

}