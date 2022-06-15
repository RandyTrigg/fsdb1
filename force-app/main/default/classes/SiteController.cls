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
    * Invoked from community-related LWC for Review Community
    (Based on AssessorSiteController)
    *********************************/

    @AuraEnabled
    public static string getAdvisorSummary(){
        try {
            AdvisorController.AdvisorSummary advSummary = new AdvisorController.AdvisorSummary(AdvisorController.getRunningUserAdvisorId());
            return JSON.serialize(advSummary);
        } catch (Exception e) {
            throw new GFW_Exception('SiteController.loadAdvisorSummary',e.getMessage(),e);
        }
    }

    @AuraEnabled
    public static String loadAdvisorRecords(String objectType){
        return AdvisorController.loadAdvisorRecords(objectType);
    }

    


}