public with sharing class AssessorSiteController {
    private final static Integer MAX_RESULTS = 5;
    
    //We load all the searchable records and do searching/filtering in the LWC.  Assessor Advisors only have access to a limited number of records and this avoids querying with complex logic with each search
    @AuraEnabled(Cacheable=true)
    public static String getSearchableRecords() {

        String advisorId = getRunningUserAdvisorId();
        Advisor__c advRecord = [SELECT ID, Language__c, (SELECT ID, Type__c, Status_external__c, Portfolio__c FROM Advisor_Terms__r WHERE Status_external__c='Active') FROM Advisor__c WHERE ID=:advisorId];

        //All Invites:
        List < Invite__c > invites = loadInviteViewForms(advRecord.Advisor_Terms__r,null);

        //All Ratings
        List < Assessment__c > ratingAssessments = AssessorSiteController.getRatingAssessments(advisorId, null, null);

        //All Grantee Report Assessments
        List < Assessment__c > grReportAssessments = AssessorSiteController.getGRAssessments(advisorId, null, null);

        //All Proposal Assessments
        List < Assessment__c > propAssessments = AssessorSiteController.getProposalAssessments(advisorId, null, null);

        //All Profile Assessments
        List < Assessment__c > profileAssessments = AssessorSiteController.getProfileAssessments(advisorId, null, null);

        //All endorsements
        List < Endorsement__c > endorsements = AssessorSiteController.getEndorsements(advisorId, null, null);
    

        // Prepare results
        List<LookupSearchResult> results = new List<LookupSearchResult>();

        // Extract Grantee Report Assessments & convert them into LookupSearchResult
        String grIcon = 'standard:expense_report';
        for (Assessment__c assess: grReportAssessments) {
            String subtitle = assess.Grantee_Report__r.Account_name__c;
            results.add(new LookupSearchResult(assess.Id, 'Assessment__c', grIcon, 'gfw-gr-icon', assess.Grantee_Report__r.Name, subtitle));
        }

        // Extract Proposal Assessments & convert them into LookupSearchResult
        String propIcon = 'standard:service_report';
        for (Assessment__c assess: propAssessments) {
            String subtitle = assess.Proposal__r.Account__r.Name;
            results.add(new LookupSearchResult(assess.Id, 'Assessment__c', propIcon, 'gfw-prop-icon', assess.Proposal__r.Name, subtitle));
        }

        // Extract Profile Assessments & convert them into LookupSearchResult
        String profIcon = 'standard:channel_program_members';
        for (Assessment__c assess: profileAssessments) {
            String subtitle = assess.Profile__r.Applicant__r.Name;
            results.add(new LookupSearchResult(assess.Id, 'Assessment__c', profIcon, 'gfw-prof-icon', assess.Profile__r.Name, subtitle));
        }

        // Extract Rating Assessments & convert them into LookupSearchResult
        String ratingIcon = 'standard:lead_insights';
        for (Assessment__c assess: ratingAssessments) {
            String subtitle = assess.Proposal__r.Country__r.Name;
            results.add(new LookupSearchResult(assess.Id, 'Assessment__c', ratingIcon, 'gfw-rating-icon', assess.Proposal__r.Account__r.Name, subtitle));
        }

        // Extract Endorsements & convert them into LookupSearchResult
        String endIcon = 'standard:product_required';
        for (Endorsement__c endorse: endorsements) {
            String subtitle = String.valueOf(endorse.Date_due__c);
            results.add(new LookupSearchResult(endorse.Id, 'Endorsement__c', endIcon, 'gfw-endorse-icon', endorse.Account__r.Name, subtitle));
        }

        // Extract Forms & convert them into LookupSearchResult
        String formIcon = 'standard:work_plan';
        if (invites!=null) {
            for (Invite__c inv: invites) {
                String subtitle = inv.Account__r.GM_country__r.Name;
                results.add(new LookupSearchResult(inv.Id, 'Invite__c', formIcon, 'gfw-form-icon', inv.Account__r.Name, subtitle));
            }
        }
        
        // Sort all results on title
        results.sort();

        return JSON.serialize(results);
    }
    
    @AuraEnabled //Do not cache
    public static String getInterfaceType() {

        ID userId = UserInfo.getUserId();
        User u = [SELECT Id, FirstName, LastName, Email, ContactId FROM User WHERE Id=:userId];

        Advisor__c runningAdvisor = [SELECT ID, (SELECT ID, Type__c, Status_external__c, Portfolio__c FROM Advisor_Terms__r WHERE Status_external__c='Active') FROM Advisor__c WHERE Community_contact__c =:u.ContactId LIMIT 1];

        //Now get the Portfolios linked to any active Advisor term to see if they have an Externally Viewed Portfolio linked
        List < ID > portfolioIDs = new List < ID >();
        for (Advisor_Term__c term: runningAdvisor.Advisor_Terms__r) {
            if (term.Portfolio__c!=null) {
                portfolioIDs.add(term.Portfolio__c);
            }
            
        }
        List < Portfolio__c > portfolios = [SELECT ID, Type__c FROM Portfolio__c WHERE Type__c='Externally viewed' AND ID in:portfolioIDs];
        
        //If they have an active Advisor Term that is linked to a Portfolio of type "Externally viewed, they get the Invitations view
        if (portfolios.size()>0) {
            return 'invitations';
        } else {
            return 'assessments';
        }

    }  

    @AuraEnabled //Do not cache
    public static String getEndorsements () {
        List < Endorsement__c > endorsements = [SELECT ID, Name, Proposal__c, Proposal__r.Name, Status_external__c,Date_due__c, Advisor__r.Name FROM Endorsement__c];

        return JSON.serialize(endorsements);

    } 

    @AuraEnabled //Do not cache
    public static String getAssessmentReview(String assessmentId) {
        Assessment rev = new Assessment(assessmentId);
        return JSON.serialize(rev);
    }    

    @AuraEnabled// Do not cache
    public static List<Assessment__c> getAssignedAssessments() {

        try {
            String advisorId = getRunningUserAdvisorId();

            return [
                SELECT Id, Name, Account__c, Advisor__c, Advisor__r.Name, Advisor_Term__c, Date_submitted__c, Grantee_Report__c, Grantee_Report__r.Account_name__c, Grantee_Report__r.Date_review_completed__c, Portfolio__c, Profile__c, Proposal__c, Proposal__r.Account__r.Name, Proposal__r.Date_review_completed__c, Review_Form__c, Status__c, Status_external__c, Profile__r.Applicant_name__c, Profile__r.Account__c, Profile__r.Account__r.Name, Profile__r.Date_review_completed__c, Grantee_Report__r.Name, Grantee_Report__r.Date_received__c, Grantee_Report__r.Review_priority__c, Grantee_Report__r.Country_name__c
                FROM Assessment__c
                WHERE Advisor__c=:advisorId
                AND Form__c=null
                ORDER BY Status_external__c, Date_submitted__c
            ];
        } catch (Exception e) {
            throw new GFW_Exception('AssessorSiteController.getAssignedAssessments', 'Could not load Assessments for the current user.', e);
        }
        
    }

    @AuraEnabled// Do not cache
    public static String getAssignedInvites() {

        try {
            ID userId = UserInfo.getUserId();
            User u = [SELECT Id, FirstName, LastName, Email, ContactId FROM User WHERE Id=:userId];

            //Fetch the advisor record matching the running user/contact
            Advisor__c runningAdvisor = [
                SELECT ID, 
                    (SELECT ID, Type__c, Status_external__c, Portfolio__c 
                    FROM Advisor_Terms__r 
                    WHERE Status_external__c='Active') 
                FROM Advisor__c 
                WHERE Community_contact__c =:u.ContactId LIMIT 1];

            //Now get the Portfolios linked to any active Advisor term to see if they have an Externally Viewed Portfolio linked
            List < ID > portfolioIDs = new List < ID >();
            for (Advisor_Term__c term: runningAdvisor.Advisor_Terms__r) {
                portfolioIDs.add(term.Portfolio__c);
            }
            List < Portfolio__c > portfolios = [SELECT ID, Type__c FROM Portfolio__c WHERE ID in:portfolioIDs AND Type__c='Externally viewed'];


            //Load all of the Accounts via the Portfolio_Account_Assign__c
            if (runningAdvisor.Advisor_Terms__r.size()>0) {
                List < Portfolio_Account_Assign__c > portfolioAssigns = [
                    SELECT ID, Account__c FROM Portfolio_Account_Assign__c 
                    WHERE Portfolio__c in:portfolios
                ];
            
                List < ID > accountIds = new List < ID >();
                for (Portfolio_Account_Assign__c pa: portfolioAssigns) {
                    accountIds.add(pa.Account__c);
                }

                // We will also load any invitations linked to Proposals that are linked to this portfolio
                List < Portfolio_Assignment__c > portfolioLinkedProposals = [
                    SELECT ID, Proposal__c, Proposal__r.Invite__c
                    FROM Portfolio_Assignment__c 
                    WHERE Portfolio__c in:portfolios];
                List < ID > inviteIDsFromProposals = new List < ID >();
                for (Portfolio_Assignment__c pa: portfolioLinkedProposals) {
                    inviteIDsFromProposals.add(pa.Proposal__r.Invite__c);
                }

                //Finally, get the list of invitations for all these accounts with the correct status
                List < Invite__c > invitations = [
                    SELECT ID, Account__r.Name, Status__c, Status_numeric__c, Comments__c, Profile__c, Has_proposal__c, Proposal__r.Status_numeric__c, CreatedDate
                    FROM Invite__c 
                    WHERE (ID in:inviteIDsFromProposals 
                    OR (Account__c in:accountIds AND (Proposal__c=null OR (Proposal__r.Status_numeric__c<10 AND Proposal__r.Status_numeric__c>=1))))
                    ORDER BY CreatedDate Desc
                ];

                return JSON.serialize(invitations);

            } else {
                //throw exception
                System.debug('No Advisor Term Found For: '+runningAdvisor);
                throw new GFW_Exception('AssessorSiteController.getAssignedInvites', 'No Advisor Term Found For: '+runningAdvisor);
            }

        } catch (Exception e) {
            throw new GFW_Exception('AssessorSiteController.getAssignedInvites', 'Could not load Invites for the current user.', e);
        }
        
    }

    @AuraEnabled// Do not cache
    public static String getInviteFormInfo(String inviteId) {
        if (inviteId!=null) {
            Invite__c inv = [
                SELECT ID, Profile__c, Proposal__c, Account__r.Name 
                FROM Invite__c
                WHERE ID=:inviteId
            ];
            
            if (inv.Proposal__c !=null ) {
                return '{"Id":"'+inv.Proposal__c+'","Name":"'+inv.Account__r.Name+'"}';
            } else {
                return '{"Id":"'+inv.Profile__c+'","Name":"'+inv.Account__r.Name+'"}';
            }
        } else {
            String returnMessage = 'No Invite Id Provided';
            return returnMessage;
        }
        //return either the profile or proposal id
        

    }

    private static String getRunningUserAdvisorId() {
        return AdvisorController.getRunningUserAdvisorId();        
    }

    @AuraEnabled
    public static boolean submitReview(String assessmentId){
        Assessment assess = new Assessment(assessmentId);
        assess.submit();
        return true;
    }


    // --------------------------------------------------------------------------------------
    //TODO: switch to new controller

    @AuraEnabled
    public static string loadAdvisorSummary(){
        try {
            AdvisorSummary advSummary = new AdvisorSummary(getRunningUserAdvisorId());
            return JSON.serialize(advSummary);
        } catch (Exception e) {
            throw new GFW_Exception('AssessorSiteController.loadAdvisorSummary',e.getMessage(),e);
        }
    }

    @AuraEnabled
    public static String loadAdvisorRecords(String objectType){
        System.debug('objectType: '+objectType);
        String advisorId = getRunningUserAdvisorId();
        Advisor__c advRecord = [SELECT ID, Language__c, (SELECT ID, Type__c, Status_external__c, Portfolio__c FROM Advisor_Terms__r WHERE Status_external__c='Active') FROM Advisor__c WHERE ID=:advisorId];

        try {
            String result;
            switch on objectType {
                when 'Grantee_Report__c' {
                    List < Assessment__c > reports = AssessorSiteController.getGRAssessments(advisorId, null, null);
                    result = JSON.serialize(reports);
                }	
                when 'Proposal__c' {
                    List < Assessment__c > props = AssessorSiteController.getProposalAssessments(advisorId, null, null);
                    result = JSON.serialize(props);
                }
                when 'Rating' {
                    List < Assessment__c > ratingAssessments = AssessorSiteController.getRatingAssessments(advisorId, null, null);
                    System.debug('ratingAssessments: '+JSON.serialize(ratingAssessments));
                    result = JSON.serialize(ratingAssessments);
                }
                when 'Profile__c' {
                    List < Assessment__c > profiles = AssessorSiteController.getProfileAssessments(advisorId, null, null);
                    result = JSON.serialize(profiles);
                    System.debug('profiles: '+result);
                }
                when 'Endorsement__c' {
                    List < Endorsement__c > endorsements = AssessorSiteController.getEndorsements(advisorId, null, null);
                    result = JSON.serialize(endorsements);
                }
                when 'Form' {
                    System.debug('in form section');
                    List < Invite__c > invites = loadInviteViewForms(advRecord.Advisor_Terms__r,null);
                    result = JSON.serialize(invites);
                }
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static List < Invite__c > loadInviteViewForms(List < Advisor_Term__c > advTerms, Integer limitCount) {

        //Get the Portfolios linked to any active Advisor term to see if they have an Externally Viewed Portfolio linked
        List < ID > portfolioIDs = new List < ID >();
        for (Advisor_Term__c term: advTerms) {
            portfolioIDs.add(term.Portfolio__c);
        }
        List < Portfolio__c > portfolios = [SELECT ID, Type__c FROM Portfolio__c WHERE ID in:portfolioIDs AND Type__c='Externally viewed'];

        //Load all of the Accounts via the Portfolio_Account_Assign__c
        if (advTerms.size()>0) {
            List < Portfolio_Account_Assign__c > portfolioAssigns = [
                SELECT ID, Account__c FROM Portfolio_Account_Assign__c 
                WHERE Portfolio__c in:portfolios
            ];
        
            List < ID > accountIds = new List < ID >();
            for (Portfolio_Account_Assign__c pa: portfolioAssigns) {
                accountIds.add(pa.Account__c);
            }

            // We will also load any invitations linked to Proposals that are linked to this portfolio
            List < Portfolio_Assignment__c > portfolioLinkedProposals = [
                SELECT ID, Proposal__c, Proposal__r.Invite__c
                FROM Portfolio_Assignment__c 
                WHERE Portfolio__c in:portfolios];
            List < ID > inviteIDsFromProposals = new List < ID >();
            for (Portfolio_Assignment__c pa: portfolioLinkedProposals) {
                inviteIDsFromProposals.add(pa.Proposal__r.Invite__c);
            }

            //Finally, get the list of invitations for all these accounts with the correct status
            if (limitCount==null) {
                limitCount = 50000;
            }
            List < Invite__c > invitations = [
                SELECT ID, Account__r.Name, Account__r.GM_country__r.Name, Status__c, Status_numeric__c, Comments__c, Profile__c, Has_proposal__c, Proposal__r.Name, Proposal__r.Status_numeric__c, Proposal__r.Template_language__c, CreatedDate
                FROM Invite__c 
                WHERE (ID in:inviteIDsFromProposals 
                OR (Account__c in:accountIds AND (Proposal__c=null OR (Proposal__r.Status_numeric__c<10 AND Proposal__r.Status_numeric__c>=1))))
                ORDER BY CreatedDate Desc
                LIMIT :limitCount
            ];

            return invitations;

        } else {
            return null;
        }
    }


    //There are several places where we load Assessments based on advisor id, and optionally status and count.  Query logic is shared here to avoid discrepancies and redundancy
    public static List < Assessment__c > getGRAssessments(String advisorId, String status, Integer count) {

        String whereClause = ' WHERE Advisor__c=:advisorId AND Form__c=null AND Grantee_Report__c!=null';
        if (status!=null) {
            whereClause = whereClause + ' AND Status_external__c=:status';
        }
        
        String queryString = 'SELECT Id, Name, Advisor__c, Grantee_Report__c, Grantee_Report__r.Account_name__c, Grantee_Report__r.Country_name__c, Grantee_Report__r.Name, Grantee_Report__r.Proposal__r.Grant_type__c, Grantee_Report__r.Proposal__r.Thematic_priority__c, Grantee_Report__r.Date_due__c, Grantee_Report__r.Date_received__c, Grantee_Report__r.Review_priority__c, Grantee_Report__r.Template_language__c, Status_external__c FROM Assessment__c' + whereClause + ' ORDER BY Grantee_Report__r.Review_priority__c DESC, Status_external__c, Date_submitted__c ASC';

        if (count!=null) {
            queryString = queryString + ' LIMIT: count';
        }

        List < Assessment__c > grReportAssessments = Database.query(queryString);

        return grReportAssessments;
        
    }

    public static List < Assessment__c > getProposalAssessments(String advisorId, String status, Integer count) {

        String whereClause = ' WHERE Advisor__c=:advisorId AND Form__c=null AND Grantee_Report__c=null AND Profile__c=null AND Proposal__c!=null';
        if (status!=null) {
            whereClause = whereClause + ' AND Status_external__c=:status';
        }
        
        String queryString = 'SELECT Id, Name, Account__c, Account__r.Name, Advisor__c, Proposal__r.Country__c, Proposal__r.Country__r.Name, Proposal__r.Name, Proposal__r.Account__r.Name, Proposal__r.Grant_type__c, Proposal__r.Award_notification_deadline__c, Proposal__r.Date_received__c, Proposal__r.Template_language__c, Proposal__r.Thematic_priority__c, Status_external__c FROM Assessment__c' + whereClause + ' ORDER BY Status_external__c, Proposal__r.Award_notification_deadline__c ASC';

        if (count!=null) {
            queryString = queryString + ' LIMIT: count';
        }

        List < Assessment__c > propReportAssessments = Database.query(queryString);

        return propReportAssessments;
        
    }

    public static List < Assessment__c > getProfileAssessments(String advisorId, String status, Integer count) {

        String whereClause = ' WHERE Advisor__c=:advisorId AND Form__c=null AND Grantee_Report__c=null AND Profile__c!=null';
        if (status!=null) {
            whereClause = whereClause + ' AND Status_external__c=:status';
        }
        
        String queryString = 'SELECT Id, Account__c, Profile__r.Applicant__c, Profile__r.Applicant__r.Name, Profile__r.Country_name__c, Profile__r.Name, Date_submitted__c, Profile__r.Language__c,Status_external__c, Profile__r.Date_submitted__c FROM Assessment__c' + whereClause + ' ORDER BY Status_external__c, Date_submitted__c, Profile__r.Name ASC';

        if (count!=null) {
            queryString = queryString + ' LIMIT: count';
        }

        List < Assessment__c > profReportAssessments = Database.query(queryString);

        return profReportAssessments;
        
    }

    public static List < Endorsement__c > getEndorsements(String advisorId, String status, Integer count) {

        String whereClause = ' WHERE Advisor__c=:advisorId';
        if (status!=null) {
            whereClause = whereClause + ' AND Status_external__c=:status';
        }
        
        String queryString = 'SELECT ID, Account__c, Account__r.Name, Account__r.GM_country__r.Name, Date_requested__c, Date_due__c, Expiration_date__c, Status_external__c, Proposal__c, Proposal__r.Name FROM Endorsement__c' + whereClause + ' ORDER BY Status_external__c, Date_received__c';

        if (count!=null) {
            queryString = queryString + ' LIMIT: count';
        }

        List < Endorsement__c > endorsements = Database.query(queryString);

        return endorsements;
        
    }

    public static List < Assessment__c > getRatingAssessments(String advisorId, String status, Integer count) {

        String whereClause = ' WHERE Advisor__c=:advisorId AND Form__c!=null AND Proposal__c!=null';
        if (status!=null) {
            whereClause = whereClause + ' AND Status_external__c=:status';
        }
        
        String queryString = 'SELECT Id, Name, Account__c, Account__r.Name, Advisor__c, Form__c, Proposal__r.Country__c, Proposal__r.Country__r.Name, Proposal__r.Name, Proposal__r.Account__r.Name, Proposal__r.Grant_type__c, Proposal__r.Award_notification_deadline__c, Proposal__r.Date_received__c, Proposal__r.Template_language__c ,Status_external__c FROM Assessment__c' + whereClause + ' ORDER BY Status_external__c, Date_submitted__c';

        if (count!=null) {
            queryString = queryString + ' LIMIT: count';
        }

        List < Assessment__c > ratingAssessments = Database.query(queryString);

        return ratingAssessments;
        
    }


}