public class PaymentMethodNewInvocable {
    @InvocableMethod(
        label='Build new payment method, normally by cloning a prior payment method'
        description='Build new payment method, normally by cloning a prior payment method'
    )
    // This is set up for a list of proposal ids, but only expect to be called with one, returning one new payment method.
    public static Id[] newPaymentMethod(List<Id> propIds) {
        Id[] pmIds = new List<Id>();
        for (Id pId : propIds)
            pmIds.add(PaymentMethodController.newPaymentMethod(pId));
        return pmIds;
    }
}