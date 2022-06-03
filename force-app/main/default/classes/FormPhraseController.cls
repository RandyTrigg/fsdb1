public inherited sharing class FormPhraseController {

    /**********************************
    * For general use
    *********************************/
    
    // Update the phrase-in-English fields in form phrase, its form phrase translations, and referring form components.
    public static void updatePhraseInEnglish (Id phraseId) {
        // Fetch form phrase and its translations.
        Form_Phrase__c phr = [
            SELECT Phrase_in_English__c, Phrase_in_English_trimmed__c
            FROM Form_Phrase__c
            WHERE Id = : phraseId
        ];
        Form_Phrase_Translation__c[] trs = [
            SELECT Id, Language__c, Text__c, Text_in_English__c
            FROM Form_Phrase_Translation__c
            WHERE Form_Phrase__c = : phraseId            
        ];
        system.debug('updatePhraseInEnglish phr = ' +JSON.serialize(phr));
        system.debug('updatePhraseInEnglish trs = ' +JSON.serialize(trs));
        // Get the English text of the phrase if any.
        String textEng;
        for (Form_Phrase_Translation__c tr : trs) if (tr.Language__c == 'English') textEng = tr.Text__c;
        if (textEng == null) return; // Do nothing if there's no translation into English.
        String textEngTrimmed = textEng.left(255);
        // Update phrase and translations where necessary.
        if (phr.Phrase_in_English__c != textEng || phr.Phrase_in_English_trimmed__c != textEngTrimmed) {
            phr.Phrase_in_English__c = textEng;
            phr.Phrase_in_English_trimmed__c = textEngTrimmed;
            system.debug('updatePhraseInEnglish textEng = ' +textEng+ '; textEngTrimmed = ' +textEngTrimmed);
            update phr;
        }
        Form_Phrase_Translation__c[] trsToUpdate = new List<Form_Phrase_Translation__c> ();
        for (Form_Phrase_Translation__c tr : trs) {
            if (tr.Text_in_English__c != textEng) {
                tr.Text_in_English__c = textEng;
                trsToUpdate.add(tr);
            }
        }
        if (trsToUpdate.size() > 0) update trsToUpdate;
        // Check and update form components pointing to this phrase.
        Form_Component__c[] comps = [
            SELECT Form_phrase_in_English__c
            FROM Form_Component__c
            WHERE Form_Phrase__c = : phraseId
        ];
        Form_Component__c[] compsToUpdate = new List<Form_Component__c> ();
        for (Form_Component__c comp : comps) {
            if (comp.Form_phrase_in_English__c != textEng) {
                comp.Form_phrase_in_English__c = textEng;
                compsToUpdate.add(comp);
            }
        }
        if (compsToUpdate.size() > 0) update compsToUpdate;
    }

    // Form phrase translations for LWC 
    @AuraEnabled(cacheable=true)
    public static string getTranslations(){
        try {
            Form_Phrase_Translation__c[] translations = [
                SELECT Text__c, Text_in_English__c, Form_Phrase__c, Form_Phrase__r.Name, Language__c
                FROM Form_Phrase_Translation__c
                WHERE Form_Phrase__r.Active__c = true
            ];
            return JSON.serialize(translations);
        } catch (Exception e) {
            throw new GFW_Exception(e.getMessage());
        }
    }
    
}