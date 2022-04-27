public class FormInstanceController {

    /**********************************
     * For use in Lightning components
     *********************************/
    
    // Fetch all local fields of a form instance record, plus a few specified related fields. 
    @AuraEnabled
    public static Form_Instance__c getFormInstance(Id fiId) {
        String[] relatedFieldNames = new List<String>{'Profile__r.Name', 'Profile__r.Account__c'};
        return (Form_Instance__c) Utilities.fetchRecord('Form_Instance__c', fiId, relatedFieldNames);
    }

    @AuraEnabled
    public static Form__c getForm(Id formId) {
        return [
            SELECT Id, Name, Form_Phrase_Title__c, Form_Phrase_Title__r.Phrase_in_English__c
            FROM Form__c
            WHERE Id = :formId
        ][0];
    }

    @AuraEnabled
    public static Form_Section__c[] getSections(Id formId) {
        return [
            SELECT Id, Name, Form_Phrase_Title__c, Form_Phrase_Title__r.Phrase_in_English__c, Sort_number__c
            FROM Form_Section__c
            WHERE Form__c = :formId
            ORDER BY Sort_number__c
        ];
    }

    @AuraEnabled
    public static Form_Item__c[] getItems(Id sectionId) {
        return [
            SELECT Id, Name, Form_Phrase__c, Form_Phrase__r.Phrase_in_English__c, 
            Sort_number__c, Sort_number_child__c, Sort_number_parent__c,
            Hierarchical_sort_num__c, Hierarchical_level_num__c, Sub_numbered__c,
            Type__c, Number_of_columns__c, Numbered__c, Hide_on_disable__c,
            Form_Item_Parent__c
            FROM Form_Item__c
            WHERE Form_Section__c = :sectionId
            ORDER BY Hierarchical_sort_num__c
        ];
    }

    @AuraEnabled
    public static Form_Item__c[] getItemsForForm(Id formId) {
        return [
            SELECT Id, Name, Form_Section__c,
            Form_Phrase__c, Form_Phrase__r.Phrase_in_English__c, 
            Sort_number__c, Sort_number_child__c, Sort_number_parent__c,
            Hierarchical_sort_num__c, Hierarchical_level_num__c, Sub_numbered__c,
            Type__c, Number_of_columns__c, Numbered__c, Hide_on_disable__c,
            Form_Item_Parent__c
            FROM Form_Item__c
            WHERE Form_Section__r.Form__c = :formId
            ORDER BY Hierarchical_sort_num__c
        ];
    }

    @AuraEnabled
    public static Form_Component__c[] getComponents(Id itemId) {
        return [
            SELECT Id, Name, Form_Phrase__c, Form_Phrase__r.Phrase_in_English__c, 
            Sort_number__c, Form_Picklist__c,
            Type__c, Required__c, Classes__c, Group_Component__c
            FROM Form_Component__c
            WHERE Form_Item__c = :itemId
            AND Group_Component__c = null
            ORDER BY Sort_number__c
        ];
    }

    // Fetch all form components in form.  Note inclusion of sub-components using Group Component lookup.
    @AuraEnabled
    public static Form_Component__c[] getComponentsForForm(Id formId) {
        return [
            SELECT Id, Name, Form_Item__c, Form_Item__r.Form_Section__c,
            Form_Phrase__c, Form_Phrase__r.Phrase_in_English__c, 
            Sort_number__c, Form_Picklist__c,
            Type__c, Required__c, Classes__c, Group_Component__c,
            (SELECT Id, Name, Form_Phrase__c, Form_Phrase__r.Phrase_in_English__c, 
             Sort_number__c, Form_Picklist__c,
             Type__c, Required__c, Classes__c
             FROM Form_Components__r
            )
            FROM Form_Component__c
            WHERE Form_Item__r.Form_Section__r.Form__c = :formId
            AND Group_Component__c = null
            ORDER BY Sort_number__c
        ];
    }

    @AuraEnabled
    public static Form_Component__c[] getComponentsInGroup(Id groupComponentId) {
        return [
            SELECT Id, Name, Form_Phrase__c, Form_Phrase__r.Phrase_in_English__c, 
            Sort_number__c, Form_Picklist__c,
            Type__c, Required__c, Classes__c, Group_Component__c
            FROM Form_Component__c
            WHERE Group_Component__c = :groupComponentId
            ORDER BY Sort_number__c
        ];
    }

    @AuraEnabled
    public static Form_Data__c[] getFormData(Id componentId, Id formInstanceId) {
        return [
            SELECT Id, Name, Type__c,
            Form_Component__c, Data_text__c, Data_textarea__c, Index__c
            FROM Form_Data__c
            WHERE Form_Component__c = :componentId
            AND Form_Instance__c = :formInstanceId
            ORDER BY Form_Component__c, Index__c, LastModifiedDate DESC
        ];
    }

    @AuraEnabled
    public static Form_Data__c[] getFormDataForFormInstance(Id formInstanceId) {
        return [
            SELECT Id, Name, Type__c,
            Form_Component__c, Form_Component__r.Form_Item__c, Form_Component__r.Form_Item__r.Form_Section__c,
            Data_text__c, Data_textarea__c, Index__c, 
            Form_Component__r.Name, Target_Id__c, Applicant__c,
            Form_Component__r.NoFormDataClone__c,
            Form_Instance__r.Language__c
            FROM Form_Data__c
            WHERE Form_Instance__c = :formInstanceId
            AND Disabled__c = false
            ORDER BY Form_Component__c, Index__c, LastModifiedDate DESC
        ];
    }
    
    // Fetch all local fields of a form data record, plus a few specified related fields. 
    @AuraEnabled
    public static Form_Data__c[] getFormDataForFormInstanceAllFields(Id fiId) {
        String objName = 'Form_Data__c';
        String[] relatedFieldNames = new List<String>{
            'Form_Component__r.Form_Item__c', 'Form_Component__r.Form_Item__r.Form_Section__c',
            'Form_Component__r.Name', 'Form_Component__r.NoFormDataClone__c'
			};
		String[] fieldNames = Utilities.fieldNamesForObject(objName);
        fieldNames.addAll(relatedFieldNames);
        String q = 
            'SELECT '+ String.join(fieldNames, ', ') +
            ' FROM '+ objName +
            ' WHERE Form_Instance__c = : fiId';
        system.debug('get all fields for ' +objName+ ': q = ' +q);
        return Database.query(q);
    }

    /**********************************
     * Render form instance to text - called from aura and elsewhere
     *********************************/
    
    // For given form instance, return text rendering of its form data, including html tags.  
    // Suitable for pushing into rich text area fields.
    public static String renderFormInstanceText(Id fiId) {
        String[] resultStrs = new List<String> ();
        String sectionsJson = renderSectionTexts (fiId);
        system.debug('renderFormInstanceText: responseStr = ' +JSON.serialize(sectionsJson));
        Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(sectionsJson);
        system.debug('renderFormInstanceText: response = ' +JSON.serialize(response));
        Map<String, Object> results = (Map<String, Object>)response.get('results');
        List<Object> sections = (List<Object>)results.get('sections');
        for (Object sectionObj : sections) {
            Map<String, Object> sectionMap = (Map<String, Object>) sectionObj;
            resultStrs.add('<big><b>' + (String)sectionMap.get('title') + '</b></big >');
            resultStrs.add((String)sectionMap.get('text'));
        }
        return String.join(resultStrs, '<br/><br/>');
    }

    // For given form instance, return list of pairs of section title and rendered section text.
    // Suitable for invocation from left side of review interfaces.
    @AuraEnabled
    public static String renderSectionTexts(Id fiId) {
        strike_responseData responseData = new strike_responseData();
        // Retrieve form structure and data.
        Form_Instance__c fi = getFormInstanceAllFields(fiId);
        Form_Data__c[] fds = getFormDataForFormInstance(fiId);
        Id formId = fi.Form__c;
        Form_Section__c[] secs = getSections(formId);
        Form_Item__c[] items = getItemsForForm(formId);
        Form_Component__c[] comps = getComponentsForForm(formId);
        // Walk through sections gathering titles and rendering texts.
        Object[] sectionResults = new List<Object>();
        for (Form_Section__c sec : secs) {
            String secTitle = sec.Form_Phrase_Title__r.Phrase_in_English__c != null ? sec.Form_Phrase_Title__r.Phrase_in_English__c : sec.Name;
            Form_Item__c[] secItems = new List<Form_Item__c> ();
            for (Form_Item__c item : items) if (item.Form_Section__c == sec.Id) secItems.add(item);
            Form_Component__c[] secComps = new List<Form_Component__c> ();
            for (Form_Component__c comp : comps) if (comp.Form_Item__r.Form_Section__c == sec.Id) secComps.add(comp);
            Form_Data__c[] secData = new List<Form_Data__c> ();
            for (Form_Data__c fd : fds) if (fd.Form_Component__r.Form_Item__r.Form_Section__c == sec.Id) secData.add(fd);
            system.debug('renderSectionTexts: secTitle = ' +secTitle+ '; # items = ' +secItems.size()+ '; # comps = ' +secComps.size()+ '; # data = ' +secData.size());
            sectionResults.add(new Map<String, Object> {
                'title' => secTitle,
                'text' => renderItemsText(secItems, secComps, secData)
            });
        }
        responseData.results = new Map<String, Object> {
            'sections' => sectionResults
        };
        system.debug('renderSectionTexts: responseData = ' +JSON.serialize(responseData));
        return responseData.getJsonString();
    }

    // Return text rendering of a list of items.
    private static String renderItemsText (Form_Item__c[] items, Form_Component__c[] components, Form_Data__c[] formData) {
        Map<Id, String> itemNumMap = buildItemNumberMap(items);
        String[] itemTexts = new List<String>();
        for (Form_Item__c item : items) {
            Boolean inTable = item.Type__c.contains('Table');
            // Gather form components and form data belonging to this item.
            Form_Component__c[] comps = new List<Form_Component__c>();
            for (Form_Component__c comp : components) if (comp.Form_Item__c == item.Id) comps.add(comp);
            // Organize this item's form data by which table row (if any) it's in - 0 means not in a table row.
            Map<Integer, List<Form_Data__c>> fdMap = new Map<Integer, List<Form_Data__c>>();
            for (Form_Data__c fd : formData) {
                if (fd.Form_Component__r.Form_Item__c == item.Id) {
                    Integer row = fd.Index__c > 0 ? Integer.valueOf(fd.Index__c) : 0;
                    if (!fdMap.containsKey(row)) fdMap.put(row, new List<Form_Data__c>());
                    fdMap.get(row).add(fd);
                }
            }
            if (fdMap.size() > 0) { // Skip items with no non-disabled data.
                // Build text for this item, one table row at a time.
                String num = itemNumMap.get(item.Id);
                String itemLabel = '<b>'+ (num != null ? num + '. ' : '') + item.Form_Phrase__r.Phrase_in_English__c +'</b>';
                // First render components not in a table (if any).
                String itemNonTableTexts = '';
                if (fdMap.containsKey(0) && fdMap.get(0).size() > 0) itemNonTableTexts = renderComponentsText (comps, fdMap.get(0), inTable);
                // If the first non-table component has no label (starts with non-breaking spaces), then only one return after item label, else two.
                Boolean addExtraSpace = itemNonTableTexts.length() == 0 || !itemNonTableTexts.startsWith('&nbsp;&nbsp;');
                itemTexts.add(itemLabel +'<br/>'+ (addExtraSpace ? '<br/>' : '') + itemNonTableTexts);
                // Next, render components in table, one row at a time, bailing when encountering a row with no data.
                Integer row = 1;
                while (fdMap.containsKey(row) && fdMap.get(row).size() > 0) {
                    itemTexts.add(renderComponentsText (comps, fdMap.get(row), inTable));
                    row += 1;
                }
            }
        }
        return String.join(itemTexts, '<br/><br/>');
    }

    // Return a mapping of item id to its appropriate item number string based on hierarchical sort order.
    public static Map<Id, String> buildItemNumberMap (Form_Item__c[] items) {
        Map<Id, Form_Item__c> itemsMap = new Map<Id, Form_Item__c> (items);
        Map<Id, String> itemsNumberMap = new Map<Id, String> ();
        // Build mapping of id to count of its descendant items.
        Map<Id, Integer> descendantItemsCount = new Map<Id, Integer> ();
        for (Form_Item__c item : items) {
            if (item.Numbered__c) {
                Id iId = item.Form_Item_Parent__c;
                while (iId != null) { // Increment the count of parent, grandparent, etc.
                    Boolean hasCount = descendantItemsCount.containsKey(iId);
                    descendantItemsCount.put(iId, hasCount ? descendantItemsCount.get(iId) + 1 : 1);
                    iId = itemsMap.get(iId).Form_Item_Parent__c;
                }
            }
        }
        // Build mapping of id to item number based on hierarchical position.
        Integer level;
        Integer priorLevel = 0;
        String num;
        String priorNum = '0';
        Boolean numbering = true;
        for (Form_Item__c item : items) {
            level = Integer.valueOf(item.Hierarchical_level_num__c);
            // If numbering is off, leave it off until we bounce back to the level where it was turned off.
            if (!numbering && level <= priorLevel) numbering = true;
            // Turn numbering off if this item isn't numbered nor are any of its descendants.
            if (!item.Numbered__c && !descendantItemsCount.containsKey(item.Id)) numbering = false;
            if (numbering) { // The next item needs numbering.
                // Increment the number at the (possibly new) level.
                system.debug('buildItemNumberMap: num = ' +num+ '; priorNum = ' +priorNum+ '; level = ' +level);
                num = incItemNum(priorNum, level);
                // If item is supposed to be sub-numbered, then start it at the next level down.
                if (item.Sub_numbered__c) {
                    level = level+1;
                    system.debug('buildItemNumberMap: num = ' +num+ '; priorNum = ' +priorNum+ '; level = ' +level);
                    num = incItemNum(num, level);
                }
                priorLevel = level;
                priorNum = num;
            } else num = null;
            if (num != null) itemsNumberMap.put(item.Id, itemNumDisplay(num));
        }
        return itemsNumberMap;
    }
    
    // Increment an item number to the next one at the given zero-based level, possibly popping higher levels.
    // An item number is a period-delimited sequence of numbers, ala 1.3.2.  
    // For level=1, the result is 1.4; for level=0, the result is 2.
    private static String incItemNum (String numStr, Integer level) {
        String[] numStrList = numStr.split('\\.'); // Break up string using '.' as delimiter.
        // Compute a "slice" of the first level+1 elements of the num list. 
        String[] numArr = new List<String> ();
        for(Integer a = 0; a < Math.min(numStrList.size(), level+1); a++) numArr.add(numStrList[a]);
        system.debug('incItemNum: level = ' +level+ '; numStrList = ' +JSON.serialize(numStrList));
        system.debug('incItemNum: numArr = ' +JSON.serialize(numArr));
        if (numArr.size() < level+1) numArr.add('1');
        else numArr.add(String.valueOf(Integer.valueOf(numArr.remove(numArr.size()-1)) + 1));
        return String.join(numArr, '.');
    }

    // Reformat an item number for display in item labels.  For example, 1.3.2 becomes 1c.2.
    private static String itemNumDisplay (String numStr) {
        String[] numArr = numStr.split('\\.');
        if (numArr.size() <= 1) return numStr;
        String prefix = numArr[0] + String.fromCharArray(new List<Integer> {'a'.charAt(0) + Integer.valueOf(numArr[1]) - 1});
        // Attach prefix to rest of the item number.
        String[] numArrResult = new List<String> {prefix};
        for (Integer i = 2; i < numArr.size(); i++) numArrResult.add(numArr[i-1]);
        return String.join(numArrResult, '.');
    }
    
    // Return text rendering of a list of components, possibly those in a table row.
    private static String renderComponentsText (Form_Component__c[] components, Form_Data__c[] formData, Boolean inTable) {
        String[] compTexts = new List<String>();
        Map<Id, Form_Data__c> dataMap = new Map<Id, Form_Data__c>();
        for (Form_Data__c fd : formData) dataMap.put(fd.Form_Component__c, fd);
        for (Form_Component__c c : components) {
            // First render sub-components recursively if any.
            if (c.Form_Components__r.size() > 0) compTexts.add(renderComponentsText(c.Form_Components__r, formData, inTable));
            if (dataMap.containsKey(c.Id)) compTexts.add(renderComponentText (c, dataMap.get(c.Id), inTable));
        }
        return String.join(compTexts, '<br/><br/>');
    }

    // Return text rendering of a single component.
    private static String renderComponentText (Form_Component__c c, Form_Data__c fd, Boolean inTable) {
        String[] compTexts = new List<String>();
        // Only render component if it has data.
        if (fd != null) {
            // If we're in a table, then prefix the phrase with component name to help identify table column.
            String formPhrase = c.Form_Phrase__r.Phrase_in_English__c;
            String phrase = (inTable ? c.Name + ': ' : '') + (formPhrase != null ? formPhrase : ''); 
            if (phrase.length() > 0) compTexts.add('<b>'+ phrase +'</b>');
            // Render data, surrounding "||" with spaces to enable line breaks, and indenting with two spaces.
            String txt = fd.Data_textarea__c != null ? fd.Data_textarea__c : fd.Data_text__c;
            if (txt != null && txt.length() > 0) compTexts.add('&nbsp;&nbsp;' + txt.replace('||', ' || '));
        }
        return String.join (compTexts, '<br/>');
    }

    /**********************************
     * For general use
     *********************************/
    
    // Anonymize a form instance by cloning it (to replace Owner and CreatedBy fields) and clearing the lookup fields.
    // Attach the new form instance to the given applicant.
    // Also clone the form data records and clear their lookup fields.  
    // Finally, delete original form instance, form data records, and form log entries.  (The new form instance has no form log entries.)
    public static void anonymize(Id formInstanceId, Id applicantId) {
        system.debug('anonymize: formInstanceId = ' +formInstanceId+ '; applicantId = ' +applicantId);
        // Use current user as owner for the cloned form data
        Id currentUserId = UserInfo.getUserId();
        // Grab "Is First Grant" field from linked proposal to check that form data is correct, as we've been getting ambiguous dupe form data (rt 9/27/21).
        String[] relFIFields = new List<String> {'Proposal__r.Is_first_grant__c'};
        Form_Instance__c fi = (Form_Instance__c)Utilities.fetchRecord('Form_Instance__c', formInstanceId, relFIFields);
        Boolean isFirstGrant = fi.Proposal__r.Is_first_grant__c;
        String[] relFDFields = new List<String> {'Form_Component__r.Prefill_object_name__c', 'Form_Component__r.Prefill_field_name__c'};
        Form_Data__c[] fds = (Form_Data__c[])Utilities.fetchChildRecords('Form_Data__c', fi.Id, 'Form_Instance__c', relFDFields);
        Form_Log_Entry__c[] fles = [SELECT Id FROM Form_Log_Entry__c WHERE Form_Instance__c = : fi.Id];
        if (fles.size() == 0) return; // Bail if no form log entries, that is, form instance is already anonymized.
        sObject[] toInsert = new List<sObject> (); 
        sObject[] toDelete = new List<sObject> (); 
        // Clone form instance, clear lookup fields, set applicant, form and owner links.
        Form_Instance__c fiNew = fi.clone(false, true);
        for (String fName : Utilities.relFieldNamesForObject('Form_Instance__c')) fiNew.put(fName, null);
        fiNew.Applicant__c = applicantId; 
        fiNew.Form__c = fi.Form__c;
        fiNew.OwnerId = currentUserId;
        insert fiNew;
        // Clone form data records, clear their lookup fields, then set parent applicant, form instance, form component, and owner.
        String[] formDataRelFieldNames = Utilities.relFieldNamesForObject('Form_Data__c');
        for (Form_Data__c fd : fds) {
            if (fd.Form_Component__r.Prefill_object_name__c == 'Proposal__c' && 
                fd.Form_Component__r.Prefill_field_name__c == 'Is_first_grant__c' && 
                isFirstGrant != (fd.Data_text__c != null ? Boolean.valueOf(fd.Data_text__c) : false)
            ) {
                fd.Data_textarea__c = 'This form data has the wrong value. It should be: ' +isFirstGrant;
            }
            Form_Data__c fdNew = fd.clone(false, true);
            for (String fName : formDataRelFieldNames) fdNew.put(fName, null);
            fdNew.Applicant__c = applicantId; 
            fdNew.Form_Instance__c = fiNew.Id;
            fdNew.Form_Component__c = fd.Form_Component__c;
            fdNew.OwnerId = currentUserId;
            toInsert.add(fdNew);
        }
        if (toInsert.size() > 0) insert toInsert;
        // Delete the original form instance and child records.
        toDelete.add(fi);
        toDelete.addAll((sObject[])fds);
        toDelete.addAll((sObject[])fles);
        delete toDelete;
        return;
    }
    
    // Delete unsubmitted form instances for anonymizing forms if they've been expired for at least a week (to avoid mishaps at online apps).
    public static void deleteExpiredAnonymizingFormInstances () {
        Integer offsetFromExpirationDate = 7; // Delete if we're more than this number of days from expiration date.
        Integer deleteBatchSize = Test.isRunningTest() ? 3 : 1; // Batch size at least 3 for testing (one each of form instance, form data, form log entry).
        Date today = Date.today();
        Form_Instance__c[] fis = [
            SELECT Id, Expiration_date__c
            FROM Form_Instance__c
            WHERE Date_submitted__c = null
            AND Form__r.Anonymous_applicant__c <> null
            AND Expiration_date__c <> null
        ];
        Map<Id, Form_Instance__c> fisToDelete = new Map<Id, Form_Instance__c> ();
        for (Form_Instance__c fi : fis) { // Gather the form instances that expired a while ago.
            if (fi.Expiration_date__c.addDays(offsetFromExpirationDate) < today) fisToDelete.put(fi.Id, fi);
        }
        if (fisToDelete.size() > 0) {
            // Delete the form instances and child records.
            Form_Data__c[] fds = [SELECT Id FROM Form_Data__c WHERE Form_Instance__c IN : fisToDelete.keySet()];
            Form_Log_Entry__c[] fles = [SELECT Id FROM Form_Log_Entry__c WHERE Form_Instance__c IN : fisToDelete.keySet()];
            sObject[] toDelete = new List<sObject> (); 
            toDelete.addAll((sObject[])fisToDelete.values());
            toDelete.addAll((sObject[])fds);
            toDelete.addAll((sObject[])fles);
            Database.executeBatch(new DeleteRecordsBatch(toDelete, true), deleteBatchSize);
        }
        return;
    } 
    
    // Clone the form instance, clearing Date Submitted, Date form closed, Number of errors. 
    public static Form_Instance__c formInstanceClone(Id formInstanceId) {
        Form_Instance__c fi = getFormInstanceAllFields(formInstanceId);
        Form_Instance__c fiNew = fi.clone(false, true);
        // Clear Date Submitted to push status back to Pending, and insert new form instance.
        fiNew.Date_submitted__c = null;
        fiNew.Date_form_closed__c = null;
        fiNew.Number_of_errors__c = null;
        if(fiNew != null) insert fiNew;
        return fiNew;            
    }

    // Clone all of the first form instance's linked form data records except those with components for which NoFormDataClone is checked.
    // Link them to the new form instance, and use that form instance's profile and proposal Ids.
    public static List<Form_Data__c> formDataClone(Id fiId, Id fiNewId) {
        Form_Instance__c fi = getFormInstanceAllFields(fiId);
        Form_Instance__c fiNew = getFormInstanceAllFields(fiNewId);
    	// If the form instances are for different forms, then build a map to assign the Form_Component lookup fields in the cloned form data.
        Map<Id, Id> formCompsMap;
        if (fi.Form__c != fiNew.Form__c) formCompsMap = buildFormComponentMap(fi.Form__c, fiNew.Form__c);
        List<Form_Data__c> fds = getFormDataForFormInstanceAllFields(fiId);
        List<Form_Data__c> fdsNew = new List<Form_Data__c> ();
        // Clone form data records unless form data's component has NoFormDataClone checked.
        for (Form_Data__c fd : fds) {
            if(!fd.Form_Component__r.NoFormDataClone__c) {
                Form_Data__c fdNew = fd.clone(false, true);
                fdNew.Form_Instance__c = fiNew.Id; // Wire up to new form instance.
                fdNew.Profile__c = fiNew.Profile__c;
                fdNew.Proposal__c = fiNew.Proposal__c;
                if (formCompsMap != null) { // Rewire the form component link if there's an id mapping.
                    Id formCompId = formCompsMap.get(fd.Form_Component__c);
                    if (formCompId != null) { // Don't add this clone unless the form comp id mapping succeeded.
                        fdNew.Form_Component__c = formCompId;
                        fdsNew.add(fdNew);
                    }
                } else fdsNew.add(fdNew);
            }
        }
        if(fdsNew.size() > 0) {
            // If not under batch/future, then do inserts as batch process to keep triggered processes/flows out of current transaction.
        	if (!System.isBatch() && !System.isFuture()) Database.executeBatch(new GenericInsertRecordsBatch (fdsNew), 5);
            else insert fdsNew;
            // Fill in the back pointer to the form instance that is the source of cloned form data.
            if (fiNew.Pre_populated_from__c != fi.Id) {
                system.debug('formDataClone, setting Pre_populated_from__c: fi.Id = ' +fi.Id);
                fiNew.Pre_populated_from__c = fi.Id;
                update fiNew;
            }
        }
        return fdsNew;            
    }
    
    // Relink the form instances and their form data records to a new applicant. 
    // Normally used when merging applicant records. 
    public static void formInstanceRelinkApplicant(List<Id> formInstanceIds, Id applicantId) {
        Form_Instance__c[] fis = [SELECT Id FROM Form_Instance__c WHERE Id IN : formInstanceIds];
        Form_Data__c[] fds = [SELECT Id FROM Form_Data__c WHERE Form_Instance__c IN : formInstanceIds];
        for (Form_Data__c fd : fds) fd.Applicant__c = applicantId;
        Form_Log_Entry__c[] fles = [SELECT Id FROM Form_Log_Entry__c WHERE Form_Instance__c IN : formInstanceIds];
        for (Form_Log_Entry__c fle : fles) fle.Applicant__c = applicantId;
        // Relink the parent form instances.
        for (Form_Instance__c fi : fis) fi.Applicant__c = applicantId;
        // Batch update the form data and form log entries and then update the parent form instances from the batch's finish method.
        // First combine form data and form log entries into one list.
        SObject[] toUpdate = new List<SObject> ();
        toUpdate.addAll((List<SObject>) fds);
        toUpdate.addAll((List<SObject>) fles);
        if (toUpdate.size() > 0) Database.executeBatch(new GenericUpdateRecordsBatch(toUpdate, fis, 10), 50);
    }

    // Move the form instances and their form data records to a new form using the form components map. 
    // Normally used to move all pending (non-submitted) form instances of an outdated form to a new form. 
    public static void formInstanceMove(List<Id> formInstanceIds, Id formId, Map<Id, Id> formCompsMap) {
        Form_Instance__c[] fis = [SELECT Id FROM Form_Instance__c WHERE Id IN : formInstanceIds];
        Form_Data__c[] fds = [SELECT Form_Component__c FROM Form_Data__c WHERE Form_Instance__c IN : formInstanceIds];
        List<Form_Data__c> fdsToUpdate = new List<Form_Data__c> ();
        List<Form_Data__c> fdsToDelete = new List<Form_Data__c> ();
        for (Form_Data__c fd : fds) {
            // Rewire the form component link if there's a match in the target form, else delete the form data record.
            Id formCompId = formCompsMap.get(fd.Form_Component__c);
            if (formCompId != null) {
                fd.Form_Component__c = formCompId;
                fdsToUpdate.add(fd);
            } else fdsToDelete.add(fd);
        }
        // Relink the parent form instances.
        for (Form_Instance__c fi : fis) fi.Form__c = formId;
        // Batch delete the form datas that need deleting.
        Database.executeBatch(new DeleteRecordsBatch(fdsToDelete, false), 100);
        // Batch update the form data and then update the parent form instances from the batch's finish method.
        if (fis.size() > 0) Database.executeBatch(new GenericUpdateRecordsBatch(fdsToUpdate, fis, 10), 50);
    }

    // Return a mapping of component ids in the first form to matching component ids in the second form.
    public static Map<Id, Id> buildFormComponentMap (Id formAId, Id formBId) {
        Map<Id, Form_Component__c> compsA = new Map<Id, Form_Component__c> ([
            SELECT Id, Name
            FROM Form_Component__c
            WHERE Form_Item__r.Form_Section__r.Form__c = : formAId
        ]);
        Map<Id, Form_Component__c> compsB = new Map<Id, Form_Component__c> ([
            SELECT Id, Name
            FROM Form_Component__c
            WHERE Form_Item__r.Form_Section__r.Form__c = : formBId
        ]);
        Map<String, Id> compNamesMapB = new Map<String, Id> ();
        for (Form_Component__c c : compsB.values()) compNamesMapB.put(c.Name, c.Id);
        Map<Id, Id> resultMap = new Map<Id, Id>();
        for (Form_Component__c c : compsA.values()) resultMap.put(c.Id, compNamesMapB.get(c.Name));
        return resultMap;
    }

    // See if the form instance identifies another fi as "pre-populuated from".
    // If so, do a diff of the form data under each fi and enter the results in the current fi.
    public static String computeDiffResults (Id fiId) {
        String result;
        Form_Instance__c fi = getFormInstanceAllFields(fiId);
        if (fi.Pre_populated_from__c != null) {
            Set<String> diffResults = formDataDiff(fi.Pre_populated_from__c, fiId);
            result = diffResults.size() > 0 ? String.join(new List<String>(diffResults), '; ') : null;
            if (fi.Diff_results__c != result) {
                fi.Diff_results__c = result;
                update fi;
            }
        }
        return result;
    }
    
    // Compare the form data under the two form instances.
    // Return a set of component names whose values differ.
    // NOTE: Assumes that current FI has form data records for a superset of the components of the prior FI.
    // NOTE: indexed data currently not being handled.  Should check whether index matches, etc.
    public static Set<String> formDataDiff(Id priorFIId, Id currentFIId) {
        Set<String> result = new Set<String>();
        Form_Data__c[] fdsPrior = getFormDataForFormInstance(priorFIId), 
            fdsCurr = getFormDataForFormInstance(currentFIId);
        // Map of prior form data by component id.
        Map<String, Form_Data__c> fdsPriorByCompName = new Map<String, Form_Data__c> ();
        for (Form_Data__c fd : fdsPrior) fdsPriorByCompName.put(fd.Form_Component__r.Name, fd);
        // Gather components whose prior values don't match the current ones.
        for (Form_Data__c fd : fdsCurr) {
            Form_Data__c fdPrior = fdsPriorByCompName.get(fd.Form_Component__r.Name);
            if (
                fdPrior == null ||
                (fdPrior.Data_text__c != null ? fdPrior.Data_text__c.trim() : null) != 
                (fd.Data_text__c != null ? fd.Data_text__c.trim() : null) ||
                (fdPrior.Data_textarea__c != null ? fdPrior.Data_textarea__c.trim() : null) != 
                (fd.Data_textarea__c != null ? fd.Data_textarea__c.trim() : null)
            ) result.add(fd.Form_Component__r.Name);
        }
        return result;
    }
    
    // Re-open a submitted form instance, that is, clear Date Submitted and delete certain flagged form data records.
    public static void reOpen(Id fiId) {
        Form_Instance__c fi = [SELECT Id, Date_submitted__c FROM Form_Instance__c WHERE Id = : fiId];
        // Do nothing if not submitted.
        if (fi.Date_submitted__c != null) {
            // Find linked form data records whose form components are suitably flagged.
            Form_Data__c[] fdsToDelete = [
                SELECT Id
                FROM Form_Data__c
                WHERE Form_Instance__c = : fiId
                AND Form_Component__r.Clear_on_re_open__c = true
            ];
            fi.Date_submitted__c = null;
            update fi;
            if (fdsToDelete.size() > 0) delete fdsToDelete;
        }
    }

    // Send email reminders/overdue notices for non-submitted form instances as directed by the form record.
    public static void emailRemindersOverdues (Boolean testApplicantsOnlyFlg) {
        // The names of objects whose reminder/overdue templates are currently supported.
        // In each case, the obj name is also the name of the lookup field in Form Instance.
        List<String> supportedObjNames = new List<String> {
            'Proposal__c', 'Grantee_Report__c', 'Payment__c', 'Payment_Method__c', 'Profile__c',
            'Advisor__c', 'Advisor_Term__c', 'Advisor_Payment__c', 'Endorsement__c', 'Assessment__c'
        };
        // Fetch non-submitted form instances with date due and a linked form with instructions for when to send reminders/overdues.
        Map<Id, Form_Instance__c> fis = new Map<Id, Form_Instance__c> ([
            SELECT Id, Date_due__c, Date_submitted__c, Applicant__r.Name,
            Proposal__c, Grantee_Report__c, Payment__c, Profile__c,
            Profile__r.Account_black_listed__c, Proposal__r.Account_black_listed__c,
            Proposal__r.Status_numeric__c, Profile__r.Status_numeric__c,
            Grantee_Report__r.Reminder_overdue_number_of_days__c,
            Form__r.Name, Form__r.Reminder_overdue_number_of_days__c,
            Form__r.Reminder_template__c, Form__r.Overdue_template__c,
            (SELECT Id FROM Payment_Methods__r ORDER BY CreatedDate)
            FROM Form_Instance__c
            WHERE Date_due__c <> null
            AND Date_submitted__c = null
            AND Status__c = 'Pending'
            AND Date_auto_reminders_paused__c = null
            AND Form__r.Reminder_overdue_number_of_days__c <> null
            AND Profile__r.Account_black_listed__c <> true
            AND Proposal__r.Account_black_listed__c <> true
        ]);
        Map<Id, Template__c> tmpls = new Map<Id, Template__c> ([
            SELECT Id, Name, Active__c, Source_object__c, Allowed_statuses__c
            FROM Template__c
            ]);
        // Mapping of object name to template id to ids of form instances that need reminder/overdue emails.
        Map<String, Map<Id, Set<Id>>> recIds = new Map<String, Map<Id, Set<Id>>> ();
        // Walk through form instances to find proposals that require reminders/overdue notices.
        for (Form_Instance__c fi : fis.values()) {
            // If in test mode, bail unless form instance's parent is a DONOTUSE applicant.
            if (testApplicantsOnlyFlg && !fi.Applicant__r.Name.toLowerCase().contains('donotuse')) continue;
            Id tmplId = reminderOverdueTemplateId(fi);
            Template__c tmpl = tmplId != null ? tmpls.get(tmplId) : null;
            system.debug('emailRemindersOverdues in loop: fi = ' +JSON.serialize(fi)+ '; tmplId = ' +tmplId);
            if (tmpl != null) { 
                // Skip if the template's source object is not supported for auto-reminders/overdues.
                String objName = tmpl.Source_object__c;
                if (!supportedObjNames.contains(objName)) continue;
                // Compute id of record to which reminder letter will link.
                Id recId;
                if (objName == 'Payment_Method__c') { // Grab oldest child payment method
                    recId = fi.Payment_Methods__r.size() > 0 ? fi.Payment_Methods__r[0].Id : null;
                } else { // Use form instance's lookup field with same name as source object
                    recId = (Id)fi.get(objName);
                }
                // This form instance gets a reminder/overdue letter if the record's status is allowed by the template, and the template is active.
                if (recId != null && statusAllowed(fi, tmpl) && tmpl.Active__c) {
                    if (!recIds.containsKey(objName)) recIds.put(objName, new Map<Id, Set<Id>>());
                    if (!recIds.get(objName).containsKey(tmpl.Id)) recIds.get(objName).put(tmpl.Id, new Set<Id>());
                    recIds.get(objName).get(tmpl.Id).add(recId);
                }
            }
        }
        system.debug('emailRemindersOverdues: recIds = ' +JSON.serialize(recIds));
        // Walk through the gathered sets of record ids and build and email letter records.
        for (String objName : recIds.keySet()) {
            for (Id tmplId : recIds.get(objName).keySet()) {
                Set<Id> ids = recIds.get(objName).get(tmplId);
                Map < String, String > customParams = new Map < String, String >{'isEmail'=>'true','autoGeneratedEmail'=>'true'};
                LetterController.buildAndEmailLetters(tmplId, ids, customParams);
            }
        }
    }

    // True if the status referred to by the form instance is allowed by the template.
    public static Boolean statusAllowed (Form_Instance__c fi, Template__c t) {
        String objName = t.Source_object__c;
        // Maintain this related object name definition as more objects related to Form Instance  are supported.
        String statusRelObjName = objName == 'Profile__c' ? 'Profile__r' : 'Proposal__r';
        String statusFieldName = 'Status_numeric__c';
        Decimal statusNumeric = (Decimal)fi.getSobject(statusRelObjName).get(statusFieldName);
        Set<Decimal> allowedStatuses = Utilities.commaSepStringToDecimalSet(t.Allowed_statuses__c);
        return allowedStatuses == null || statusNumeric == null || allowedStatuses.contains(statusNumeric.stripTrailingZeros());
    }
    
    // Return non-null template id if the given form instance needs a reminder/overdue email.
    public static Id reminderOverdueTemplateId (Form_Instance__c fi) {
        // Compute number of days overdue (negative if not overdue). 
        Integer numDays = fi.Date_due__c.daysBetween(Date.today());
        // Look for that number of days in the comma-separated string of numbers in the form (or overridden by the grantee report record).
        // NOTE (9/22/17): Do we also need an override field in the proposal record?
        String numsStr = fi.Grantee_Report__r.Reminder_overdue_number_of_days__c != null ?
            fi.Grantee_Report__r.Reminder_overdue_number_of_days__c : 
        	fi.Form__r.Reminder_overdue_number_of_days__c;
        system.debug('reminderOverdueTemplateId: numDays = ' +numDays+ '; numsStr = ' +numsStr);
        // Each string comprising numsStr should be a positive number, a negative number, or a positive number with a '+' at the end, called a repeater.
        // If numDays equals one of the negative numbers, then send an overdue letter.
        // If numDays equals one of the positive numbers, then send a reminder letter.
        // Finally, send a reminder if there's a repeater such that numDays minus the last non-negative number before the repeater (or zero if none) is a multiple of the repeater.
        Integer lastNonNegative = 0;
        for (String numStr : numsStr.split(',')) {
            String numStrTrim = numStr.trim();
            Integer num = Utilities.isInteger(numStrTrim) ? Integer.valueOf(numStrTrim) : null;
            if (num != null && num > 0) lastNonNegative = num; 
            Integer numRepeater = numStrTrim.right(1) == '+' && Utilities.isInteger(numStrTrim.left(numStrTrim.length()-1)) ?
                    Integer.valueOf(numStrTrim.left(numStrTrim.length()-1)) : null;
            if ((num != null && numDays == num) ||
                (numRepeater != null && numRepeater > 0 && numDays > 0 && Math.mod(numDays-lastNonNegative, numRepeater) == 0))
                return numDays <= 0 ? fi.Form__r.Reminder_template__c : fi.Form__r.Overdue_template__c;
        }
        return null;
    }
    
    // Withdraw props of inactive, unsubmitted, blank date-due form instances if their forms have non-blank inactivity threshold.
    public static void withdrawPropsWithInactiveFormInstances () {
        // Fetch candidate form instances, including most recent "Save" form log entries.
        Form_Instance__c[] fis = [
            SELECT Proposal__c, CreatedDate, Proposal__r.Date_request_withdrawn__c, Form__r.Inactivity_threshold_in_days__c,
            (SELECT Id, CreatedDate FROM Form_Log_Entries__r WHERE Operation__c = 'Save' ORDER BY CreatedDate DESC)
            FROM Form_Instance__c
            WHERE Date_submitted__c = null
            AND Date_due__c = null
            AND Proposal__c <> null
            AND Proposal__r.Status_numeric__c >= 1
            AND Proposal__r.Status_numeric__c < 6
            AND Form__r.Inactivity_threshold_in_days__c <> null
        ];
        system.debug('withdrawPropsWithInactiveFormInstances: fis = ' +JSON.serialize(fis));
        Map<Id, Proposal__c> propsToUpdate = new Map<Id, Proposal__c> ();
        Date today = Date.today();
        for (Form_Instance__c fi : fis) {
            // Compute the last date this form instance was saved (or created if it's never been saved).
            Date lastSaved = fi.Form_Log_Entries__r.size() > 0 ? fi.Form_Log_Entries__r[0].CreatedDate.date() : fi.CreatedDate.date();
            // Withdraw proposal if over threshold of inactivity.
            if (lastSaved == null || lastSaved.daysBetween(today) > fi.Form__r.Inactivity_threshold_in_days__c) {
                Proposal__c prop = fi.Proposal__r;
                prop.Date_request_withdrawn__c = today;
                prop.Request_withdrawn_reason__c = 'AUTOMATED: Lack of online form activity';
                propsToUpdate.put(prop.Id, prop);
            }
        }
        // Update via batch process.
        system.debug('withdrawPropsWithInactiveFormInstances: propsToUpdate = ' +JSON.serialize(propsToUpdate));
        if (propsToUpdate.size() > 0) Database.executeBatch(new GenericUpdateRecordsBatch(propsToUpdate.values()), 1);
    }

     /**********************************
     * For use in Apex code processing form data
     *********************************/
    
    // Class that includes all form data associated with the given form instance
    public class DataManager {
        public Form_Instance__c fi;
        public Applicant__c appl;
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
            this.fi = getFormInstanceAllFields(fiId);
            // Get applicant or advisor term.
            system.debug('DataManager: fi.Applicant__c = ' +fi.Applicant__c+ '; fi.Advisor_Term__c = ' +fi.Advisor_Term__c);
            if (fi.Applicant__c != null) {
                appl = [
                    SELECT Id, Account__c, Contact_email__c, Language__c
                    FROM Applicant__c 
                    WHERE Id = : fi.Applicant__c
                ];
            } else if (fi.Advisor_Term__c != null) {
                advt = [
                    SELECT Id, Advisor__c, Advisor__r.Community_contact_email__c, Advisor__r.Language__c
                    FROM Advisor_Term__c 
                    WHERE Id = : fi.Advisor_Term__c
                ];
            }
            comps = getComponentsForForm(fi.Form__c);
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
            fds = getFormDataForFormInstance(fi.Id);
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
       
    public String formInstanceText { get; private set; } // Form instance text

    // Build text for selected form instance.
    public PageReference buildText() {
        // Grab selected form instance id(s). 
        // Currently (5/1/20) only handles a single selected form instance.
        Id selId = (new List<Id> (getSelectedIds()))[0];
        formInstanceText = renderFormInstanceText(selId);
        return null;
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