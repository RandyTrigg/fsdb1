public class FormInstanceController {

    /**********************************
     * For use in Lightning components
     *********************************/
    
    // Fetch all local fields of a form instance record, plus a few specified related fields. 
    @AuraEnabled
    public static Form_Instance__c getFormInstance(Id fiId) {
        String[] relatedFieldNames = new List<String>{'Profile__r.Name', 'Profile__r.Account__c', 'Profile__r.Account__r.Name'};
        return (Form_Instance__c) Utilities.fetchRecord('Form_Instance__c', fiId, relatedFieldNames);
    }
    
    // Fetch the form's form components, plus a few specified related fields. 
    @AuraEnabled
    public static Form_Component__c[] getComponents(Id formId) {
        String[] relatedFieldNames = new List<String>{
            'Form_Phrase__r.Phrase_in_English__c'
			};
        String whereClause = 
            ' WHERE Form__c = \'' +formId+ '\'' +
            ' ORDER BY Hierarchical_sort_num__c';
        return (List<Form_Component__c>) Utilities.fetchRecords('Form_Component__c', whereClause, relatedFieldNames);
    }
    
    // Fetch all local fields of the form instance's form data, plus a few specified related fields. 
    @AuraEnabled
    public static Form_Data__c[] getFormData(Id fiId) {
        String[] relatedFieldNames = new List<String>{
            'Form_Component__r.Form__c', 'Form_Component__r.Form__r.Name',
            'Form_Component__r.Name', 'Form_Component__r.NoFormDataClone__c'
			};
        String whereClause = 
            ' WHERE Form_Instance__c = \'' +fiId+ '\'' +
            ' ORDER BY Form_Component__c, Index__c, LastModifiedDate DESC';
        return (List<Form_Data__c>) Utilities.fetchRecords('Form_Data__c', whereClause, relatedFieldNames);
    }

    // Return a mapping of form component id to its appropriate number string based on hierarchical sort order.
    @AuraEnabled
    public static Map<Id, String> buildCmpNumberMap (Form_Component__c[] cmps) {
        Map<Id, Form_Component__c> cmpsMap = new Map<Id, Form_Component__c> (cmps);
        Map<Id, String> cmpsNumberMap = new Map<Id, String> ();
        // Build mapping of id to count of its descendant form components.
        Map<Id, Integer> descendantCmpsCount = new Map<Id, Integer> ();
        for (Form_Component__c cmp : cmps) {
            if (cmp.Numbered__c) {
                Id cId = cmp.Group_component__c;
                while (cId != null) { // Increment the count of parent, grandparent, etc.
                    Boolean hasCount = descendantCmpsCount.containsKey(cId);
                    descendantCmpsCount.put(cId, hasCount ? descendantCmpsCount.get(cId) + 1 : 1);
                    cId = cmpsMap.get(cId).Group_component__c;
                }
            }
        }
        // Build mapping of id to form component number based on hierarchical position.
        Integer level;
        Integer priorLevel = 0;
        String num;
        String priorNum = '0';
        Boolean numbering = true;
        for (Form_Component__c cmp : cmps) {
            level = Integer.valueOf(cmp.Hierarchical_level_num__c);
            // If numbering is off, leave it off until we bounce back to the level where it was turned off.
            if (!numbering && level <= priorLevel) numbering = true;
            // Turn numbering off if this item isn't numbered nor are any of its descendants.
            if (!cmp.Numbered__c && !descendantCmpsCount.containsKey(cmp.Id)) numbering = false;
            if (numbering) { // The next cmp needs numbering.
                // Increment the number at the (possibly new) level.
                system.debug('buildCmpNumberMap: num = ' +num+ '; priorNum = ' +priorNum+ '; level = ' +level);
                num = incCmpNum(priorNum, level);
                // If cmp is supposed to be sub-numbered, then start it at the next level down.
                if (cmp.Sub_numbered__c) {
                    level = level+1;
                    system.debug('buildCmpNumberMap: num = ' +num+ '; priorNum = ' +priorNum+ '; level = ' +level);
                    num = incCmpNum(num, level);
                }
                priorLevel = level;
                priorNum = num;
            } else num = null;
            if (num != null) cmpsNumberMap.put(cmp.Id, cmpNumDisplay(num));
        }
        return cmpsNumberMap;
    }
    
    // Increment a form component number to the next one at the given zero-based level, possibly popping higher levels.
    // A cmp number is a period-delimited sequence of numbers, ala 1.3.2.
    // For level=1, the result is 1.4; for level=0, the result is 2.
    private static String incCmpNum (String numStr, Integer level) {
        String[] numStrList = numStr.split('\\.'); // Break up string using '.' as delimiter.
        // Compute a "slice" of the first level+1 elements of the num list. 
        String[] numArr = new List<String> ();
        for(Integer a = 0; a < Math.min(numStrList.size(), level+1); a++) numArr.add(numStrList[a]);
        system.debug('incCmpNum: level = ' +level+ '; numStrList = ' +JSON.serialize(numStrList));
        system.debug('incCmpNum: numArr = ' +JSON.serialize(numArr));
        if (numArr.size() < level+1) numArr.add('1');
        else numArr.add(String.valueOf(Integer.valueOf(numArr.remove(numArr.size()-1)) + 1));
        return String.join(numArr, '.');
    }

    // Reformat a cmp number for display in cmp labels.  For example, 1.3.2 becomes 1c.2.
    private static String cmpNumDisplay (String numStr) {
        String[] numArr = numStr.split('\\.');
        if (numArr.size() <= 1) return numStr;
        String prefix = numArr[0] + String.fromCharArray(new List<Integer> {'a'.charAt(0) + Integer.valueOf(numArr[1]) - 1});
        // Attach prefix to rest of the item number.
        String[] numArrResult = new List<String> {prefix};
        for (Integer i = 2; i < numArr.size(); i++) numArrResult.add(numArr[i-1]);
        return String.join(numArrResult, '.');
    }

    /**********************************
     * For general use
     *********************************/

     /**********************************
     * For use in Apex code processing form data
     *********************************/
    
    // Class that includes all form data associated with the given form instance
    public class DataManager {
        public Form_Instance__c fi;
        public Profile__c prof;
        public Advisor_Term__c advt;
        public Map<String, String> dataValue, dataValueText, dataValueTextArea, dataTargetId;

        private Id fiId;
        private List<Form_Component__c> comps;
        private Map<String, Id> compIds;
        private List<Form_Picklist_Phrase__c> picklistPhrases;
        private Map<String, String> picklistPhraseValues;
        private List<Form_Data__c> fds;
        private Map<String, Form_Data__c> dataRecord;
        
        public DataManager(Id fiId) {
            this.fiId = fiId;
            this.fi = getFormInstance(fiId);
            // Get profile or advisor term.
            system.debug('DataManager: fi.Profile__c = ' +fi.Profile__c+ '; fi.Advisor_Term__c = ' +fi.Advisor_Term__c);
            if (fi.Profile__c != null) {
                prof = [
                    SELECT Id, Account__c, Community_contact_email__c, Language__c
                    FROM Profile__c 
                    WHERE Id = : fi.Profile__c
                ];
            } else if (fi.Advisor_Term__c != null) {
                advt = [
                    SELECT Id, Advisor__c, Advisor__r.Community_contact_email__c, Advisor__r.Language__c
                    FROM Advisor_Term__c 
                    WHERE Id = : fi.Advisor_Term__c
                ];
            }
            comps = getComponents(fi.Form__c);
            // Map from component name to id.  NOTE: Trouble if multiple components in a form have the same name.
            compIds = new Map<String, Id> ();
            for (Form_Component__c c : comps) compIds.put(c.Name, c.Id);
            // Get picklist phrases for those components, and build lookup table from picklist option phrase names to their English translations.
            picklistPhrases = new List<Form_Picklist_Phrase__c> ([
                SELECT Name, Form_Phrase__r.Phrase_in_English__c
                FROM Form_Picklist_Phrase__c
                WHERE Form_Picklist__c IN (SELECT Form_Picklist__c FROM Form_Component__c WHERE Id IN : compIds.values())
            ]);
            picklistPhraseValues = new Map<String, String> ();
            for (Form_Picklist_Phrase__c p : picklistPhrases) picklistPhraseValues.put(p.Name, p.Form_Phrase__r.Phrase_in_English__c);
            fds = getFormData(fi.Id);
            // Lookup tables map component name to record, value and target Id.
            dataRecord = new Map<String, Form_Data__c> ();
            dataValue = new Map<String, String> ();
            dataValueText = new Map<String, String> ();
            dataValueTextArea = new Map<String, String> ();
            dataTargetId = new Map<String, String> ();
            for (Form_Data__c fd : fds) {
                dataRecord.put(fd.Form_Component__r.Name, fd);
                dataValueText.put(fd.Form_Component__r.Name, fd.Data_text__c);
                dataValueTextArea.put(fd.Form_Component__r.Name, fd.Data_textarea__c);
                dataValue.put(fd.Form_Component__r.Name, fd.Data_text__c == null ? fd.Data_textarea__c : fd.Data_text__c);
                dataTargetId.put(fd.Form_Component__r.Name, fd.Target_Id__c);
            }
            system.debug('DataManager: dataValue = ' +JSON.serialize(dataValue));
        }    
    }

    // Builds collection of form instance plus child form data, form plus child form components, and form picklists and form picklist phrases.
    public class FormInstanceData {
        public Form_Instance__c frmInst; // Includes child form data
        public Form__c frm; // Includes child form components
        public Form_Picklist__c[] frmPicklists; // Includes child form picklist phrases

        public FormInstanceData (Id formInstanceId) {
            // Get form instance and form data
            String fdSubQuery = Utilities.buildChildSubQuery('Form_Data__c', 'Form_Data__r', null);
            frmInst = (Form_Instance__c)Utilities.fetchRecord('Form_Instance__c', formInstanceId, new List<String>{fdSubQuery});
            // Get form and form components
            String fcSubQuery = Utilities.buildChildSubQuery('Form_Component__c', 'Form_Components__r', 'ORDER BY Hierarchical_sort_num__c');
            frm = (Form__c)Utilities.fetchRecord('Form__c', frmInst.Form__c, new List<String>{fcSubQuery});
            // Get ALL form picklists and child form picklist phrases
            String fpSubQuery = Utilities.buildChildSubQuery('Form_Picklist_Phrase__c', 'Form_Picklist_Phrases__r', null);
            frmPicklists = (List<Form_Picklist__c>)Utilities.fetchRecords('Form_Picklist__c', null, new List<String>{fpSubQuery});
        }
    }
    
    @AuraEnabled //Do not cache
    public static String getFormInstanceData(String formInstanceId) {
        FormInstanceData data = new FormInstanceData(formInstanceId);
        return JSON.serialize(data);
    }    

    /**********************************
     * For use in VisualForce pages
     *********************************/
    
    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;
 
    public FormInstanceController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
    }
 
    public FormInstanceController(ApexPages.StandardSetController standardSetController) {
        this.standardSetController = standardSetController;
    }
            
    public PageReference doCancel() {       
        return (standardSetController != null) ? standardSetController.cancel() : standardController.cancel();   
    }
    
    private Set<Id> getSelectedIds() {
        Set<Id> selIds;
        if (standardSetController != null) {
            Map<Id, Form_Instance__c> selMap = new Map<Id, Form_Instance__c> ((List<Form_Instance__c>) standardSetController.getSelected());
            selIds = selMap.keySet();
        } else {
            selIds = new Set<Id> {standardController.getId()};
        }
        return selIds;
    }
    
}