public class FormDataPrefillFormInstanceInvocable {
    
    @InvocableMethod(
        label='Prefill form data for a (new) form instance'
        description='Prefill form data for a (new) form instance'
    )
    public static void prefillFormInstance (List<Id> formInstanceIds) {
        for (Id fiId : formInstanceIds) {
            FormDataController.prefillFormInstance(fiId);
        }
    }
    
}