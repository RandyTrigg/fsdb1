// Find submitted form instances whose "parent" record has blank date submitted/received and update those date fields
Map<Id, sObject> toUpdate = new Map<Id, sObject>();
// Fetch all submitted form instances. The sort by form type is to avoid "too many chunks" error in the loop
Form_Instance__c[] fis = [
    SELECT Id, Form__r.Type__c, Date_submitted__c, Profile__c, Proposal__c, Assessment__c, Advisor__c,
    Profile__r.Date_submitted__c, Proposal__r.Date_received__c, Assessment__r.Date_submitted__c
    FROM Form_Instance__c
    WHERE Date_submitted__c <> null
    ORDER BY Form__r.Type__c 
];
for (Form_Instance__c fi : fis) {
    Date profSubmitted = fi.Profile__r.Date_submitted__c;
    Date propReceived = fi.Proposal__r.Date_received__c;
    Date assessSubmitted = fi.Assessment__r.Date_submitted__c;
    // Check for profile needing update
    if (fi.Profile__c != null && profSubmitted == null && fi.Proposal__c == null && fi.Assessment__c == null && fi.Advisor__c == null) {
        fi.Profile__r.Date_submitted__c = fi.Date_submitted__c;
        toUpdate.put(fi.Profile__c, fi.Profile__r);
    }
    // Check for proposal needing update
    if (fi.Proposal__c != null && propReceived == null && fi.Form__r.Type__c == 'Application') {
        fi.Proposal__r.Date_received__c = fi.Date_submitted__c;
        toUpdate.put(fi.Proposal__c, fi.Proposal__r);
    }
    // Check for assessment needing update
    if (fi.Assessment__c != null && assessSubmitted == null) {
        fi.Assessment__r.Date_submitted__c = fi.Date_submitted__c;
        toUpdate.put(fi.Assessment__c, fi.Assessment__r);
    }
}
system.debug(toUpdate.size());
if (toUpdate.size() > 0) Database.executeBatch(new GenericUpdateRecordsBatch(toUpdate.values()), 1);