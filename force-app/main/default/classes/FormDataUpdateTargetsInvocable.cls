public class FormDataUpdateTargetsInvocable {
    
    @InvocableMethod(
        label='Update target fields from a form instance\'s form data'
        description='Update target fields from a form instance\'s form data'
    )
    public static void updateTargetFields (List<Id> formInstanceIds) {
        for (Id fiId : formInstanceIds) {
            FormDataController.updateTargetFields(fiId);
        }
    }
    
}