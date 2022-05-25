// Update the target fields for form data under the given form instances. 
global class FormDataUpdateTargetsBatch implements Database.Batchable<sObject>{
    private String query;

    global FormDataUpdateTargetsBatch(String query) {
        this.query = query;
    }

    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Form_Instance__c> scope){
        for (Form_Instance__c fi : scope) FormDataController.updateTargetFields(fi.Id);
    }

    global void finish(Database.BatchableContext BC){   
        AsyncApexJob a = [Select Id, Status, NumberOfErrors, JobItemsProcessed,
            TotalJobItems, CreatedBy.Email
            from AsyncApexJob where Id = :BC.getJobId()];
       
        // Send error email if there were errors.
        if (a.NumberOfErrors > 0) Utilities.BatchErrorEmail('FormDataUpdateTargetsBatch', a);
    }
}