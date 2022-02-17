public with sharing class AccountUpdateContactInfoInvocable {
    @InvocableMethod(
        label='Update contact info by touching OrgContactInfo\'s Submit Form Log Entry record'
        description='Update contact info by touching OrgContactInfo\'s Submit Form Log Entry record'
    )
    public static List<Boolean> updateContactInfo(List<Id> accountIds) {
        Boolean[] result = new List<Boolean>();
        for (Id aId : accountIds) {
            result.add(AccountController.updateContactInfo(aId));
        }
        return result;
    }
}