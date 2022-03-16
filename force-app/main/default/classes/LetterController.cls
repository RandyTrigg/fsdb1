public class LetterController {
    public static Integer updateBatchSize = 5;
    public static Integer emailBatchSize = 5;
    public static Integer resetBatchSize = 5;
    public static Integer resetAsyncThreshold = 20;
    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;
    // Certain letter fields are displayed on VF page so need to be added in the controller constructor.
    private List<String> fieldsToAdd = new List<String>{
        'Page_1__c',
        'Page_2__c',
        'Page_3__c',
        'Page_4__c',
        'Page_5__c',
        'Language__c'
    };

    public LetterController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
        if (!Test.isRunningTest())
            standardController.addFields(fieldsToAdd);
    }

    public LetterController(
        ApexPages.StandardSetController standardSetController
    ) {
        this.standardSetController = standardSetController;
        if (!Test.isRunningTest())
            standardSetController.addFields(fieldsToAdd);
    }

    // Check letter template to perform any required special handling, then recompute the text of the selected letters.
    public PageReference resetLetters() {
        Set<Id> letIds = selectedLetters();
        if (resetLetters0(letIds, false))
            return returnPage();
        else
            return null;
    }

    // Check letter template to perform any required special handling, then recompute the text of the selected letters.
    // Return true if no errors.
    public static Boolean resetLetters0(Set<Id> letIds, Boolean emailFlg) {
        if (letIds.size() == 0)
            return false;
        // Special handling for assessment letters, assumed to be in a batch with single template and belonging to a single endorse request.
        String templateName = [
            SELECT Template__r.Name
            FROM Letter__c
            WHERE Id IN :letIds
        ][0]
        .Template__r.Name;
        return resetLetters1(letIds, emailFlg);
    }

    // Recompute the text of the selected letters either sync or batch async depending on size of set.
    // If emailFlg is true, then go async regardless of size of set.
    // However, if these are assessment letters, then always go sync to avoid race condition with updateassessments.
    public static Boolean resetLetters1(Set<Id> letIds, Boolean emailFlg) {
        Boolean result = true;
        if (letIds.size() == 0)
            return true;
        if (emailFlg || letIds.size() > resetAsyncThreshold) {
            // Fire up batch process for selected letters.
            Database.executeBatch(
                new LetterResetBatch(letIds, emailFlg),
                resetBatchSize
            );
        } else {
            result = resetLettersSync(letIds, emailFlg);
        }
        return result;
    }

    // Recompute the text of the selected letters synchronously, that is, in the foreground.
    // Return true if no errors.
    public static Boolean resetLettersSync(Set<Id> letIds, Boolean emailFlg) {
        LetterReset lr = new LetterReset();
        List<Id> sentLetIds = lr.resetLettersHandler(letIds);
        if (sentLetIds.size() > 0) {
            // Some letters have already been sent (emailed or printed) so couldn't be reset.
            String warning =
                sentLetIds.size() +
                ' out of ' +
                letIds.size() +
                ' letter(s) could not be reset, because they have non-blank Date Sent: ' +
                String.join(sentLetIds, ', ');
            ApexPages.AddMessage(
                new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    warning,
                    warning
                )
            );
            return false;
        } else {
            if (emailFlg)
                emailLetters0(letIds);
            return true;
        }
    }

    public PageReference doCancel() {
        return (standardSetController != null)
            ? standardSetController.cancel()
            : standardController.cancel();
    }

    // Email selected letters (VF context).
    public PageReference emailLetters() {
        Set<Id> letIds = selectedLetters();
        system.debug('emailLetters: letIds = ' + JSON.serialize(letIds));
        if (emailLetters0(letIds))
            return returnPage();
        else
            return null;
    }

    // Email the given letters
    public static Boolean emailLetters0(Set<Id> letIds) {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [
                SELECT
                    Emails__c,
                    Email_subject__c,
                    Email_footer__c,
                    Email_cc__c,
                    Date_sent__c,
                    Date_emailed__c,
                    Date_printed__c,
                    Page_1__c,
                    Page_2__c,
                    Page_3__c,
                    Page_4__c,
                    Page_5__c,
                    Profile__c,
                    Notification_email_subject__c,
                    Notification_email_body__c,
                    Template__r.Type__c,
                    Email_override_from_account__c
                FROM Letter__c
                WHERE Id IN :letIds AND Emails__c != null
            ]
        );
        system.debug('emailLetters0: lMap = ' + JSON.serialize(lMap));
        Map<Id, Letter__c> lChangedMap = new Map<Id, Letter__c>();
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        // Send emails from the appropriate org-wide email address depending on whether the letter is fundraising- or grantmaking-related.
        // Grab all authenticated sender email addresses from the custom metadata type, and from the OrgWideEmailAddress object.
        Sender_email_address__mdt[] senderEmails = [
            SELECT Id, DeveloperName, Email__c
            FROM Sender_email_address__mdt
        ];
        Map<String, String> senderEmailMap = new Map<String, String>();
        for (Sender_email_address__mdt s : senderEmails)
            senderEmailMap.put(s.DeveloperName, s.Email__c);
        OrgWideEmailAddress[] OWEAs = [
            SELECT Id, DisplayName, Address
            FROM OrgWideEmailAddress
        ];
        Map<String, OrgWideEmailAddress> OWEAMap = new Map<String, OrgWideEmailAddress>();
        for (OrgWideEmailAddress owea : OWEAs)
            OWEAMap.put(owea.Address, owea);
        String senderEmailAddressGM = senderEmailMap.get('Grantmaking');
        String senderEmailAddressFR = senderEmailMap.get('Fundraising');
        OrgWideEmailAddress senderOWEAGM = senderEmailAddressGM != null
            ? OWEAMap.get(senderEmailAddressGM)
            : null;
        OrgWideEmailAddress senderOWEAFR = senderEmailAddressFR != null
            ? OWEAMap.get(senderEmailAddressFR)
            : null;
        for (Letter__c l : lMap.values()) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            OrgWideEmailAddress senderOWEA = l.Template__r.Type__c ==
                'Grantmaking'
                ? senderOWEAGM
                : senderOWEAFR;
            if (senderOWEA != null)
                mail.setOrgWideEmailAddressId(senderOWEA.Id);
            // Use email addresses from the letter unless the linked account has an email override.
            String toAddresses = l.Email_override_from_account__c != null
                ? l.Email_override_from_account__c
                : l.Emails__c;
            mail.setToAddresses(toAddresses.deleteWhitespace().split(','));
            mail.setSubject(l.Email_subject__c);
            if (l.Email_cc__c != null)
                mail.setCcAddresses(
                    l.Email_cc__c.deleteWhitespace().split(',')
                );
            if (senderOWEA != null)
                mail.setReplyTo(senderOWEA.Address);
            String s = '';
            if (l.Page_1__c != null)
                s += l.Page_1__c;
            if (l.Page_2__c != null)
                s += '<br/><br/>' + l.Page_2__c;
            if (l.Page_3__c != null)
                s += '<br/><br/>' + l.Page_3__c;
            if (l.Page_4__c != null)
                s += '<br/><br/>' + l.Page_4__c;
            if (l.Page_5__c != null)
                s += '<br/><br/>' + l.Page_5__c;
            if (l.Email_footer__c != null)
                s += l.Email_footer__c;
            mail.setHtmlBody(
                '<p style="font-family:\'geomanistregular\',\'century gothic\',verdana,sans-serif;">' +
                s +
                '</p>'
            );
            mails.add(mail);
            l.Emailed_to__c = toAddresses;
            if (l.Date_emailed__c == null)
                l.Date_emailed__c = Date.today();
            lChangedMap.put(l.Id, l);
        }
        // Update grantmaking letter records in background if there's more than one.
        // Should we also do that for Dev letters?
        if (lChangedMap.size() > 0) {
            system.debug(
                'emailLetters0: lChangedMap.size() = ' +
                lChangedMap.size() +
                '; lChangedMap.values()[0] = ' +
                JSON.serialize(lChangedMap.values()[0])
            );
            if (
                lChangedMap.values()[0].Template__r.Type__c == 'Development' ||
                lChangedMap.size() == 1
            )
                update lChangedMap.values();
            else {
                // Want small batch size, except when testing when there must only be a single batch.
                Integer batchSize = Test.IsRunningTest()
                    ? lChangedMap.size()
                    : 1;
                Database.executeBatch(
                    new GenericUpdateRecordsBatch(lChangedMap.values()),
                    batchSize
                );
            }
        }
        // Send emails outside the loop to avoid governor limit.
        if (mails.size() > 0)
            Messaging.sendEmail(mails);
        return true;
    }

    // Print the selected letters, that is, display the letters in a multi-page pdf.
    public PageReference printLetters() {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [
                SELECT
                    Date_sent__c,
                    Date_emailed__c,
                    Date_printed__c,
                    Page_1__c,
                    Page_2__c,
                    Page_3__c,
                    Page_4__c,
                    Page_5__c,
                    Language__c
                FROM Letter__c
                WHERE Id IN :selectedLetters()
            ]
        );
        Map<Id, Letter__c> lChangedMap = new Map<Id, Letter__c>();
        Integer lCount = 0;
        for (Letter__c l : lMap.values()) {
            if (l.Date_printed__c == null) {
                l.Date_printed__c = Date.today();
                lChangedMap.put(l.Id, l);
            }
            // Update letter records in batches to prevent overrunning SOQL call governor limit.
            lCount += 1;
            if (Math.mod(lCount, updateBatchSize) == 0) {
                if (lChangedMap.size() > 0)
                    update lChangedMap.values();
                lChangedMap.clear();
            }
        }
        if (lChangedMap.size() > 0)
            update lChangedMap.values();
        sortLetters(); // Sort letters by account name.
        return new PageReference(
            (standardSetController != null)
                ? '/apex/LettersPrint'
                : '/apex/LetterPrint'
        );
    }

    // Sort letters by account name.
    private void sortLetters() {
        if (standardSetController != null) {
            Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
                (List<Letter__c>) standardSetController.getSelected()
            );
            List<Letter__c> lets = [
                SELECT
                    Date_sent__c,
                    Date_emailed__c,
                    Date_printed__c,
                    Page_1__c,
                    Page_2__c,
                    Page_3__c,
                    Page_4__c,
                    Page_5__c
                FROM Letter__c
                WHERE Id IN :lMap.keySet()
                ORDER BY Account__r.Name
            ];
            standardSetController.setSelected(lets);
        }
    }

    // Return a set of the selected letters - should work from either detail or list layout.
    private Set<Id> selectedLetters() {
        Set<Id> lSet;
        if (standardSetController != null) {
            Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
                (List<Letter__c>) standardSetController.getSelected()
            );
            lSet = lMap.keySet();
        } else if (standardController != null) {
            lSet = new Set<Id>{ standardController.getId() };
        }
        return lSet;
    }

    // Use the retURL parameter as return page if non-null, else use the cancel page.
    private PageReference returnPage() {
        PageReference retPage;
        String retURL = ApexPages.currentPage().getParameters().get('retURL');
        if (!String.isBlank(retURL)) {
            return new PageReference(retURL);
        } else {
            return (standardSetController != null)
                ? standardSetController.cancel()
                : standardController.cancel();
        }
    }

    // Use Date sent or Date received in this letter to set a field in a linked record,
    // based on object/field name stored in the letter's template.
    // NOTE: Letter object's lookup field must have the same name as the object (e.g. Proposal__c or Payment_Method__c).
    public static void setDateFieldInRelatedRecord(Id letId) {
        String[] relTemplateFlds = new List<String>{
            'Template__r.Date_sent_recd_field_name__c',
            'Template__r.Date_sent_recd_object_name__c'
        };
        Letter__c let = (Letter__c) Utilities.fetchRecord(
            'Letter__c',
            letId,
            relTemplateFlds
        );
        // Bail if letter hasn't been sent/received,
        // template doesn't specify a related object/field,
        // or if the letter doesn't link to the given object.
        String objName = let.Template__r.Date_sent_recd_object_name__c,
            fldName = let.Template__r.Date_sent_recd_field_name__c;
        if (
            (let.Date_sent__c == null &&
            let.Date_received__c == null) ||
            objName == null ||
            fldName == null ||
            let.get(objName) == null
        )
            return;
        // Get related record
        Id recId = (Id) let.get(objName);
        sObject rec = Utilities.fetchRecord(objName, recId, null);
        // If date field in related record is blank, then set to letter's date sent or date received.
        if (rec != null && rec.get(fldName) == null) {
            rec.put(
                fldName,
                let.Date_sent__c != null
                    ? let.Date_sent__c
                    : let.Date_received__c
            );
            update rec;
        }
    }
}