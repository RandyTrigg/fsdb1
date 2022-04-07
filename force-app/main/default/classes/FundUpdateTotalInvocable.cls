public with sharing class FundUpdateTotalInvocable {
    @InvocableMethod(
        label='Recalculate total available in fund records'
        description='Recalculate total available in fund records'
    )
    // Expects to be called with the id of the fund in which updateTotals was invoked.
    // That fund will be updated immediately; any other funds needing updates will be updated in a batch process.
    public static void updateTotal(List<Id> fundIds) {
        FundController.updateTotals(fundIds[0]);
    }
}