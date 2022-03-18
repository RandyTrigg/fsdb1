public class PaymentMethodController {
    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;

    public PaymentMethodController(
        ApexPages.StandardController standardController
    ) {
        this.standardController = standardController;
        this.selRecs = fetchRecords(new Set<Id>{ standardController.getId() });
        setClassVars();
    }

    public PaymentMethodController(
        ApexPages.StandardSetController standardSetController
    ) {
        this.standardSetController = standardSetController;
        Map<Id, Payment_Method__c> selMap = new Map<Id, Payment_Method__c>(
            (List<Payment_Method__c>) standardSetController.getSelected()
        );
        this.selRecs = fetchRecords(selMap.keySet());
        setClassVars();
    }

    private static String objectName = 'Payment_Method__c';
    private static final String START = '--Select Template--';
    private List<Payment_Method__c> selRecs;
    Boolean hasOnlyCorrectionPMs, hasOnlyVerificationPMs;
    private String statusFieldName;
    public List<selectOption> templates { get; private set; }
    public String selectedTemplate { get; set; }

    {
        selectedTemplate = START;
    }

    // Compute template-related info used to build the menu of admissible correspondence templates for this object.
    private void setClassVars() {
        this.statusFieldName = 'Proposal__r.Status_numeric__c';
        this.templates = Utilities.templatesMenu(
            fetchTemplates(),
            START,
            selRecs,
            statusFieldName
        );
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
        // Gather account ids from payment methods.
        Set<Id> accIds = new Set<Id>();
        for (Payment_Method__c pm : selRecs) {
            if (pm.Proposal__c != null)
                accIds.add(pm.Proposal__r.Account__c);
        }
        Map<Id, List<String>> accEmails = Utilities.emailsForAccounts(
            accIds
        );
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName(
            'Template__c',
            selectedTemplate
        );
        List<Letter__c> ls = new List<Letter__c>();
        for (Payment_Method__c r : selRecs) {
            Proposal__c prop = r.Proposal__r;
            if (prop == null)
                continue; // Skip this payment method, if lookups are both blank.
            // Gather all emails for this payment method.
            Set<String> es = new Set<String>();
            if (prop != null)
                es.addAll(accEmails.get(prop.Account__c));
            ls.add(
                new Letter__c(
                    Template__c = templateId,
                    Account__c = prop != null ? prop.Account__c : null,
                    Account_owner__c = prop != null
                        ? prop.Account__r.OwnerId
                        : null,
                    Letter_owner__c = UserInfo.getUserId(),
                    Payment_Method__c = r.Id,
                    Proposal__c = prop != null ? prop.Id : null,
                    Region__c = prop != null ? prop.Region__c : null,
                    Custom_Reqs__c = prop != null ? prop.Custom_Reqs__c : null,
                    Emails__c = (es == null)
                        ? ''
                        : Utilities.stringJoinWithCharLimit(
                                new List<String>(es),
                                ',',
                                255
                            )
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
    private Payment_Method__c[] fetchRecords(Set<Id> ids) {
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
            FROM Payment_Method__c
            WHERE Id IN :ids
        ];
    }

    // Get templates for the pull-down list.
    public Template__c[] fetchTemplates() {
        system.debug('fetchTemplates: selRecs = ' + JSON.serialize(selRecs));
        // Grab all active templates.
        Template__c[] templates = [
            SELECT Name, Allowed_statuses__c
            FROM Template__c
            WHERE Source_object__c = :objectName AND Active__c = true
            ORDER BY Name
        ];
        return templates;
    }

    public PageReference doCancel() {
        return (standardSetController != null)
            ? standardSetController.cancel()
            : standardController.cancel();
    }

    /**********************************
     * For general use
     *********************************/

    // Update the Unique id in given payment method.
    // Copy the value from the latest payment method for the same account or for the FS account if any.
    // If this is the only payment method, then build a new unique id from the Account Number field.
    public static void updateUniqueId(Id pmId) {
        Payment_Method__c pm = [
            SELECT
                Id,
                Account__c,
                Unique_id__c,
                Type__c,
                Fiscal_sponsor__c,
                Proposal__c,
                Proposal__r.Account__c,
                Proposal__r.Account__r.Account_number__c,
                Account__r.Account_number__c,
                Fiscal_sponsor__r.Account_number__c
            FROM Payment_Method__c
            WHERE Id = :pmId
        ];
        // Bail if Unique id already has a value, or if the fiscal sponsor link hasn't yet been set for an FS payment method.
        if (
            pm.Unique_id__c != null ||
            (pm.Type__c == 'Fiscal sponsor' &&
            pm.Fiscal_sponsor__c == null)
        )
            return;
        // Set Unique id appropriately depending on whether pm is a fiscal sponsor.
        List<Payment_Method__c> pms;
        if (pm.Type__c == 'Fiscal sponsor') {
            pms = [
                SELECT Id, Unique_id__c
                FROM Payment_Method__c
                WHERE
                    Fiscal_sponsor__c = :pm.Fiscal_sponsor__c
                    AND Type__c = 'Fiscal sponsor'
                    AND Id != :pmId
                ORDER BY CreatedDate DESC
            ];
            // Copy Unique id from most recent pm of that account, or build a new one from Account number.
            pm.Unique_id__c = pms.size() > 0
                ? pms[0].Unique_id__c
                : pm.Fiscal_sponsor__r.Account_number__c + '-1';
        } else if (pm.Proposal__c != null) {
            pms = [
                SELECT Id, Unique_id__c
                FROM Payment_Method__c
                WHERE
                    Proposal__r.Account__c = :pm.Proposal__r.Account__c
                    AND Type__c != 'Fiscal sponsor'
                    AND Id != :pmId
                ORDER BY CreatedDate DESC
            ];
            // Copy Unique id from most recent pm of that account, or build a new one from Account number.
            pm.Unique_id__c = pms.size() > 0
                ? pms[0].Unique_id__c
                : pm.Proposal__r.Account__r.Account_number__c + '-1';
        }
        if (pm.Unique_id__c != null)
            update pm;
    }

    // Build and return new payment method for given proposal
    public static Id newPaymentMethod(Id propId) {
        // Clone most recent payment method for this proposal, but only if payment info was confirmed.
        // If prop has no payment methods, then clone the most recent on parent account whose payment info was confirmed.
        // If none on the account or none confirmed, then build a fresh one.
        system.debug('newPaymentMethod: propId = ' + propId);
        Payment_Method__c newPM, oldPM, currPM;
        Proposal__c p = (Proposal__c) Utilities.fetchRecord(
            'Proposal__c',
            propId,
            new List<String>{
                Utilities.buildChildSubQuery(
                    'Payment_Method__c',
                    'Payment_Methods__r',
                    'WHERE Date_payment_info_confirmed__c <> null ' +
                    'ORDER BY Date_payment_info_confirmed__c DESC'
                ),
                Utilities.buildChildSubQuery('Payment__c', 'Payments__r', null),
                'Current_payment_milestone__r.Planned_amount__c',
                'Current_payment_method__r.CreatedDate'
            }
        );
        currPM = p.Current_payment_method__r;
        // Compute the amount to pay based on the amount remaining to be paid on the current payment milestone, if any.
        // Else use the proposal's To be paid field, that is, the amount remaining for the grant as a whole.
        Id payMId = p.Current_payment_milestone__c;
        Double payMAmount = p.Current_payment_milestone__r.Planned_amount__c;
        Double amountToPay;
        if (payMId != null && payMAmount > 0) {
            Double total = 0;
            for (Payment__c pay : p.Payments__r) {
                if (pay.Date_paid__c != null && pay.Milestone__c == payMId)
                    total += pay.Amount_paid__c;
            }
            amountToPay = payMAmount - total;
        }
        if (amountToPay == null || amountToPay <= 0)
            amountToPay = p.To_be_paid__c;
        // Find the payment method to clone, if any.
        if (p.Payment_Methods__r.size() > 0) {
            // Use prop's most recent payment method according to date payment info confirmed.
            oldPM = p.Payment_Methods__r[0];
            // Bail if there's a current payment method created after the confirmed one.
            if (currPM != null && currPM.CreatedDate > oldPM.CreatedDate)
                return null;
        } else {
            // Bail if there's a current payment method (which thus hasn't been confirmed).
            if (currPM != null)
                return null;
            // Use the parent account's most recently confirmed payment method, if any.
            Account a = (Account) Utilities.fetchRecord(
                'Account',
                p.Account__c,
                new List<String>{
                    Utilities.buildChildSubQuery(
                        'Payment_Method__c',
                        'Payment_Methods__r',
                        'WHERE Date_payment_info_confirmed__c <> null ' +
                        'ORDER BY Date_payment_info_confirmed__c DESC'
                    )
                }
            );
            if (a.Payment_Methods__r.size() > 0)
                oldPM = a.Payment_Methods__r[0];
            else
                newPM = new Payment_Method__c(
                    Proposal__c = p.Id,
                    Account__c = p.Account__c
                );
        }
        if (oldPM != null) {
            // Clone an earlier payment method.
            newPM = oldPM.clone(false, true);
            // Clear all editable date fields, except for Date submitted.
            for (
                String fName : Utilities.updateableFieldNamesOfType(
                    'Payment_Method__c',
                    'Date'
                )
            )
                if (fName != 'Date_submitted__c')
                    newPM.put(fName, null);
            // Other field settings
            newPM.Extra_instructions__c = null;
            newPM.Proposal__c = p.Id;
            newPM.Pre_populated_from__c = oldPM.Id;
        }
        if (newPM != null) {
            newPM.Amount_to_pay__c = amountToPay;
            newPM.Date_ready_for_payment__c = null;
            newPM.Date_payment_info_confirmed__c = null;
            insert newPM;
        }
        // Update proposal now that there's a new payment method
        ProposalUpdate.updateProposal(p.Id);
        return newPM != null ? newPM.Id : null;
    }
}