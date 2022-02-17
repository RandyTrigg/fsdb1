public class AccountController {
    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;

    public AccountController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
    }

    public AccountController(
        ApexPages.StandardSetController standardSetController
    ) {
        this.standardSetController = standardSetController;
    }

    // Build the menu of admissible correspondence templates for this object.
    private static String objectName = 'Account';
    private static final String START = '--Select Template--';
    public List<selectOption> templates { get; private set; }
    {
        templates = Utilities.templatesForObject(objectName, START);
    }
    public String selectedTemplate { get; set; }

    {
        selectedTemplate = START;
    }

    // Build and reset letters for selected records.
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
        Set<Id> selIds = getSelectedIds();
        Map<Id, Account> selMap = new Map<Id, Account>(
            [SELECT Id, OwnerId, GM_Region__c FROM Account WHERE Id IN :selIds]
        );
        Map<Id, List<String>> emails = emailsForAccounts(selMap.keySet());
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName(
            'Template__c',
            selectedTemplate
        );
        List<Letter__c> ls = new List<Letter__c>();
        for (Account r : selMap.values()) {
            List<String> es = emails.get(r.Id);
            ls.add(
                new Letter__c(
                    Template__c = templateId,
                    Account__c = r.Id,
                    Account_owner__c = r.OwnerId,
                    Letter_owner__c = UserInfo.getUserId(),
                    Region__c = r.GM_Region__c,
                    Emails__c = Utilities.stringJoinWithCharLimit(es, ',', 255)
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

    public PageReference doCancel() {
        return (standardSetController != null)
            ? standardSetController.cancel()
            : standardController.cancel();
    }

    private Set<Id> getSelectedIds() {
        Set<Id> selIds;
        if (standardSetController != null) {
            Map<Id, Account> selMap = new Map<Id, Account>(
                (List<Account>) standardSetController.getSelected()
            );
            selIds = selMap.keySet();
        } else {
            selIds = new Set<Id>{ standardController.getId() };
        }
        return selIds;
    }

    /**********************************
     * For general use
     *********************************/

    // Fetch account records with given ids, grabbing all contact info fields.
    public static List<Account> fetchAccountsContactInfo(Set<Id> accIds) {
        return [
            SELECT
                Name,
                Org_name_GM__c,
                Website,
                Contact_info_GM__c,
                Contact_emails_GM__c,
                Phone,
                Phone2__c,
                GM_Email__c,
                GM_Email2__c,
                Contact_primary__c,
                Contact_primary__r.Name,
                RecordType.DeveloperName,
                BillingAddress,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode,
                BillingCountry,
                (
                    SELECT Email, Email2__c, Rank__c
                    FROM Contacts
                    WHERE Email != null
                    ORDER BY Rank_non_blank__c
                )
            FROM Account
            WHERE Id IN :accIds
        ];
    }

    // Return a map of emails for given accounts; results depend on account record type.
    public static Map<Id, List<String>> emailsForAccounts(Set<Id> aIds) {
        Map<ID, List<String>> eMap = new Map<Id, List<String>>();
        List<Account> accts = fetchAccountsContactInfo(aIds);
        //system.debug('accts = ' +JSON.serialize(accts));
        // Gather emails for each account.
        for (Account a : accts) {
            eMap.put(a.Id, emailsForAccount(a));
        }
        return eMap;
    }

    // Return the unique email addresses that haven't been marked invalid for the given account.
    // Use Email and Email2 fields plus emails of rank 1 contacts.  If none of those, use linked emails.
    // NOTE: The caller should have fetched all necessary contact info fields into given account.
    public static List<String> emailsForAccount(Account a) {
        Set<String> uniqueEmails = new Set<String>();
        List<String> orderedEmails = new List<String>(); // Used for contact emails of Dev accounts
        if (
            a.RecordType.DeveloperName != null &&
            a.RecordType.DeveloperName.contains('GM')
        ) {
            // Gather emails for a GM account.
            // Grab emails from fields and from contacts.
            if (a.GM_Email__c != null)
                uniqueEmails.add(a.GM_Email__c);
            if (a.GM_Email2__c != null)
                uniqueEmails.add(a.GM_Email2__c);
            // For GM accounts, only add emails from rank 1 contacts.
            for (Contact c : a.Contacts) {
                if (c.Rank__c == 1) {
                    uniqueEmails.add(c.Email);
                }
            }
            system.debug(
                'emailsForAccount: uniqueEmails (GM) = ' +
                JSON.serialize(uniqueEmails)
            );
            return new List<String>(uniqueEmails);
        } else {
            // For Dev accounts, gather unique contact emails, preserving the original rank order.
            for (Contact c : a.Contacts)
                if (!uniqueEmails.contains(c.Email)) {
                    uniqueEmails.add(c.Email);
                    orderedEmails.add(c.Email);
                }
            system.debug(
                'emailsForAccount: orderedEmails (Dev) = ' +
                JSON.serialize(orderedEmails)
            );
            return orderedEmails;
        }
    }

    // Update a GM account's contact info by "touching" the orgContactInfo form instance's Submit form log entry (which triggers invocation of apex code).
    public static Boolean updateContactInfo(Id accountId) {
        UpdateAccountContactInfo.UpdateAccountContactInfo(
            new List<Id>{ accountId }
        );
        return true;
    }

    /**********************************
     * For use in Lightning components
     *********************************/
}