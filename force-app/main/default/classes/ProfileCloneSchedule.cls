/*
 * Clone profiles that have reached their expiration dates.
 * Schedule using Schedule button in setup.
 */
global with sharing class ProfileCloneSchedule implements Schedulable {
    global void execute(SchedulableContext scMain) {
        // Build a query that searches for profiles with expiration dates today or earlier.
        // Require that they haven't already been cloned (Next Profile field is blank).
        Integer batchSize = 1;
        String q =
            'SELECT Id, Decline_reason__c, Decline_reason__r.Name FROM Profile__c ' +
            ' WHERE Expiration_date__c <> null ' +
            ' AND Expiration_date__c <= TODAY ' +
            ' AND Next_profile__c = null';
        system.debug('ProfileCloneSchedule execute: q = ' + q);
        Database.executeBatch(new ProfileCloneBatch(q), batchSize);
    }
}