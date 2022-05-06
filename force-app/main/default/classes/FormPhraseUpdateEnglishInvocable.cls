public class FormPhraseUpdateEnglishInvocable {
    
    @InvocableMethod(
        label='Update the phrase-in-English fields in phrase, translations, and referring form components'
        description='Update the phrase-in-English fields in phrase, translations, and referring form components'
    )
    
    // Expects to be called with a single phrase Id (the list parameter is required for invocable methods) 
    public static void updatePhraseInEnglish (List<Id> phraseIds) {
        FormPhraseController.updatePhraseInEnglish(phraseIds[0]);
    }
}