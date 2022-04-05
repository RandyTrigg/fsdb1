/*
* Update stats fields of all countries.
* Schedule using Schedule button in setup.
*/
global with sharing class CountryStatsSchedule implements Schedulable {
    global void execute (SchedulableContext scMain) {
        Integer batchSize = 5;
        String q = 'SELECT Id FROM Country__c ';
        system.debug('CountryStatsSchedule execute: q = ' +q);
        Database.executeBatch(new CountryStatsBatch(q), batchSize);
    }
}