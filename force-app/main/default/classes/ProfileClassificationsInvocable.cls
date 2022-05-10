public class ProfileClassificationsInvocable {
    public class myException extends Exception {
    }

    @InvocableMethod(
        label='Update profile classifications'
        description='Update the classification join records of the given profile to align with the double-vertical bar-separated list of classification names'
    )
    public static void updateProfileClassifications(
        List<UpdateClassificationsRequest> requests
    ) {
        for (UpdateClassificationsRequest request : requests) {
            handleRequest(request);
        }
    }

    // Insert and delete joins to align selected classifications (of given category/type) with those that are assigned.
    // NOTE: We're hard-wiring classification names as well as the short names appearing in the profile form.
    public static void handleRequest(UpdateClassificationsRequest request) {
        system.debug('handleRequest: request = ' + JSON.serialize(request));
        // Mapping of short age/id names to official classification names
        Map<String, String> shortToLongName = new Map<String, String>{
            'Girls' => 'Girls',
            'Women' => 'Women',
            'Boys' => 'Boys and adolescent boys',
            'AdultMen' => 'Adult men',
            'AdolescentGirls' => 'Adolescent girls',
            'YoungWomen' => 'Young Women',
            'Trans' => 'Trans* or intersex youth or adults'
        };
        // Get all classifications of given category and type.
        List<Classification__c> cAll = new List<Classification__c>(
            [
                SELECT Id, Name
                FROM Classification__c
                WHERE
                    Classification_Category__r.Name = :request.categoryName
                    AND Type__c = :request.classificationType
            ]
        );
        // Lookup table maps classification name to id.
        Map<String, Id> lookupId = new Map<String, Id>();
        for (Classification__c c : cAll)
            lookupId.put(c.Name, c.Id);
        system.debug('handleRequest: lookupId = ' + JSON.serialize(lookupId));
        // Compute Ids corresponding to selected names.
        Set<Id> selIds = new Set<Id>();
        for (String name : request.selectedNames.split('\\|\\|')) {
            String lName = shortToLongName.get(name);
            if (lName != null && lName.length() > 0) {
                Id i = lookupId.get(lName);
                if (i != null) {
                    selIds.add(i);
                } else {
                    throw new myException(
                        'ProfileClassificationsInvocable: Classification name (' +
                        lName +
                        ') not found for given type/category (' +
                        request.classificationType +
                        '/' +
                        request.categoryName +
                        ').'
                    );
                }
            } else {
                throw new myException(
                    'ProfileClassificationsInvocable: ' +
                    'Unknown classification name in profile (' +
                    name +
                    ').'
                );
            }
        }
        // Get assigned joins of given category and type.
        Map<Id, Classification_Profile_Assign__c> cJoins = new Map<Id, Classification_Profile_Assign__c>(
            [
                SELECT Id, Classification__c
                FROM Classification_Profile_Assign__c
                WHERE
                    Profile__c = :request.profileId
                    AND Classification__r.Classification_Category__r.Name = :request.categoryName
                    AND Classification__r.Type__c = :request.classificationType
            ]
        );
        // Stash assigned classification ids.
        Set<Id> currentIds = new Set<Id>();
        for (Classification_Profile_Assign__c ca : cJoins.values())
            currentIds.add(ca.Classification__c);
        // Build list of joins that should be deleted - their classifications were assigned, but are no longer selected.
        List<Classification_Profile_Assign__c> toDelete = new List<Classification_Profile_Assign__c>();
        for (Classification_Profile_Assign__c ca : cJoins.values()) {
            if (!selIds.contains(ca.Classification__c))
                toDelete.add(ca);
        }
        // Build list of join records to insert - they weren't originally assigned, but are now selected.
        List<Classification_Profile_Assign__c> toInsert = new List<Classification_Profile_Assign__c>();
        for (Id selId : selIds) {
            if (!currentIds.contains(selId))
                toInsert.add(
                    new Classification_Profile_Assign__c(
                        Classification__c = selId,
                        Profile__c = request.profileId
                    )
                );
        }
        system.debug(
            'In handleRequest: toInsert = ' + JSON.serialize(toInsert)
        );
        if (toDelete.size() > 0)
            delete toDelete;
        if (toInsert.size() > 0)
            insert toInsert;
    }

    // The selectedNames parameter is a double-vertical bar-separated list of short characteristic names.
    // NOTE: as of 2/2/16, there seems to be a bug in invocableVariable.  It errors out on null parameters.
    // So any calling Processes/Flows need to ensure that selectedNames is passed in as "||" rather than blank.
    public class UpdateClassificationsRequest {
        @InvocableVariable(required=true)
        public ID profileId;
        @InvocableVariable(required=true)
        public String selectedNames;
        @InvocableVariable(required=true)
        public String categoryName;
        @InvocableVariable(required=true)
        public String classificationType;
    }
}