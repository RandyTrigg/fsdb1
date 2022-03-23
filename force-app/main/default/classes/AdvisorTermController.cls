public with sharing class AdvisorTermController {

    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;
 
    public AdvisorTermController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
        this.selRecs = fetchRecords(new Set<Id> {standardController.getId()});
        this.templates = Utilities.templatesMenu(objectName, START, selRecs, statusFieldName);
    }
 
    public AdvisorTermController(ApexPages.StandardSetController standardSetController) {
        this.standardSetController = standardSetController;
        Map<Id, Advisor_Term__c> selMap = new Map<Id, Advisor_Term__c> ((List<Advisor_Term__c>) standardSetController.getSelected());
        this.selRecs = fetchRecords(selMap.keySet());
        this.templates = Utilities.templatesMenu(objectName, START, selRecs, statusFieldName);
    }
    
    // Build the menu of admissible correspondence templates for this object. 
    private static String objectName = 'Advisor_Term__c';
    private static final String START = '--Select Template--';
    private static String statusFieldName = 'Status_numeric__c';
    private List<Advisor_Term__c> selRecs;
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
        for (Advisor_Term__c at : selRecs) advIds.add(at.Advisor__c);
        // Gather email addresses from the advisor accounts.
        Set<Id> accIds = new Set<Id> ();
        for (Advisor_Term__c advt : selRecs) accIds.add(advt.Advisor__r.Account__c);
        Map<Id, List<String>> accEmails = Utilities.emailsForAccounts(accIds);
        system.debug('buildLetters: accEmails = ' +JSON.serialize(accEmails));
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName('Template__c', selectedTemplate);
        List<Letter__c> ls = new List<Letter__c>();
        for (Advisor_Term__c r : selRecs){
            Advisor__c adv = r.Advisor__r;
            Id accId = adv.Account__c;
            String emails = accId != null && accEmails.get(accId) != null ? String.join(Utilities.removeNulls(accEmails.get(accId)), ',') : null;
            ls.add(new Letter__c (
                Template__c = templateId,
                Account__c = adv.Account__c,
                Account_owner__c = adv.Account__r.OwnerId,
                Letter_owner__c = UserInfo.getUserId(),
                Advisor_Term__c = r.Id,
                Advisor__c = adv.Id,
                Contact__c = adv.Contact__c,
                Emails__c = emails
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
    static private Advisor_Term__c[] fetchRecords(Set<Id> ids) {
        system.debug('fetchRecords: ids = ' +JSON.serialize(ids));
        return [
            SELECT Id, Status_numeric__c, Advisor__c, Advisor__r.Account__c, Advisor__r.Account__r.OwnerId, Advisor__r.Contact__c,
            Advisor__r.Emails__c, Advisor__r.Contact__r.Email, Advisor__r.Contact__r.Email2__c
            FROM Advisor_Term__c
            WHERE Id IN : ids
        ];
    }
    
    public PageReference doCancel() {       
        return (standardSetController != null) ? standardSetController.cancel() : standardController.cancel();   
    }

    /**********************************
     * For general use
     *********************************/

    public static String reminderTemplateName = 'Assessment Reminder/Overdue letter';

    // Send email reminders/overdue notices for advisor terms with pending assessments, at least one of which is more than 2 days old.
    // NOTE: As of 3/22/22, the call to build and email letters is commented out. Can uncomment when Melissa's bulk email infrastructure is in LetterController (ala GFW).
    public static void emailRemindersOverdues () {
        Template__c tmpl = [SELECT Id FROM Template__c WHERE Name = : reminderTemplateName LIMIT 1];
        // Fetch advisor terms needing a reminder letter.
        Date recentDay = Date.today().addDays(-2);
        Map<Id, Advisor_Term__c> ats = new Map<Id, Advisor_Term__c> ([
            SELECT Id
            FROM Advisor_Term__c
            WHERE Date_auto_reminders_paused__c = null
            AND ID IN (
                SELECT Advisor_Term__c 
                FROM Assessment__c
                WHERE Status_external__c = 'Pending'
                AND CreatedDate < : recentDay
                )
        ]);
        if (ats.size() > 0 && tmpl != null) {
            Map <String, String> customParams = new Map <String, String>{'isEmail'=>'true','autoGeneratedEmail'=>'true'};
            // Temporarily disabled - see comment above
            //LetterController.buildAndEmailLetters(tmpl.Id, ats.keySet(), customParams);
        }
    }
   
}