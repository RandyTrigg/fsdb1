public with sharing class LetterUpdatedInvocable {
    @InvocableMethod(
        label='Letter record updated'
        description='Letter record updated'
    )
    public static void letterUpdated(List<Id> letterIds) {
        for (Id letId : letterIds) {
            // If date sent or date received is non-blank, then set a related date field specified in linked template.
            LetterController.setDateFieldInRelatedRecord(letId);
        }
    }
}