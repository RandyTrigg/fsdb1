/* Generic way to delete a bunch of records of arbitrary type in a batch process. 
 * Call with either a list of records or a query.
 */
global with sharing class DeleteRecordsBatch implements Database.Batchable<sObject>{
    private List<sObject> recs;
    private String query;
    private Boolean hardDelete;

    global DeleteRecordsBatch(List<sObject> recs, Boolean hardDelete) {
        system.debug('DeleteRecordsBatch: recs.size() = ' +recs.size()+ '; hardDelete = ' +hardDelete);
        this.recs = recs;
        this.hardDelete = hardDelete;
    }

    global DeleteRecordsBatch(String query, Boolean hardDelete) {
        system.debug('DeleteRecordsBatch: query = ' +query+ '; hardDelete = ' +hardDelete);
        this.query = query;
        this.hardDelete = hardDelete;
    }

    global List<sObject> start(Database.BatchableContext BC){
        if (query != null) recs = (List<sObject>) Database.query(query);
        return recs;
    }

    /*
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(query);
    }
	*/

    global void execute(Database.BatchableContext BC, List<sObject> scope){
        system.debug('DeleteRecordsBatch execute: scope = ' +scope);
        delete scope;
        if (hardDelete) Database.emptyRecycleBin(scope);
    }

    global void finish(Database.BatchableContext BC){   
        AsyncApexJob a = [Select Id, Status, NumberOfErrors, JobItemsProcessed,
                          TotalJobItems, CreatedBy.Email
                          from AsyncApexJob where Id = :BC.getJobId()];
        
        // If errors, send an email to the Apex job's submitter. 
        if (a.NumberOfErrors > 0 || Test.isrunningtest()) {
            string message = 'The batch Apex job processed ' + a.TotalJobItems + ' batches with '+ a.NumberOfErrors + ' failures.';       
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] {a.CreatedBy.Email});
            mail.setCcAddresses(new String[] {Utilities.EmailAddressIM});
            mail.setSubject('Salesforce DeleteRecordsBatch ' + a.Status);
            mail.setPlainTextBody(message);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });  
        }
    }
}