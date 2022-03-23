public class FormController {

    /**********************************
     * For general use
     *********************************/

    // Search for all form phrases linked directly and indirectly from a given form - tag with form name in SavedSetNames.
    public static void tagFormPhrases (Id formId) {
        // Fetch form and related records.
        Form__c form = (Form__c) Utilities.fetchRecord('Form__c', formId, null);
        Form_Component__c[] comps = (Form_Component__c[]) Utilities.fetchChildRecords('Form_Component__c', formId, 'Form_Item__r.Form_Section__r.Form__c', null);
        // Fetch form phrases already tagged with the form name.
        Map<Id, Form_Phrase__c> fPhrasesTagged = new Map<Id, Form_Phrase__c> ([
            SELECT Id 
            FROM Form_Phrase__c
            WHERE SavedSetNames__c = : form.name
        ]);
        // Gather ids of form phrases "under" given form.
        Set<Id> formPhraseIds = new Set<Id>();
        formPhraseIds.addAll(fetchIdsFromFields(new List<Form__c>{form}, getFormPhraseFieldNames('Form__c')));
        formPhraseIds.addAll(fetchIdsFromFields(comps, getFormPhraseFieldNames('Form_Component__c')));
        // Fetch the form phrases.
        Form_Phrase__c[] fPhrasesToTag = [SELECT SavedSetNames__c FROM Form_Phrase__c WHERE Id IN : formPhraseIds];
        Map<Id, Form_Phrase__c> toUpdate = new Map<Id, Form_Phrase__c>();
        // Tag form phrases where necessary.
        for (Form_Phrase__c fp : fPhrasesToTag) {
            if (fp.SavedSetNames__c != form.name) {
                fp.SavedSetNames__c = form.name;
                toUpdate.put(fp.Id, fp);
            }
        } 
        // Untag formerly tagged form phrases where necessary.
        for (Form_Phrase__c fp : fPhrasesTagged.values()) {
            if (!formPhraseIds.contains(fp.Id)) {
                fp.SavedSetNames__c = null;
                toUpdate.put(fp.Id, fp);
            }
        }
        if (toUpdate.size() > 0) Database.executeBatch(new GenericUpdateRecordsBatch(toUpdate.values()), 100);
    }

    // Get field names that start with "Form_Phrase" for the given object.
    private static String[] getFormPhraseFieldNames (String objName) {
        String[] returnVal = new List<String>();
        for (String fName : Utilities.fieldNamesForObject(objName)) {
            if (fName.left(11) == 'Form_Phrase') returnVal.add(fName);
        }
        return returnVal;
    }

    // Gather ids from given lookup fields of given records.
    private static Set<Id> fetchIdsFromFields(sObject[] records, String[] fieldNames) {
        Set<Id> returnVal = new Set<Id> ();
        for (sObject rec : records) {
            for (String fName : fieldNames) {
                Object val = rec.get(fName);
                if (val != null && val instanceof Id) returnVal.add((Id)val);
            }
        }
        return returnVal;
    }
}