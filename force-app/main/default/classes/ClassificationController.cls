public class ClassificationController {

    public static Map<string, string> objNameToAssignObjName = new Map<string, string> {
        'Proposal__c' => 'Classification_Assign__c',
        'Profile__c' => 'Classification_Profile_Assign__c'
    };
    
    // Update the classification assigns for an appropriate record (say, Profile or Proposal).
    // Create/delete joins to align with given selected classification ids.
    // Two shapes depending on whether we're called with classification names or ids.
    // Note that if classIds list is empty, the current classification assignments for the record are deleted.
    public static void updateClassificationAssigns (Id recId, String classType, String[] classNames) {
        Map<Id, Classification__c> cMap = new Map<Id, Classification__c> ([
            SELECT Name, Name_with_prefix__c
            FROM Classification__c
            WHERE Type__c = : classType
            AND Active__c = true
            AND (Name IN : classNames OR Name_with_prefix__c IN :classNames)
        ]);
        updateClassificationAssigns (recId, classType, new List<Id>(cMap.keySet()));
    }
    public static void updateClassificationAssigns (Id recId, String classType, Id[] classIds) {
        String objName = Utilities.objectNameFromRecordId(recId);
        String assignObjName = objNameToAssignObjName.get(objName);
        // Bail if record's object doesn't have classification assign join object.
        if (assignObjName == null) return;
        sObject[] toDelete = new List<sObject>();
        sObject[] toInsert = new List<sObject>();
        system.debug('updateClassificationAssigns: recId = ' +recId+ '; classType = ' +classType+ '; classIds = ' +classIds);
        // Get current assignments. Note that master/detail field is assumed to have same name as object. 
        String whereClause = 'WHERE ' +objName+ ' = \'' +recId+ '\'' +
            ' AND Classification__r.Type__c = \'' +classType+ '\'' +
            ' AND Classification__r.Active__c = true';
        Map<Id, sObject> cAssigns = new Map<Id, sObject> (Utilities.fetchRecords(assignObjName, whereClause, null));
        system.debug('In updateClassificationAssigns: cAssigns = ' + JSON.serialize(cAssigns));
        // Stash current classification ids.
        Set<Id> currClassIds = new Set<Id>();
        for (sObject ca : cAssigns.values()) currClassIds.add((Id)ca.get('Classification__c'));
        // Augment list of classifications to delete - they were assigned, but are no longer selected.
        for (sObject ca : cAssigns.values()) {
            if (!classIds.contains((Id)ca.get('Classification__c'))) toDelete.add(ca);
        }
        system.debug('In updateClassificationAssigns: toDelete = ' + JSON.serialize(toDelete));
        // Augment list of classifications to insert - they weren't originally assigned, but are now selected.
        for (Id cId : classIds) {
            if (!currClassIds.contains(cId)) {
                sObject cAssign = Utilities.newRecord(assignObjName);
                cAssign.put('Classification__c', cId);
                cAssign.put(objName, recId);
                toInsert.add(cAssign); 
            }
        }
        system.debug('In updateClassificationAssigns: toInsert = ' + JSON.serialize(toInsert));
        if (toDelete.size() > 0) delete toDelete;
        if (toInsert.size() > 0) insert toInsert;
    }
}