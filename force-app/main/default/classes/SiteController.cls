public without sharing class SiteController {

    /**********************************
    * Invoked from community-related LWCs
    *********************************/

    // Fetch name for site header
    @AuraEnabled
    public static String getHeaderName(){
        List<String> permSets = new List<String>(Utilities.currentUserPermissionSetNames());
        String name;
        if (permSets.contains('ReviewCommunity_BFF')) {
            name = AdvisorController.getRunningUserAdvisorHeaderName();
        } else if (permSets.contains('GrantsCommunity_BFF')) {
            name = ProfileController.getRunningUserProfileHeaderName();
        }
        return name;
    }
    
    // Handle self-registration
    @AuraEnabled
    public static String handleRegistration(String registrantJSON){
        return BFFGrantsRegistrationController.handleRegistration(registrantJSON);
    }
    
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

    // Get proposal-related info for proposal landing page
    @AuraEnabled  //Do not cache
    public static String getProposalSummary(String propId) {
        ProposalController.ProposalSummary prpSummary = new ProposalController.ProposalSummary(propId);
        return JSON.serialize(prpSummary);
    }



    /**********************************
    * Invoked from community-related LWC for Review Community
    *********************************/

    @AuraEnabled
    public static string getAdvisorSummary(){
        AdvisorController.AdvisorSummary advSummary = new AdvisorController.AdvisorSummary(AdvisorController.getRunningUserAdvisorId());
        return JSON.serialize(advSummary);
    }

    // Fetch data related to an assessment. For assessments linked to a form, build form instance if needed.
    @AuraEnabled //Do not cache
    public static String getAssessmentData(String assessmentId) {
        AssessmentController.AssessmentData data = new AssessmentController.AssessmentData(assessmentId);
        return JSON.serialize(data);
    }
}