public class AdvisorTermController {

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
        Set<Id> selIds = getSelectedIds();
        Map < String, String > customParams = new Map < String, String >{'isEmail'=>'false'};
        List<Letter__c> ls = buildLetters0(selIds, selectedTemplate, customParams); //Not emails

        if(standardController != null && ls.size() == 1) return Utilities.pageReferenceForRecord(ls[0]);
        else return doCancel(); // Stay in current layout.
    }

    public static List<Letter__c> buildLetters0(Set<Id> selIds, ID templateId, Map < String, String > customParams) {
        //Set email flag from params
        Boolean emailFlg = false;
        if (customParams.containsKey('isEmail') && customParams.get('isEmail')=='true') {
            emailFlg = true;
        }
        
        // Load Advisor Records from IDS 
        List < Advisor_Term__c > advTermRecords = fetchRecords(selIds);

        // Build list of Account Ids
        Set<Id> accIds = new Set<Id> ();
        for (Advisor_Term__c at : advTermRecords) {
            accIds.add(at.Advisor__r.Account__c);
        }

        Map<Id, List<String>> accEmails = Utilities.emailsForAccounts(accIds);
        system.debug('buildLetters: accEmails = ' +JSON.serialize(accEmails));
        // Build new letters for selected records.
        List<Letter__c> ls = new List<Letter__c>();
        for (Advisor_Term__c r : advTermRecords){
            Advisor__c adv = r.Advisor__r;
            Id accId = adv.Account__c;
            String emails = accId != null && accEmails.get(accId) != null ? String.join(Utilities.removeNulls(accEmails.get(accId)), ',') : null;
            Letter__c let = new Letter__c (
                Template__c = templateId,
                Account__c = adv.Account__c,
                Account_owner__c = adv.Account__r.OwnerId,
                Letter_owner__c = UserInfo.getUserId(),
                Advisor_Term__c = r.Id,
                Advisor__c = adv.Id,
                Contact__c = adv.Contact__c,
                Emails__c = emails
            );
            // update any additional values from the map
            let = LetterController.updateWithParams(let, customParams);
            ls.add(let);
        }
        insert ls;
        Map<Id, Letter__c> lsMap = new Map<Id, Letter__c> (ls);
        // Reset the new letters.
        LetterController.resetLetters0(lsMap.keySet(), emailFlg);
        
        return ls;
    }
    
    // Get records for given ids.
    static private Advisor_Term__c[] fetchRecords(Set<Id> ids) {
        system.debug('fetchRecords: ids = ' +JSON.serialize(ids));
        return [
            SELECT Id, Status_numeric__c, Advisor__c, Advisor__r.Account__c, Advisor__r.Account__r.OwnerId, Advisor__r.Contact__c,
            Advisor__r.Emails__c, 
            Advisor__r.Contact__r.Email, Advisor__r.Contact__r.Email2__c
            FROM Advisor_Term__c
            WHERE Id IN : ids
        ];
    }
    
    public PageReference doCancel() {       
        return (standardSetController != null) ? standardSetController.cancel() : standardController.cancel();   
    }

    private Set<Id> getSelectedIds() {
        Set<Id> selIds;
        if (standardSetController != null) {
            Map<Id, Advisor_Term__c> selMap = new Map<Id, Advisor_Term__c> ((List<Advisor_Term__c>) standardSetController.getSelected());
            selIds = selMap.keySet();
        } else {
            selIds = new Set<Id> {standardController.getId()};
        }
        return selIds;
    }

    /**********************************
     * For general use
     *********************************/

    public static String reminderTemplateName = 'Assessment Reminder/Overdue letter';

    // Send email reminders/overdue notices for advisor terms with pending assessments, at least one of which is more than 2 days old.
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
            LetterController.buildAndEmailLetters(tmpl.Id, ats.keySet(), customParams);
        }
    }
   
}