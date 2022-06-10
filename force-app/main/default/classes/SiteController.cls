public without sharing class SiteController {

    /**********************************
    * Invoked from community-related LWCs
    *********************************/

    // Fetch Profile-related information, including proposals and form instances.
    @AuraEnabled //Do not cache
    public static String getProfileSummary() {
        ProfileController.ProfileSummary data = new ProfileController.ProfileSummary(ProfileController.getRunningUserProfileId());
        return JSON.serialize(data);
    }

    // Create new proposal of given type and return its application form instance id.
    @AuraEnabled //Do not cache
    public static String formInstIdOfNewProposal(Id prfId, String grantType) {
        return ProfileController.createProposal(prfId, grantType);
    }

    // Return a list of form instances to be displayed in form viewer for the given record (normally a profile, proposal, or milestone).
    @AuraEnabled //Do not cache
    public static String getFormInstances(Id id) {
        List<Form_Instance__c> fis = FormInstanceController.getFormInstances(id);
        return JSON.serialize(fis);
    }

    // Fetch data related to a form instance including form, form data, form components, ...
    @AuraEnabled //Do not cache
    public static String getFormInstanceData(String formInstanceId) {
        FormInstanceController.FormInstanceData data = new FormInstanceController.FormInstanceData(formInstanceId);
        return JSON.serialize(data);
    }

    // Update form data record if existing, else build new one.
    @AuraEnabled
    public static Boolean updateFormData(String frmInstanceId, String componentId, String value, Boolean isTextarea){
        return FormInstanceController.updateFormData(frmInstanceId, componentId, value, isTextarea);
    }

    // Submit a form instance
    @AuraEnabled
    public static boolean submitForm(String formInstanceId){
        return FormInstanceController.submitForm(formInstanceID);
    }

    // Get form phrase translations
    @AuraEnabled(cacheable=true)
    public static String getTranslations(){
        return FormPhraseController.getTranslations();
    }


    /**********************************
    * Invoked from community-related LWC: Review Community
    (Pulled over from AssessorSiteController - need to go thru))
    *********************************/
    
    private static String getRunningUserAdvisorId() {
        return AdvisorController.getRunningUserAdvisorId();        
    }

    @AuraEnabled
    public static string loadAdvisorSummary(){
        try {
            AdvisorSummary advSummary = new AdvisorSummary(getRunningUserAdvisorId());
            return JSON.serialize(advSummary);
        } catch (Exception e) {
            throw new GFW_Exception('SiteController.loadAdvisorSummary',e.getMessage(),e);
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
                when 'Milestone__c' {
                    List < Assessment__c > reports = AssessorSiteController.getMilestoneAssessments(advisorId, null, null);
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

    public static List < Assessment__c > getProposalAssessments(String advisorId, String status, Integer count) {

        String whereClause = ' WHERE Advisor__c=:advisorId AND Form__c=null AND Milestone__c=null AND Profile__c=null AND Proposal__c!=null';
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
                SELECT Id, Name, Account__c, Advisor__c, Advisor__r.Name, Advisor_Term__c, Date_submitted__c, 
                Milestone__c, Milestone__r.Account_name__c, Milestone__r.Date_submitted__c, Milestone__r.Name, 
                Milestone__r.Review_priority__c, Milestone__r.Country_name__c, Portfolio__c, Profile__c, 
                Proposal__c, Proposal__r.Account__r.Name, Proposal__r.Date_received__c, Review_Form__c, Status__c, 
                Status_external__c, Profile__r.Org_name__c, Profile__r.Account__c, Profile__r.Account__r.Name, 
                Profile__r.Date_submitted__c
                FROM Assessment__c
                WHERE Advisor__c=:advisorId
                AND Form__c=null
                ORDER BY Status_external__c, Date_submitted__c
            ];
        } catch (Exception e) {
            throw new GFW_Exception('SiteController.getAssignedAssessments', 'Could not load Assessments for the current user.', e);
        }
    }

    @AuraEnabled
    public static boolean submitReview(String assessmentId){
        Assessment assess = new Assessment(assessmentId);
        assess.submit();
        return true;
    }


}