public with sharing class PaymentController {
    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;

    public PaymentController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
        this.selRecs = fetchRecords(new Set<Id>{ standardController.getId() });
        this.templates = Utilities.templatesMenu(
            objectName,
            START,
            selRecs,
            statusFieldName
        );
    }

    public PaymentController(
        ApexPages.StandardSetController standardSetController
    ) {
        this.standardSetController = standardSetController;
        Map<Id, Payment__c> selMap = new Map<Id, Payment__c>(
            (List<Payment__c>) standardSetController.getSelected()
        );
        this.selRecs = fetchRecords(selMap.keySet());
        this.templates = Utilities.templatesMenu(
            objectName,
            START,
            selRecs,
            statusFieldName
        );
    }

    // Build the menu of admissible correspondence templates for this object.
    private static String objectName = 'Payment__c';
    private static final String START = '--Select Template--';
    private static String statusFieldName = 'Proposal__r.Status_numeric__c';
    private List<Payment__c> selRecs;
    public List<selectOption> templates { get; private set; }
    public String selectedTemplate { get; set; }

    {
        selectedTemplate = START;
    }

    // Get selected records, then build and reset letters for them.
    public PageReference buildLetters() {
        // Generate error if no selected template - assign error to the templateType field.
        if (selectedTemplate == null || selectedTemplate == START) {
            ApexPages.AddMessage(
                new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Please select a template',
                    'Must select a template before building new letters'
                )
            );
            selectedTemplate = START; // If I don't reset to the START value, it gets set to one of the non-disabled values.
            return null;
        }
        // Gather email addresses from the related accounts.
        Set<Id> accIds = new Set<Id>();
        for (Payment__c p : selRecs)
            accIds.add(p.Proposal__r.Account__c);
        Map<Id, List<String>> emails = AccountController.emailsForAccounts(accIds);
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName(
            'Template__c',
            selectedTemplate
        );
        List<Letter__c> ls = new List<Letter__c>();
        for (Payment__c r : selRecs) {
            List<String> es = emails.get(r.Proposal__r.Account__c);
            ls.add(
                new Letter__c(
                    Template__c = templateId,
                    Account__c = r.Proposal__r.Account__c,
                    Account_owner__c = r.Proposal__r.Account__r.OwnerId,
                    Letter_owner__c = UserInfo.getUserId(),
                    Payment__c = r.Id,
                    Proposal__c = r.Proposal__c,
                    Region__c = r.Proposal__r.Region__c,
                    Custom_Reqs__c = r.Proposal__r.Custom_Reqs__c,
                    Emails__c = (es == null)
                        ? ''
                        : Utilities.stringJoinWithCharLimit(es, ',', 255)
                )
            );
        }
        insert ls;
        Map<Id, Letter__c> lsMap = new Map<Id, Letter__c>(ls);
        // Reset the new letters.
        LetterController.resetLetters0(lsMap.keySet(), false);
        // Changes have been saved; jump to the new letter if there's only one.
        if (standardController != null && ls.size() == 1)
            return Utilities.pageReferenceForRecord(ls[0]);
        else
            return doCancel(); // Stay in current layout.
    }

    // Get records for given ids.
    static private Payment__c[] fetchRecords(Set<Id> ids) {
        system.debug('fetchRecords: ids = ' + JSON.serialize(ids));
        return [
            SELECT
                Id,
                Proposal__c,
                Proposal__r.Account__c,
                Proposal__r.Status_numeric__c,
                Proposal__r.Account__r.OwnerId,
                Proposal__r.Region__c,
                Proposal__r.Custom_Reqs__c
            FROM Payment__c
            WHERE Id IN :ids
        ];
    }

    public PageReference doCancel() {
        return (standardSetController != null)
            ? standardSetController.cancel()
            : standardController.cancel();
    }

    /**********************************
     * For general use
     *********************************/
}