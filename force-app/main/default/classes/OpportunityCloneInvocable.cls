public with sharing class OpportunityCloneInvocable {
    @InvocableMethod(
        label='Clone closed opportunity'
        description='Clone closed opportunity'
    )
    public static void opportunityClone(List<Id> oppIds) {
        handleRequest(oppIds[0]);
    }

    public static void handleRequest(Id oppId) {
        OpportunityController.opportunityClone(oppId);
    }
}