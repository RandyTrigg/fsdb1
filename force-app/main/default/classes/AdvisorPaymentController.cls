public with sharing class AdvisorPaymentController {

    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;
 
    public AdvisorPaymentController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
        this.selRecs = fetchRecords(new Set<Id> {standardController.getId()});
        this.templates = Utilities.templatesMenu(objectName, START, selRecs, statusFieldName);
    }
 
    public AdvisorPaymentController(ApexPages.StandardSetController standardSetController) {
        this.standardSetController = standardSetController;
        Map<Id, Advisor_Payment__c> selMap = new Map<Id, Advisor_Payment__c> ((List<Advisor_Payment__c>) standardSetController.getSelected());
        this.selRecs = fetchRecords(selMap.keySet());
        this.templates = Utilities.templatesMenu(objectName, START, selRecs, statusFieldName);
    }
    
    // Build the menu of admissible correspondence templates for this object. 
    private static String objectName = 'Advisor_Payment__c';
    private static final String START = '--Select Template--';
    private static String statusFieldName = 'Advisor_Term__r.Status_numeric__c';
    private List<Advisor_Payment__c> selRecs;
    public List<selectOption> templates { get; private set; }
    public String selectedTemplate {get; set;} { selectedTemplate = START; }

    // Get selected records, then build and reset letters for them.
    public PageReference buildLetters() {
        // Generate error if no selected template - assign error to the templateType field.
        if (selectedTemplate == null || selectedTemplate == START) {
            ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please select a template', 'Must select a template before building new letters'));
            selectedTemplate = START; // If I don't reset to the START value, it gets set to one of the non-disabled values. 
            return null;
        }
        Set<Id> advIds = new Set<Id> ();
        for (Advisor_Payment__c ap : selRecs) {
            Id advId = ap.Advisor_Term__r.Advisor__c;
            if (advId != null) advIds.add(advId);
        }
        Map<Id, List<String>> emails = AdvisorController.emailsForAdvisors(advIds);
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName('Template__c', selectedTemplate);
        List<Letter__c> ls = new List<Letter__c>();
        for (Advisor_Payment__c r : selRecs){
            Id advId = r.Advisor_Term__r.Advisor__c;
            List<String> es = emails.get(advId);
            ls.add(new Letter__c (
                Template__c = templateId,
                Account__c = r.Advisor_Term__r.Advisor__r.Account__c,
                Account_owner__c = r.Advisor_Term__r.Advisor__r.OwnerId,
                Letter_owner__c = UserInfo.getUserId(),
                Advisor_Payment__c = r.Id,
                Advisor_Term__c = r.Advisor_Term__c,
                Advisor__c = r.Advisor_Term__r.Advisor__c,
                Emails__c = (es == null) ? '' : Utilities.stringJoinWithCharLimit(es, ',', 255)
            ));
        }
        insert ls;
        Map<Id, Letter__c> lsMap = new Map<Id, Letter__c> (ls);
        // Reset the new letters.
        LetterController.resetLetters0(lsMap.keySet(), false);
        // Changes have been saved; jump to the new letter if there's only one.
        if(standardController != null && ls.size() == 1) return Utilities.pageReferenceForRecord(ls[0]);
        else return doCancel(); // Stay in current layout.
    }
    
    // Get records for given ids.
    private Advisor_Payment__c[] fetchRecords(Set<Id> ids) {
        system.debug('fetchRecords: ids = ' +JSON.serialize(ids));
        return [
            SELECT Id, Advisor_Term__c, Advisor_Term__r.Advisor__c, Advisor_Term__r.Advisor__r.Account__c, 
            Advisor_Term__r.Status_numeric__c, Advisor_Term__r.Advisor__r.OwnerId
            FROM Advisor_Payment__c
            WHERE Id IN : ids
        ];
    }
    
    public PageReference doCancel() {       
        return (standardSetController != null) ? standardSetController.cancel() : standardController.cancel();   
    }

}