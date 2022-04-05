public with sharing class ProfileClassificationsCloneInvocable {
    public with sharing class myException extends Exception {
    }

    @InvocableMethod(
        label='Clone profile classifications for proposal'
        description='Clone the classification assigns of a profile and assign as join records to the given proposal'
    )
    public static void cloneProfileClassifications(
        List<CloneClassificationsRequest> requests
    ) {
        for (CloneClassificationsRequest request : requests) {
            handleRequest(request);
        }
    }

    // Gather classification joins for the profile, and build assignments for the proposal.
    public static void handleRequest(CloneClassificationsRequest request) {
        system.debug('handleRequest: request = ' + JSON.serialize(request));
        // Get all classifications assigned to profile.
        List<Classification_Profile_Assign__c> joins = new List<Classification_Profile_Assign__c>(
            [
                SELECT Id, Classification__c, Rank__c
                FROM Classification_Profile_Assign__c
                WHERE Profile__c = :request.profileId
            ]
        );
        // Build new classification joins for the proposal.
        List<Classification_Assign__c> newJoins = new List<Classification_Assign__c>();
        for (Classification_Profile_Assign__c j : joins) {
            newJoins.add(
                new Classification_Assign__c(
                    Classification__c = j.Classification__c,
                    Proposal__c = request.proposalId,
                    Rank__c = j.Rank__c
                )
            );
        }
        if (newJoins.size() > 0)
            insert newJoins;
    }

    public with sharing class CloneClassificationsRequest {
        @InvocableVariable(required=true)
        public ID profileId;
        @InvocableVariable(required=true)
        public ID proposalId;
    }
}