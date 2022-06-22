public class FormDataController {
    
    // Update target fields (where necessary) of form data in given form instance.
    public static void updateTargetFields (Id formInstanceId) {
        Map<Id, sObject> toUpdate = new Map<Id, sObject> (); // Records with updated fields needing DML update.
        sObject[] toInsert = new List<sObject>();
        sObject[] toDelete = new List<sObject>();
        // Fetch form instance and its non-disabled form data.
        Form_Instance__c fi = [
            SELECT Id, Name, Profile__c, Proposal__c, Milestone__c, Assessment__c, OwnerId,
            (SELECT Data_text__c, Data_textarea__c, Disabled__c,
             Form_Component__c, Form_Component__r.Name, Form_Component__r.Type__c, Form_Component__r.Indicator__c, 
             Form_Component__r.Target_field_name__c, Form_Component__r.Target_object_name__c,
             Form_Component__r.Form_Picklist__r.Name, Form_Component__r.Form_Picklist__r.Type__c
             FROM Form_Data__r
             WHERE Disabled__c = false
            )
            FROM Form_Instance__c
            WHERE Id = : formInstanceId
        ];
        String fsGroupName = Utilities.fsGroupNameByUser(fi.OwnerId);
        Form_Data__c[] fds = fi.Form_Data__r;
        Id profId = fi.Profile__c;
        Id propId = fi.Proposal__c;
        Id milestoneId = fi.Milestone__c;
        Id assessId = fi.Assessment__c;
        // Find the relevant GM Data id (if any).
        Id gmDataId;
        GM_Data__c gmData;
        if (milestoneId != null) {
            Milestone__c milestone = [
                SELECT GM_Data__c 
                FROM Milestone__c 
                WHERE Id = : milestoneId
                ];
            // Look for a GM Data linked FROM the grantee report
            if (milestone != null && milestone.GM_Data__c != null) {
                gmDataId = milestone.GM_Data__c;
            }
        } else if (propId != null) {
            Proposal__c p = [
                SELECT GM_Data__c 
                FROM Proposal__c 
                WHERE Id = : propId
                ];
            // Plan A: Look for a GM Data linked FROM the proposal
            if (p != null && p.GM_Data__c != null) {
                gmDataId = p.GM_Data__c;
            } else {
                // Plan B: Look for gm data linked TO the proposal
                GM_Data__c[] gmDatas = [SELECT Id FROM GM_Data__c WHERE Proposal__c = : propId];
                if (gmDatas.size() > 0) gmDataId = gmDatas[0].Id;
            }
        }
        if (gmDataId != null) gmData = (GM_Data__c) Utilities.fetchRecord('GM_Data__c', gmDataId, null);
        // Get the indicator assigns of that gm data record.
        Indicator_Assign__c[] indAssigns = [
            SELECT Id, Comment__c, Quantity__c, Indicator__r.Name
            FROM Indicator_Assign__c
            WHERE GM_Data__c = : gmDataId
        ];
        // Mapping from indicator Id to indicator assign record
        Map<Id, Indicator_Assign__c> indAssignMap = new Map<Id, Indicator_Assign__c>();
        for (Indicator_Assign__c ia : indAssigns) indAssignMap.put(ia.Indicator__c, ia);
        // Get all the indicators and build indicator map and initialize gmdata checkbox field map entries to false. 
        Map<Id, Indicator__c> indMap = new Map<Id, Indicator__c>([
            SELECT Name, GM_Data_field_name__c 
            FROM Indicator__c 
            WHERE Active__c = true
            ]);
        Map<String, Boolean> checkboxesAssigned = new Map<String, Boolean> ();
        for (Indicator__c i : indMap.Values()) {
            checkboxesAssigned.put(i.GM_Data_field_name__c, false);
        }
        // Track which gmdata checkbox fields appear in the indicator form data 
        Set<String> checkboxFieldNames = new Set<String>();
        // Map object names to record Id, record and to field map.
        Map<String, Id> objNameToRecordId = new Map<String, Id> ();
        Map<String, sObject> objNameToRecord = new Map<String, sObject> ();
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map<String, Map<String, Schema.SObjectField>> objNameToFieldMap = new Map<String, Map<String, Schema.SObjectField>> ();
        // Step through obj names populating maps.
        String[] objNames = new List<String> {
            'Profile__c', 'Proposal__c', 
            'Milestone__c', 
            'GM_Data__c', 'Assessment__c'
        };
            for (String oName : objNames) {
                Id recId = oName == 'GM_Data__c' ? gmDataId : (Id)fi.get(oName);
                objNameToRecordId.put(oName, recId);
                objNameToRecord.put(oName, Utilities.fetchRecord(oName, recId, null));
                objNameToFieldMap.put(oName, schemaMap.get(oName).getDescribe().fields.getMap());
            }
        // Step through form data, building up the mappings as we go, and updating target fields.
        for (Form_Data__c fd : fds) {
            String fdText = fd.Data_text__c;
            String fdTextArea = fd.Data_textarea__c;
            // This loop only processes targeted form data. 
            if (fd.Form_Component__r.Target_object_name__c != null) {
                // Special handling for indicator form data massages the GM Data's indicator assigns
                if (fd.Form_Component__r.Type__c == 'indicator') {
                    String indId = fd.Form_Component__r.Indicator__c;
                    Indicator_Assign__c ia = indAssignMap.containsKey(indId) ? indAssignMap.get(indId) : null;
                    Indicator__c ind = indMap.containsKey(indId) ? indMap.get(indId) : null;
                    system.debug('updateTargetFields in loop: indId = ' +indId+ '; ind = ' +JSON.serialize(ind)+ '; ia = ' +JSON.serialize(ia));
                    if (ind != null && ind.GM_Data_field_name__c != null) checkboxFieldNames.add(ind.GM_Data_field_name__c);
                    Integer quantity = fdText != null && fdText.isNumeric() ? Integer.valueOf(fdText) : null;
                    String comment = fdTextArea;                    
                    if (quantity == null && comment == null) {
                        // fd is empty, so remove matching indicator assign, if any
                        if (ia != null) toDelete.add(ia);
                    } else { // indicator has data
                        // If indicator is active, note that the appropriate gmdata checkbox field should be checked
                        if (ind != null) checkboxesAssigned.put(ind.GM_Data_field_name__c, true);
                        // Existing indicator assign needs updating?
                        if (ia != null && (ia.Quantity__c != quantity || ia.Comment__c != comment)) {
                            // fd values are different so update the indicator assign
                            ia.Quantity__c = quantity;
                            ia.Comment__c = comment;
                            toUpdate.put(ia.Id, ia);
                        } // If indicator is active and there's no existing assign, build a new one
                        if (ind != null && ia == null) {
                            toInsert.add(new Indicator_Assign__c (
                                Indicator__c = ind.Id,
                                GM_Data__c = gmDataId,
                                Quantity__c = quantity,
                                Comment__c = comment
                            ));
                        }
                    }
                    continue;
                } else if (fd.Form_Component__r.Target_field_name__c != null) { // Non-indicator targeted form components must have target field
                    String oName = fd.Form_Component__r.Target_object_name__c;
                    sObject target = objNameToRecord.get(oName);
                    String fName = fd.Form_Component__r.Target_field_name__c;
                    Map<String, Schema.SObjectField> fieldMap = objNameToFieldMap.get(oName);
                    if (target != null && fieldMap.get(fName) != null) {
                        Schema.DescribeFieldResult fInfo = fieldMap.get(fName).getDescribe();
                        String fType = fInfo.getType().name();
                        system.debug('updateTargetFields in loop: fType = ' +fType+ '; fName = ' +fName+ '; target = ' +JSON.serialize(target));
                        // Now set the field dynamically in the target record if different from what's there.
                        if (fType.toLowerCase() == 'boolean')
                            updateFieldIfValueChanged(target, fName, fdText != null && fdText.contains('Yes') ? true : false, toUpdate);
                        else if (fType.toLowerCase() == 'integer') 
                            updateFieldIfValueChanged(target, fName, fdText != null ? Integer.valueOf(fdText) : null, toUpdate);
                        else if (fType.toLowerCase() == 'double' || fType.toLowerCase() == 'currency') 
                            updateFieldIfValueChanged(target, fName, fdText != null ? Decimal.valueOf(fdText) : null, toUpdate);
                        else if (fType.toLowerCase() == 'textarea') 
                            updateFieldIfValueChanged(target, fName, fdTextArea != null ? fdTextArea : fdText, toUpdate);
                        else if (fd.Form_Component__r.Form_Picklist__r.Type__c == 'Countries') {
                            // Special handling for countries picklist - look up id of selected country.
                            system.debug('updateTargetField, countries picklist: fdText = ' +fdText);
                            Country__c c = [SELECT Id FROM Country__c WHERE Name = : fdText AND Region__r.FS_Group__c = :fsGroupName LIMIT 1];
                            updateFieldIfValueChanged(target, fName, c != null ? c.Id : null, toUpdate);
                        }
                        else updateFieldIfValueChanged(target, fName, 
                                                    fdText != null ? fdText : 
                                                    fdTextArea != null ? fdTextArea.left(255) :
                                                    null, toUpdate);
                    }
                }
            }
            // Handle form data that require specialized updates (the form component doesn't specify target object/field).
            else if (fd.Form_Component__r.Name == 'Populations' && profId != null) {
                // 6/6/19: Use invocable class for now to insert/delete joins.  Once processes/flows aren't calling that invocable, then move code into ProfileController.
                ProfileClassificationsInvocable.UpdateClassificationsRequest req = new ProfileClassificationsInvocable.UpdateClassificationsRequest ();
                req.categoryName = 'Age and Gender';
                req.classificationType = 'Population';
                req.profileId = profId;
                req.selectedNames = fdText == null ? '||' : fdText; // Invocable process doesn't like null parameters.
                ProfileClassificationsInvocable.handleRequest(req);                
            }
        }
        // Update checkbox fields in the gm data record.
        //system.debug('updateTargetFields: indMap = ' +JSON.serialize(indMap)+ '; checkboxFieldNames = ' +JSON.serialize(checkboxFieldNames)+ '; checkboxesAssigned = ' +JSON.serialize(checkboxesAssigned));
        if (gmData != null) {
            for (String fName : new List<String> (checkboxFieldNames)) {
                Boolean checked = checkboxesAssigned.get(fName);
                if (gmData.get(fName) != checked) {
                    gmData.put(fName, checked);
                    toUpdate.put(gmDataId, gmData);
                }
            }
        }
        Integer batchSize = Test.isRunningTest() ? 5 : 1; // Batch process may only have one iteration in test mode.
        system.debug('toUpdate.size() = ' +toUpdate.size()+ '; batchSize = ' +batchSize+ '; toInsert.size() = ' +toInsert.size()+ '; toDelete.size() = ' +toDelete.size());
        if(toUpdate.size() > 0) {
            if (System.isBatch() || Test.isRunningTest()) update toUpdate.values(); // Can't invoke batch from within a batch.
            else Database.executeBatch(new GenericUpdateRecordsBatch(toUpdate.values()), batchSize);
        }
        if(toInsert.size() > 0) {
            if (System.isBatch() || Test.isRunningTest()) insert toInsert; // Can't invoke batch from within a batch.
            else Database.executeBatch(new GenericInsertRecordsBatch(toInsert), batchSize);
        }
        if(toDelete.size() > 0) {
            if (System.isBatch() || Test.isRunningTest()) delete toDelete; // Can't invoke batch from within a batch.
            else Database.executeBatch(new DeleteRecordsBatch(toDelete, false), batchSize);
        }
    }
    
    // Update the field if value is different, stashing record on the toUpdate list.
    private static void updateFieldIfValueChanged (sObject record, String fieldName, Object fieldValue, Map<Id, sObject> toUpdate) {
        system.debug('updateFieldIfValueChanged checking: fieldName = ' +fieldName+ '; fieldValue = ' +fieldValue);
        if (record != null && fieldName != null && record.get(fieldName) != fieldValue) {
            system.debug('updateFieldIfValueChanged setting: fieldName = ' +fieldName+ '; old value = ' +record.get(fieldName)+ '; new value = ' +fieldValue);
            record.put(fieldName, fieldValue);
            toUpdate.put(record.Id, record);
        }
    }
    
    // Prefill form data for form components of the form instance where necessary.
    public static void prefillFormInstance (Id formInstanceId) {
        Form_Data__c[] toInsert = new List<Form_Data__c> ();
        // Fetch form instance and its pre-filling form components.
        Form_Instance__c fi = [
            SELECT Id, Name, Form__c, Profile__c, Proposal__c, Milestone__c, 
            Advisor__c, Advisor__r.Contact__c, Advisor__r.Community_Contact__c, Advisor_Term__c
            FROM Form_Instance__c
            WHERE Id = : formInstanceId
        ];
        Form_Component__c[] fcs = [
            SELECT Prefill_field_name__c, Prefill_object_name__c, Type__c
            FROM Form_Component__c
            WHERE Form__c = : fi.Form__c
            AND Prefill_object_name__c <> null
            AND Prefill_field_name__c <> null
        ];
        // Bail if no prefilling form components.
        if (fcs.size() == 0) return;
        Id profId = fi.Profile__c;
        Id propId = fi.Proposal__c;
        Id milestoneId = fi.Milestone__c;
        // Find the relevant GM Data id (if any).
        Id gmDataId;
        GM_Data__c[] gmDatas = new List<GM_Data__c> ();
        if (propId != null) gmDatas = [
            SELECT Id 
            FROM GM_Data__c 
            WHERE Proposal__c = : propId
        ];
        if (gmDatas.size() > 0) gmDataId = gmDatas[0].Id;
        system.debug('prefillFormInstance: profId = ' +profId+ '; propId = ' +propId+ '; milestoneId = ' +milestoneId+ '; gmDataId = ' +gmDataId);
        system.debug('prefillFormInstance: fcs = ' +JSON.serialize(fcs));
        
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        // Map object names to record Id, record and to field map.
        Map<String, Id> objNameToRecordId = new Map<String, Id> ();
        Map<String, sObject> objNameToRecord = new Map<String, sObject> ();
        Map<String, Map<String, Schema.SObjectField>> objNameToFieldMap = new Map<String, Map<String, Schema.SObjectField>> ();
        // Step through obj names populating maps.
        String[] objNames = new List<String> {
            'Profile__c', 'Proposal__c', 'Milestone__c', 'GM_Data__c', 
            'Advisor__c', 'Advisor_Term__c', 'Advisor__r.Contact__c', 'Advisor__r.Community_Contact__c'
        };
        for (String oName : objNames) {
            // Grab last part of obj name, removing "__c" if contact or account.
            String[] parts = oName.split('\\.');
            String oNameEndpoint = parts.get(parts.size()-1);
            if (oNameEndpoint.contains('Contact__c')) oNameEndpoint = 'Contact';
            if (oNameEndpoint.contains('Account__c')) oNameEndpoint = 'Account';
            // Compute record id and populate maps
            Id recId = oName == 'GM_Data__c' ? gmDataId : (Id)Utilities.getValue(fi, oName);
            objNameToRecordId.put(oName, recId);
            objNameToRecord.put(oName, Utilities.fetchRecord(oNameEndpoint, recId, null));
            system.debug('prefillFormInstance: objNameToRecord = ' +objNameToRecord);
            objNameToFieldMap.put(oName, schemaMap.get(oNameEndpoint).getDescribe().fields.getMap());
        }
        // Step through prefilling form components, building form data records as we go.
        for (Form_Component__c fc : fcs) {
            String fcType = fc.Type__c;
            String oName = fc.Prefill_object_name__c;
            sObject source = objNameToRecord.get(oName);
            Map<String, Schema.SObjectField> fieldMap = objNameToFieldMap.get(oName);
            String fName = fc.Prefill_field_name__c;
            system.debug('prefillFormInstance in loop: fcType = ' +fcType+ '; fName = ' +fName+ '; oName = ' +oName+ '; source = ' +JSON.serialize(source));
            if (source != null && fieldMap.get(fName) != null) {
                Schema.DescribeFieldResult fInfo = fieldMap.get(fName).getDescribe();
                String fType = fInfo.getType().name();
                Object fValue = source.get(fName);
                system.debug('prefillFormInstance in loop: fType = ' +fType+ '; fValue = ' +JSON.serialize(fValue));
                if (fValue != null) { // Skip component if its prefill field is blank.
                    // Build a form data record to prefill.
                    Form_Data__c fd = new Form_Data__c (
                        Form_Instance__c = fi.Id,
                        Form_Component__c = fc.Id,
                        Profile__c = profId,
                        Proposal__c = propId
                    );
                    toInsert.add(fd);
                    system.debug('prefillFormInstance in loop: fd = ' +fd);
                    // Set data text or data textarea field appropriately.
                    // If form component type is textarea then stash value in Data Textarea.
                    if (fcType.contains('textarea')) {
                        fd.Data_textarea__c = String.valueOf(fValue);
                        fd.Type__c = 'textarea';
                    }
                    // Data text for checkbox form components depends on whether the field referred to is Boolean.
                    else if (fcType.contains('checkbox')) {
                        fd.Data_text__c = fType.toLowerCase() == 'boolean' ? ((Boolean)fValue ? 'true' : null) : String.valueOf(fValue);
                        fd.Type__c = 'checkbox';
                    }
                    // Otherwise turn value into a string and stuff in Data text.
                    else {
                        fd.Data_text__c = String.valueOf(fValue);
                        fd.Type__c = 'text';
                    }
                    system.debug('prefillFormInstance in loop: fType = ' +fType+ '; fValue = ' +JSON.serialize(fValue)+ '; fd.Data_text__c = ' +fd.Data_text__c);
                }
            }
        }
        Integer batchSize = Test.isRunningTest() ? 5 : 1; // Batch process may only one iteration in test mode.
        system.debug('prefillFormInstance: toInsert.size() = ' +toInsert.size()+ '; batchSize = ' +batchSize);
        if(toInsert.size() > 0) {
            if (System.isBatch()) insert toInsert; // Can't invoke batch from within a batch.
            else Database.executeBatch(new GenericInsertRecordsBatch(toInsert), batchSize);
        }
    }
}