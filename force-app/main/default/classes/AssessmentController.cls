public with sharing class AssessmentController {

    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;
 
    public AssessmentController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
        this.selRecs = fetchRecords(new Set<Id> {standardController.getId()});
        this.templates = Utilities.templatesMenu(objectName, START, selRecs, statusFieldName);
    }
 
    public AssessmentController(ApexPages.StandardSetController standardSetController) {
        this.standardSetController = standardSetController;
        Map<Id, Assessment__c> selMap = new Map<Id, Assessment__c> ((List<Assessment__c>) standardSetController.getSelected());
        this.selRecs = fetchRecords(selMap.keySet());
        this.templates = Utilities.templatesMenu(objectName, START, selRecs, statusFieldName);
    }
    
    // Build the menu of admissible correspondence templates for this object. 
    private static String objectName = 'Assessment__c';
    private static final String START = '--Select Template--';
    private static String statusFieldName = 'Status_numeric__c';
    private List<Assessment__c> selRecs;
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
        for (Assessment__c ap : selRecs) {
            Id advId = ap.Advisor__c;
            if (advId != null) advIds.add(advId);
        }
        Map<Id, List<String>> emails = AdvisorController.emailsForAdvisors(advIds);
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName('Template__c', selectedTemplate);
        List<Letter__c> ls = new List<Letter__c>();
        for (Assessment__c r : selRecs){
            Id advId = r.Advisor__c;
            List<String> es = emails.get(advId);
            ls.add(new Letter__c (
                Template__c = templateId,
                Account__c = r.Advisor__r.Account__c,
                Account_owner__c = r.Advisor__r.OwnerId,
                Letter_owner__c = UserInfo.getUserId(),
                Assessment__c = r.Id,
                Advisor__c = advId,
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
    private Assessment__c[] fetchRecords(Set<Id> ids) {
        system.debug('fetchRecords: ids = ' +JSON.serialize(ids));
        return [
            SELECT Id, Advisor__c, Advisor__r.Account__c, 
            Status_numeric__c, Advisor__r.OwnerId
            FROM Assessment__c
            WHERE Id IN : ids
        ];
    }
    
    public PageReference doCancel() {       
        return (standardSetController != null) ? standardSetController.cancel() : standardController.cancel();   
    }

    /**********************************
    * Invoked from LWCs via SiteController class
    *********************************/

    // Collection of data related to an assessment. Constructor builds a new form instance if needed for assessments that are linked to a form.
    public inherited sharing class AssessmentData {
        public Id formInstanceId;
        public Id assessedRecordId;
        public String advisorName, advisorTermType, formName, reviewFormName;
        
        public AssessmentData (Id assessmentId) {
            // Grab assessment fields along with child form instances.
            String[] relFieldNames = new List<String> {
                'Advisor__r.Name', 'Advisor_Term__r.Type__c, Form__r.Name, Review_Form__r.Name'
            };
            relFieldNames.add(Utilities.buildChildSubQuery('Form_Instance__c', 'Form_Instances__r', null));
            Assessment__c a = (Assessment__c)Utilities.fetchRecord('Assessment__c', assessmentId, relFieldNames);
            this.advisorName = a.Advisor__r.Name;
            this.advisorTermType = a.Advisor_Term__r.Type__c;
            this.formName = a.Form__r.Name;
            this.reviewFormName = a.Review_Form__r.Name;
            this.assessedRecordId = a.Milestone__c != null ? a.Milestone__c :
                a.Proposal__c != null ? a.Proposal__c :
                a.Profile__c != null ? a.Profile__c :
                null;
            if (this.assessedRecordId == null) throw new GFW_Exception('AssessmentData constructor', 'Assessment has no linked milestone/proposal/profile');
            // Separately handle form-based versus review-form-based assessments
            if (a.Form__c != null) {
                // Build new form instance if necessary
                Form_Instance__c fi;
                if (a.Form_Instances__r.size() > 0) fi = a.Form_Instances__r[0];
                else if (a.Date_submitted__c != null) { // Submitted form should already have a form instance!
                    throw new GFW_Exception('AssessmentData constructor', 'Submitted form-based assessment has no form instance');
                } else { // Build new form instance
                    fi = new Form_Instance__c (
                        Form__c = a.Form__c,
                        Advisor__c = a.Advisor__c,
                        Advisor_Term__c = a.Advisor_Term__c,
                        Assessment__c = assessmentId,
                        Milestone__c = a.Milestone__c,
                        Proposal__c = a.Proposal__c,
                        Profile__c = a.Profile__c
                    );
                    insert fi;
                }
                this.formInstanceId = fi.Id;
            } else if (a.Review_Form__c != null) {
                // Any other code for reviews performed at the community
                // ...
            } else throw new GFW_Exception('AssessmentData constructor', 'Assessment has blank Form__c AND blank Review_Form__c');
        }
    }
    

}