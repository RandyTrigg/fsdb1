public with sharing class FormTagFormPhrasesInvocable {
    @InvocableMethod(
        label='Tag form phrases linked directly or indirectly from this form'
        description='Tag form phrases linked directly or indirectly from this form'
    )
    public static void tagFormPhrases (List<Id> formIds) {
        for (Id formId : formIds) FormController.tagFormPhrases(formId);
    }
}