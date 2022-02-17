/*
 * Update the totals in all funds where necessary.
 */
global class FundUpdateTotalsSchedule implements Schedulable {
    global void execute(SchedulableContext scMain) {
        FundController.updateTotals(null);
    }
}