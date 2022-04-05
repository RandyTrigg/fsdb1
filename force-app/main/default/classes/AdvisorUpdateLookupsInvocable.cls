public with sharing class AdvisorUpdateLookupsInvocable {
    @InvocableMethod(
        label='Update lookup fields in Advisor'
        description='Update lookup fields in Advisor'
    )
    public static void updateLookups (List<Id> advisorIds) {
        for (Id aId : advisorIds) AdvisorController.updateLookups(aId);
    }
}