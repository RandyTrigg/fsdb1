/*
* Build and email reminder/overdue letters for advisor terms with pending endorsements.
*/
global with sharing class AdvisorTermRemindersSchedule implements Schedulable {
    global void execute (SchedulableContext scMain) {
        AdvisorTermController.emailRemindersOverdues();
    }
}