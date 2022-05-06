public class PaymentMethodProcessFIInvocable {
    @InvocableMethod(
        label='Process a payment method-related form instance'
        description='Process a payment method-related form instance'
    )
    // Expects to be called with a single form instance Id (the list parameter is required for invocable methods)
    public static void processFormInstance(List<Id> formInstanceIds) {
        // Commented out for FFDB 9/11/2020
        //PaymentMethodController.processFormInstance(formInstanceIds[0]);
    }
}