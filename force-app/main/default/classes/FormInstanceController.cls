public inherited sharing class FormInstanceController {

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
        system.debug('buildCmpNumberMap: cmpsNumberMap.size() = ' +cmpsNumberMap.size());
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
     * For use in Apex code processing form data
     *********************************/

    // Builds collection of form instance plus child form data, form plus child form components, and form picklists and form picklist phrases.
    public inherited sharing class FormInstanceData {
        public Form_Instance__c frmInst; // Includes child form data
        public Form__c frm; // Includes child form components
        public Form_Picklist__c[] frmPicklists; // Includes child form picklist phrases
        public Map<Id, String> orderingMap;
        public List<String> countryNames = new List<String>();

        public FormInstanceData (Id formInstanceId) {
            // Get form instance and form data
            String fdSubQuery = Utilities.buildChildSubQuery('Form_Data__c', 'Form_Data__r', null);
            frmInst = (Form_Instance__c)Utilities.fetchRecord('Form_Instance__c', formInstanceId, new List<String>{fdSubQuery});
            // Get form and form components
            String fcSubQuery = Utilities.buildChildSubQuery('Form_Component__c', 'Form_Components__r', 'ORDER BY Hierarchical_sort_num__c');
            frm = (Form__c)Utilities.fetchRecord('Form__c', frmInst.Form__c, new List<String>{fcSubQuery});
            // Get ALL form picklists and child form picklist phrases
            String fpSubQuery = Utilities.buildChildSubQuery('Form_Picklist_Phrase__c', 'Form_Picklist_Phrases__r', 'ORDER BY Sort_number__c');
            frmPicklists = (List<Form_Picklist__c>)Utilities.fetchRecords('Form_Picklist__c', null, new List<String>{fpSubQuery});
            // Fetch countries, filtering for current user's FS group
            String fsGroupName = Utilities.fsGroupNameByUser(UserInfo.getUserId());
            Country__c[] countries = [SELECT Name FROM Country__c WHERE Region__r.FS_Group__c = :fsGroupName ORDER BY Name];
            for (Country__c c : countries) countryNames.add(c.Name);

            // Form component numbering map
            orderingMap = buildCmpNumberMap(frm.Form_Components__r);
        }
    }

    // Update form data if existing, else build new one.
    // NOTE 5/11/2022: we're no longer updating the form data's Type__c field. When dust settles, delete that field?
    public static void updateFormData(String frmInstanceId, String componentId, String value, Boolean isTextarea){
        try {
            //Load existing form data record if it exists.
            system.debug('updateFormData: value = ' +value+ '; isTextarea = ' +isTextarea);
            String whereClause = 'WHERE Form_Instance__c=\'' +frmInstanceId+ '\'' +
                    ' AND Form_Component__c=\'' +componentId+ '\'';
            Form_Data__c[] existingFrmData = (List<Form_Data__c>) Utilities.fetchRecords('Form_Data__c', whereClause, null);
            system.debug('updateFormData: existingFrmData = ' +existingFrmData);
            Form_Data__c frmData = new Form_Data__c ();
            if (existingFrmData.size()>0) frmData = existingFrmData[0];
            else {
                frmData.Form_Instance__c = frmInstanceId;
                frmData.Form_Component__c = componentId;
                Id defOwnerId = Utilities.fsDefaultRecordOwnerIdByUser(UserInfo.getUserId());
                system.debug('updateFormData: defOwnerId = ' +defOwnerId);
                if (defOwnerId != null) frmData.OwnerId = defOwnerId;
            }
            system.debug('updateFormData: frmData = ' +frmData);
            //Set the value on either the new object, or existing
            if (isTextarea) frmData.Data_textarea__c = value;
            else frmData.Data_text__c = value;
            //frmData.Data_text__c = value;
            system.debug('updateFormData: frmData = ' +frmData);
            upsert frmData;
        } catch (Exception e) {
            throw new GFW_Exception('FormInstanceController.updateFormData', 'Could not update field value, please refresh and try again.', e);
        }
    }

    public static boolean submitForm(String formInstanceId){
        try {
            // TODO: do we want a data-level validation here or is the UI check enough?
            Form_Instance__c fi = new Form_Instance__c(Id=formInstanceID);
            fi.Date_submitted__c = Date.today();
            update fi;
            return true;           
        } catch (Exception e) {
            throw new GFW_Exception('FormInstanceController.submitForm', 'Could not submit form, please refresh and try again.', e);
        }
    }
    
}