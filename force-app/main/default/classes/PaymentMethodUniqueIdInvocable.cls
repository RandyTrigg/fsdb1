public with sharing class PaymentMethodUniqueIdInvocable {
    @InvocableMethod(
        label='Update Unique id in payment method'
        description='Update Unique id in payment method'
    )
    public static void updateUniqueId(List<Id> paymentMethodIds) {
        for (Id pmId : paymentMethodIds)
            PaymentMethodController.updateUniqueId(pmId);
    }
}