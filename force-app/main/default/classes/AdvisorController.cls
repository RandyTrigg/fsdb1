public with sharing class AdvisorController {
    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;
 
    public AdvisorController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
    }
 
    public AdvisorController(ApexPages.StandardSetController standardSetController) {
        this.standardSetController = standardSetController;
    }
    
    // Build the menu of admissible correspondence templates for this object. 
    private static String objectName = 'Advisor__c';
    private static final String START = '--Select Template--';
    public List<selectOption> templates { get; private set; } { templates = Utilities.templatesForObject(objectName, START); }
    public String selectedTemplate {get; set;} { selectedTemplate = START; }

    // Get selected records, then build and reset letters for them.
    public PageReference buildLetters() {
        // Generate error if no selected template - assign error to the templateType field.
        if (selectedTemplate == null || selectedTemplate == START) {
            ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please select a template', 'Must select a template before building new letters'));
            selectedTemplate = START; // If I don't reset to the START value, it gets set to one of the non-disabled values. 
            return null;
        }
        Set<Id> selIds;
        if (standardSetController != null) {
            Map<Id, Advisor__c> selMap = new Map<Id, Advisor__c> ((List<Advisor__c>) standardSetController.getSelected());
            selIds = selMap.keySet();
        } else {
            selIds = new Set<Id> {standardController.getId()};
        }
        Map<Id, Advisor__c> selMap = new Map<Id, Advisor__c> ([
            SELECT Id, Account__c, Account__r.OwnerId, Contact__c,
            Contact__r.Email, Contact__r.Email2__c
            FROM Advisor__c
            WHERE Id IN : selIds
        ]);
        // Gather email addresses from the advisor accounts.
        Set<Id> accIds = new Set<Id> ();
        for (Advisor__c adv : selMap.values()) accIds.add(adv.Account__c);
        Map<Id, List<String>> accEmails = Utilities.emailsForAccounts(accIds);
        system.debug('buildLetters: accEmails = ' +JSON.serialize(accEmails));
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName('Template__c', selectedTemplate);
        List<Letter__c> ls = new List<Letter__c>();
        for (Advisor__c r : selMap.values()) {
            Id accId = r.Account__c;
            String emails = accId != null && accEmails.get(accId) != null ? String.join(Utilities.removeNulls(accEmails.get(accId)), ',') : null;
            ls.add(new Letter__c (
                Template__c = templateId,
                Account__c = r.Account__c,
                Account_owner__c = r.Account__r.OwnerId,
                Letter_owner__c = UserInfo.getUserId(),
                Advisor__c = r.Id,
                Contact__c = r.Contact__c,
                Emails__c = emails
            ));
        }
        insert ls;
        Map<Id, Letter__c> lsMap = new Map<Id, Letter__c> (ls);
        // Reset the new letters.
        LetterController.resetLetters0(lsMap.keySet(), false);
        // Changes have been saved; jump to the new letter if there's only one.
        if(standardController != null && ls.size() == 1) return Utilities.pageReferenceForRecord(ls[0]);
        else return doCancel(); // Stay in current layout.
    }
    
    public PageReference doCancel() {       
        return (standardSetController != null) ? standardSetController.cancel() : standardController.cancel();   
    }
    
    /**********************************
     * For use in Lightning components
     *********************************/
    
    public with sharing class AdvException extends Exception {}
    public static Id recTypeIdContactGM = Utilities.getRecTypeId('Contact', 'Contact_GM');
    public static Id recTypeIdContactAdv = Utilities.getRecTypeId('Contact', 'Contact_GM_Advisor');
    public static Id recTypeIdAcctOrgGM = Utilities.getRecTypeId('Account', 'Organization_GM');
    public static String advisorContactsAccountName = 'Account for advisor contacts';
    public static String grantCommunityProfileName = 'GFW community member';
    public static String advisorCommunityProfileName = 'GFW community member Advisor';
    public static String standardUserGMProfileName = 'Standard User GM';
    public static String advisorCommunityPermSetName = 'Community: Advisors';
    
    // Build interlinked records: Advisor, Contact, Advisor Term, and optionally a GM Org account for org affiliation.
    @AuraEnabled
    public static String buildAdvisorRecs(String jsonString) {
        strike_responseData responseData = new strike_responseData();
        try {
            system.debug('buildAdvisorRecs: jsonString = ' +jsonString);
            Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
            String firstName = (String)jsonMap.get('firstName');
            String lastName = (String)jsonMap.get('lastName');
            String termRecordType = (String)jsonMap.get('advisorTermRecordType');
            String termType = (String)jsonMap.get('advisorTermType');
            Date advisorTermStartDate = jsonMap.get('advisorTermStartDate') != null ? Date.valueOf((String)jsonMap.get('advisorTermStartDate')) : null;
            Date advisorTermEndDate = jsonMap.get('advisorTermEndDate') != null ? Date.valueOf((String)jsonMap.get('advisorTermEndDate')) : null;
            system.debug('buildAdvisorRecs: advisorTermStartDate = ' +advisorTermStartDate+ '; advisorTermEndDate = ' +advisorTermEndDate);
            String advName = firstName +' '+ lastName;
            Account advAcct = [SELECT Id FROM Account WHERE Name = : advisorContactsAccountName LIMIT 1];
            system.debug('buildAdvisorRecs: advAcct = ' +JSON.serialize(advAcct));
            // Build org affiliation account if necessary.
            Account orgAffilAcct;
            Id orgAffilAcctId = idFromJSON(jsonMap, 'orgAffilAcctId');
            String orgAffilName = (String)jsonMap.get('orgAffilName');
            system.debug('buildAdvisorRecs: orgAffilAcctId = ' +orgAffilAcctId+ '; orgAffilName = ' +orgAffilName);
            if (orgAffilAcctId == null && orgAffilName != null) {
                orgAffilAcct = new Account (
                    RecordTypeId = recTypeIdAcctOrgGM,
                    Name = orgAffilName,
                    GM_country__c = idFromJSON(jsonMap, 'countryId')                    
                );
                insert orgAffilAcct;
                orgAffilAcctId = orgAffilAcct.Id;
            } else if (orgAffilAcctId != null && orgAffilName == null) {
                orgAffilAcct = [SELECT Name FROM Account WHERE Id = : orgAffilAcctId];
                orgAffilName = orgAffilAcct.Name;
            }
            system.debug('buildAdvisorRecs: orgAffilAcct = ' +JSON.serialize(orgAffilAcct));
            Contact advCon = new Contact (
                RecordTypeId = recTypeIdContactAdv,
                AccountId = advAcct.Id,
                FirstName = firstName,
                LastName = lastName,
                Email = (String)jsonMap.get('email'),
                Title = (String)jsonMap.get('title'),
                Rank__c = 1
            );
            insert advCon;
            system.debug('buildAdvisorRecs: advCon = ' +JSON.serialize(advCon));
            // 2/7/20: Note that Type__c field of Advisor will be retired or significantly modified at some point.
            Advisor__c adv = new Advisor__c (
                Name = advName,
                Type__c = termType == 'Strategic' ? 'Official' : termType == 'Expert' ? 'Informal' : termType,
                Language__c = (String)jsonMap.get('language'),
                Global__c = (String)jsonMap.get('global') == 'true' ? true : false,
                Contact__c = advCon.Id,
                GM_org_affiliation__c = orgAffilAcctId
            );
            insert adv;
            system.debug('buildAdvisorRecs: adv = ' +JSON.serialize(adv));
            Advisor_Term__c advt = new Advisor_Term__c (
                RecordTypeId = Utilities.getRecTypeId('Advisor_Term__c', termRecordType),
                Advisor__c = adv.Id,
                Type__c = termRecordType == 'Assessor' && termType == 'Reference' ? 'Reference' : null,
                Type_invited__c = termRecordType == 'Assessor' && termType != 'Reference' ? termType : null,
                Date_term_begins__c = advisorTermStartDate != null ? advisorTermStartDate : Date.today(),
                Date_term_ends__c = termRecordType == 'Assessor' && termType == 'Reference' ? null : advisorTermEndDate,
                Portfolio__c = idFromJSON(jsonMap, 'portfolioId')
            );
            insert advt;
            system.debug('buildAdvisorRecs: advt = ' +JSON.serialize(advt));
            advt = [SELECT Id, Name FROM Advisor_Term__c WHERE Id = :advt.Id];
            responseData.results = new Map<String, Object> {
                'advisorId' => adv.Id,
                'contactId' => advCon.Id,
                'orgAffilAcctId' => orgAffilAcctId,
                'orgAffilName' => orgAffilName,
                'name' => advName,
                'advisorTermId' => advt.Id,
                'advisorTermName' => advt.Name
            };
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        
        return responseData.getJsonString();
    }

    // Test for empty string (as opposed to null) so casting to id doesn't break.
    private static Id idFromJSON (Map<String, Object> jsonMap, String attr) {
        if (jsonMap.get(attr) == null) return null;
        String valStr = (String) jsonMap.get(attr);
        return valStr == '' ? null : Id.valueOf(valStr); 
    }

    // Fetch profile and permission sets of current user.
    @AuraEnabled
    public static String fetchProfileAndPermissionSets() {
        strike_responseData responseData = new strike_responseData();
        try {
            responseData.results = new Map<String, Object> {
                'profile' => Utilities.currentUserProfileName(),
                'permissionSets' => Utilities.currentUserPermissionSetNames()
            };
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        system.debug('fetchProfileAndPermissionSets: responseData = ' +JSON.serialize(responseData));
        return responseData.getJsonString();
    }

    // Add given advisor to the Advisors community.
    @AuraEnabled
    public static String addAdvisorToCommunity(String jsonString) {
        strike_responseData responseData = new strike_responseData();
        try {
            system.debug('addAdvisorToCommunity: jsonString = ' +jsonString);
            Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
            Id advId = Id.valueOf((String)jsonMap.get('advisorId'));
            Advisor__c adv = [
                SELECT Id, Name, Contact__c, Contact__r.Email, Contact__r.FirstName, Contact__r.LastName, Community_contact__c
                FROM Advisor__c
                WHERE Id = : advId
            ];
            system.debug('addAdvisorToCommunity: adv = ' +JSON.serialize(adv));
            // Currently, this only works for individual advisors whose contact records have emails and who aren't already online.
            if (advId == null || adv.Community_contact__c != null || adv.Contact__c == null || adv.Contact__r.Email == null) 
                throw new AdvException ('Advisor already in community or not individual or has blank email');
            // Look up community profile/perm set.
            Id pIdGrnt = [SELECT Id FROM Profile WHERE Name = : grantCommunityProfileName LIMIT 1].Id;
            Id pIdAdv = [SELECT Id FROM Profile WHERE Name = : advisorCommunityProfileName LIMIT 1].Id;
            Id psIdAdv = [SELECT Id FROM PermissionSet WHERE Label = : advisorCommunityPermSetName LIMIT 1].Id;
            String email = adv.Contact__r.Email;
            String username = advisorUsernameFromEmail(email);
            // User/Contact will either already exist or be created here.
            User u; 
            Contact c;
            // See if there's already a user with that email as username. (There should be at most one.)
            User[] users = [SELECT Id, ContactId, ProfileId, Username FROM User WHERE Username = : username];
            if (users.size() > 0) u = users[0];
            system.debug('addAdvisorToCommunity: u = ' +JSON.serialize(u));
            if (u != null) { // Don't allow reuse of existing username
                // Username already belongs to a community.
                if (u.ProfileId == pIdAdv) throw new AdvException ('Advisor contact username (' +username+ ') is already a username in advisor community.');
                if (u.ProfileId == pIdGrnt) throw new AdvException ('Advisor contact username (' +username+ ') is a username in grantmaking community.');
                if (u.ContactId != null) throw new AdvException ('Advisor contact username (' +username+ ') is a username linked to a community contact.');
                throw new AdvException ('Advisor contact username (' +username+ ') is the username of an existing user record.');
            } else {
                // Build the new user with advisor community profile.
                u = new User(
                    Username = username,
                    Email = email,
                    //CompanyName = orgName.left(80),
                    CommunityNickname = username.left(40),
                    LastName = adv.Contact__r.LastName != null ? adv.Contact__r.LastName.left(40) : null,
                    FirstName = adv.Contact__r.FirstName != null ? adv.Contact__r.FirstName.left(40) : null,
                    Alias = email.toLowerCase().left(4),
                    ProfileId = pIdAdv,
                    EmailEncodingKey = 'UTF-8',
                    LanguageLocaleKey = 'en_US',
                    LocaleSidKey = 'en_US',
                    TimeZoneSidKey = 'GMT'
                );
                system.debug('addAdvisorToCommunity: u = ' +JSON.serialize(u));
            }
            // If no contact, then build a new one in the community account.
            if (c == null) {
                Account advAcct = [SELECT Id FROM Account WHERE Name = : advisorContactsAccountName LIMIT 1];
                c = new Contact(
                    RecordTypeId = recTypeIdContactGM,
                    AccountId = advAcct.Id,
                    Email = email,
                    LastName = adv.Contact__r.LastName,
                    FirstName = adv.Contact__r.FirstName
                );
                system.debug('addAdvisorToCommunity: c = ' +JSON.serialize(c));
                insert c;
            }
            // Insert new user or update existing one.
            if (u.ContactId != c.Id) {
                u.ContactId = c.Id; // Link user to new community contact.
                if (u.Id == null) insert u;
                else update u; // Not sure if it's actually possible to hit this else clause, given conditions on u and c above.
            } 
            if (u.ProfileId == pIdGrnt) {
                // User is in grants community profile, so assign the advisors community permission set (so user is in both communities).
                assignPermissionSet(u.Id, psIdAdv);
            }
            // Link advisor to community contact.
            adv.Community_contact__c = c.Id;
            adv.Community_contact_username__c = username;
            update adv;
            responseData.results = new Map<String, Object> {
                // Note that we can't return id of new user, if any, since it was created in a separate transaction.
                'userName' => u.Username
            };
        } catch (Exception e) {
            if (e.getMessage() != 'SUCCESS') responseData.addError(e.getMessage());
        }
        system.debug('addAdvisorToCommunity: responseData = ' +JSON.serialize(responseData));
        return responseData.getJsonString();
    }
    
    // Future method to assign user to a permission set (future is to avoid Mixed DML operations error).
    @future
    public static void assignPermissionSet(Id userId, Id permSetId) {
        system.debug('assignPermissionSet: userId = ' +userId+ '; permSetId = ' +permSetId);
        insert new PermissionSetAssignment (PermissionSetId = permSetId, AssigneeId = userId);
    }
    
    // Return a map of emails for given advisors.
    public static Map<Id, List<String>> emailsForAdvisors(Set<Id> aIds) {
        Map<ID, List<String>> eMap = new Map<Id, List<String>>();
        String[] fieldNames = Utilities.fieldNamesForObject('Advisor__c');
        fieldNames.addAll(new List<String>{
            'Contact__r.Email', 'Contact__r.Email2__c', 
            'Account__r.Contact_emails_GM__c', 'GM_org_affiliation__r.Contact_emails_GM__c'
        });
        String q = 'SELECT ' +String.join(fieldNames, ', ')+ ' FROM Advisor__c WHERE Id IN : aIds';
        List<Advisor__c> advs = Database.query(q);
        //system.debug('advs = ' +JSON.serialize(advs));
        // Gather emails for each advisor.
        for (Advisor__c a : advs) {
            List<String> emails = emailsForAdvisor(a);
            if (emails.size() > 0) eMap.put(a.Id, emails);
        }
        return eMap;
    }
    
    // Return the unique email addresses for the given advisor.
    // NOTE: The caller should have fetched all necessary contact info fields into given advisor.
    public static List<String> emailsForAdvisor(Advisor__c a) {
        Set<String> uniqueEmails = new Set<String> ();
        if (a.Contact__r.Email != null) uniqueEmails.add(a.Contact__r.Email);
        if (a.Contact__r.Email2__c != null) uniqueEmails.add(a.Contact__r.Email2__c);
        // Throw in community email from online advisor, if any.
        if (a.Community_contact_email__c != null) uniqueEmails.add(a.Community_contact_email__c);
        // Throw in emails from linked accounts, if any.
        if (a.Account__r.Contact_emails_GM__c != null) {
            for (String e : a.Account__r.Contact_emails_GM__c.split(',')) uniqueEmails.add(e.trim());
        }
        if (a.GM_org_affiliation__r.Contact_emails_GM__c != null) {
            for (String e : a.GM_org_affiliation__r.Contact_emails_GM__c.split(',')) uniqueEmails.add(e.trim());
        }
        return new List<String> (uniqueEmails);
    }
    
    /**********************************
     * For general use
     *********************************/
    
    // Ensure that the Current Assessor Term lookup field is up to date. 
    public static void updateLookups (Id advisorId) {
        Id currentAssessorTermId;
        Date today = Date.today();
        Advisor__c adv = [
            SELECT Current_assessor_term__c, Active__c, 
            (SELECT Id, Status__c 
            FROM Advisor_Terms__r 
            WHERE RecordType.Name = 'Assessor' 
            )
            FROM Advisor__c
            WHERE Id = :advisorId
        ];
        system.debug('updateLookups: adv = ' +JSON.serialize(adv));
        // If advisor is active, look for an active assessor advisor term.  There should be at most one!
        if (adv.Active__c) {
            for (Advisor_Term__c advt : adv.Advisor_Terms__r) {
                if (advt.Status__c.toLowerCase().contains('active')) currentAssessorTermId = advt.Id;
            }
        }
        if (adv.Current_assessor_term__c != currentAssessorTermId) {
            adv.Current_assessor_term__c = currentAssessorTermId;
            update adv;
        }
    }
    
    // The advisor's username is their email with the prefix ADV-.
    public static String advisorUsernameFromEmail (String email) {
        return 'ADV-' + email;
    }

    //Only call when in the context of an Advisor Experience Site User
    public static String getRunningUserAdvisorId() {
        try {
            ID userId = UserInfo.getUserId();
            User u = [SELECT Id, FirstName, LastName, Email, ContactId FROM User WHERE Id=:userId];
            Advisor__c runningAdvisor = [SELECT ID FROM Advisor__c WHERE Community_contact__c =:u.ContactId LIMIT 1];
            return runningAdvisor.Id;
        } catch (Exception e) {
            throw new GFW_Exception('AdvisorController.getRunningUserAdvisorId', 'Could not load Advisor Record', e);
        }
        
    }

}