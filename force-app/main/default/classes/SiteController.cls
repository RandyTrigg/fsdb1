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
    public static List<Form_Instance__c> getFormInstances(Id id) {
        return FormInstanceController.getFormInstances(id);
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
}