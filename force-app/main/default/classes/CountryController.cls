public class CountryController {
    
    // Update grantmaking stats fields for given countries.
    public static void updateStatsFields (List<Id> countryIds) {
        Map<Id, Country__c> cMap = new Map<Id, Country__c> ([
            SELECT Id, Name, Date_of_first_grant__c, Date_of_last_grant__c, 
            Num_grants__c, Num_proposals__c, Num_profiles__c, Total_awarded__c,
            (SELECT Id, Date_awarded__c, Grant__c, Amount_awarded__c, Account__r.Name FROM Proposals__r)
            FROM Country__c
            WHERE Id IN : countryIds
        ]);
        
        // Loop through countries, assigning stats fields.
        for(Country__c c : cMap.values()) {
            c.Date_of_first_grant__c = null;
            c.Date_of_last_grant__c = null;
            c.Num_grants__c = 0;
            c.Num_proposals__c = 0;
            c.Total_awarded__c = 0;
            // Gather stats from child proposals.
            for(Proposal__c p : c.Proposals__r) {
                if(p.Account__r.Name.containsIgnoreCase('DONOTUSE')) continue;
                c.Num_proposals__c += 1;
                if(p.Grant__c && p.Amount_awarded__c != null && p.Date_awarded__c != null) {
                    c.Num_grants__c += 1;
                    c.Total_awarded__c += p.Amount_awarded__c;
                    system.debug('updateStatsFields props loop: before: c.Date_of_first_grant__c = ' +c.Date_of_first_grant__c+ '; c.Date_of_last_grant__c = ' +c.Date_of_last_grant__c+ '; p.Date_awarded__c = ' +p.Date_awarded__c);
                    if(c.Date_of_first_grant__c == null || p.Date_awarded__c < c.Date_of_first_grant__c)
                    	c.Date_of_first_grant__c = p.Date_awarded__c;
                    if(c.Date_of_last_grant__c == null || p.Date_awarded__c > c.Date_of_last_grant__c)
                    	c.Date_of_last_grant__c = p.Date_awarded__c;
                    system.debug('updateStatsFields props loop: after: c.Date_of_first_grant__c = ' +c.Date_of_first_grant__c+ '; c.Date_of_last_grant__c = ' +c.Date_of_last_grant__c);
                }
            }
        }
        if (cMap.size() > 0) update cMap.values();
    }

}