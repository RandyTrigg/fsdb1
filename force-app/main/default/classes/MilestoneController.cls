public class MilestoneController {
    /**********************************
     * For use in Lightning components
     *********************************/

    @AuraEnabled
    public static MilestoneInfo getMilestoneInfo(Id mId) {
        MilestoneInfo result = new MilestoneInfo(mId);
        return result;
    }

    // Object that packages milestone information including milestone record and picklists.
    // NOTE: Learned the hard way that this class can only contain one embedded class - any others aren't transmitted to lightning components.
    public with sharing class MilestoneInfo {
        @AuraEnabled
        public Milestone__c m;
        @AuraEnabled
        public Id gmDataId;
        @AuraEnabled
        public Map<String, List<String>> picklists;
        @AuraEnabled
        public List<Review_Form_Component__c> reviewComponents = new List<Review_Form_Component__c>();

        public MilestoneInfo(Id mId) {
            // Fetch milestone record.
            m = (Milestone__c) Utilities.fetchRecord(
                'Milestone__c',
                mId,
                new List<String>{
                    'Milestone_Spec__r.Review_form__c',
                    'Proposal__r.Account__c'
                }
            );
            Id propId = m.Proposal__c;
            // Grab GM Data id for the proposal.
            GM_Data__c[] gmDatas = [
                SELECT Id
                FROM GM_Data__c
                WHERE Proposal__c = :propId
            ];
            // If there's no gm data for the proposal, then build a new one.
            if (gmDatas.size() == 0) {
                insert new GM_Data__c(
                    Proposal__c = propId,
                    Account__c = m.Proposal__r.Account__c
                );
                gmDataId = [
                    SELECT Id
                    FROM GM_Data__c
                    WHERE Proposal__c = :propId
                ][0]
                .Id;
            } else {
                gmDataId = gmDatas[0].Id;
            }
            // Look up values in picklists at the time the record is created, so they're up to date.
            picklists = Utilities.getPicklists('Milestone__c');

            // Stash the review form components for the appropriate milestorne review form.
            // Use the linked milestone spec's review form if any, else the (active) one named 'Milestone'.
            Id revFormId = m.Milestone_Spec__r.Review_form__c;
            String whereClause =
                'WHERE Active__c = true AND ' +
                (revFormId != null
                    ? 'Id = \'' + revFormId + '\''
                    : 'Name = \'Milestone\'');
            // Fetch review form and components.
            Review_Form__c[] reviewForms = (Review_Form__c[]) Utilities.fetchRecords(
                'Review_Form__c',
                whereClause,
                new List<String>{
                    Utilities.buildChildSubQuery(
                        'Review_Form_Component__c',
                        'Review_Form_Components__r',
                        'WHERE Active__c = true ORDER BY Sort_number__c'
                    )
                }
            );
            if (reviewForms.size() > 0) {
                reviewComponents = reviewForms[0].Review_Form_Components__r;
            }
        }
    }

    @AuraEnabled
    public static Milestone__c saveMilestoneInfo(Milestone__c m, GM_Data__c d) {
        system.debug('In saveMilestoneInfo: m = ' + JSON.serialize(m));
        // Save the GMData and milestone records and return the result (possibly errors).
        saveGMData(d);
        Milestone__c result = saveMilestone(m);
        return result;
    }

    private static Milestone__c saveMilestone(Milestone__c m) {
        update m;
        return m;
    }

    private static GM_Data__c saveGMData(GM_Data__c gmData) {
        update gmData;
        return gmData;
    }

    /**********************************
     * For use in VisualForce pages
     *********************************/

    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;

    public MilestoneController(
        ApexPages.StandardController standardController
    ) {
        this.standardController = standardController;
        this.selRecs = fetchRecords(new Set<Id>{ standardController.getId() });
        this.templates = Utilities.templatesMenu(
            objectName,
            START,
            selRecs,
            statusFieldName
        );
    }

    public MilestoneController(
        ApexPages.StandardSetController standardSetController
    ) {
        this.standardSetController = standardSetController;
        Map<Id, Milestone__c> selMap = new Map<Id, Milestone__c>(
            (List<Milestone__c>) standardSetController.getSelected()
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
    private static String objectName = 'Milestone__c';
    private static final String START = '--Select Template--';
    private static String statusFieldName = 'Proposal__r.Status_numeric__c';
    private List<Milestone__c> selRecs;
    public List<selectOption> templates { get; private set; }
    public String selectedTemplate { get; set; }
    {
        selectedTemplate = START;
    }
    public List<Letter__c> newLetters = new List<Letter__c>();

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
        Set<Id> selIds;
        if (standardSetController != null) {
            Map<Id, Milestone__c> selMap = new Map<Id, Milestone__c>(
                (List<Milestone__c>) standardSetController.getSelected()
            );
            selIds = selMap.keySet();
        } else {
            selIds = new Set<Id>{ standardController.getId() };
        }
        newLetters = buildLetters0(selIds, selectedTemplate, false);
        // Changes have been saved; jump to the new letter if there's only one.
        if (standardController != null && newLetters.size() == 1)
            return Utilities.pageReferenceForRecord(newLetters[0]);
        else
            return doCancel(); // Stay in current layout.
    }

    // Build and reset letters for given milestones (non-VF context).
    // The shape with ids parameter is for external callers; with records parameter is called from VF.
    public static List<Letter__c> buildLetters0(
        Set<Id> selIds,
        String selectedTemplate,
        Boolean emailFlg
    ) {
        return buildLetters0(fetchRecords(selIds), selectedTemplate, emailFlg);
    }
    public static List<Letter__c> buildLetters0(
        Milestone__c[] selRecs,
        String selectedTemplate,
        Boolean emailFlg
    ) {
        Set<Id> accIds = new Set<Id>();
        for (Milestone__c gr : selRecs) {
            Id accId = gr.Proposal__r.Account__c;
            if (accId != null)
                accIds.add(accId);
        }
        Map<Id, List<String>> emails = AccountController.emailsForAccounts(
            accIds
        );
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName(
            'Template__c',
            selectedTemplate
        );
        List<Letter__c> ls = new List<Letter__c>();
        for (Milestone__c r : selRecs) {
            List<String> es = emails.get(r.Proposal__r.Account__c);
            ls.add(
                new Letter__c(
                    Template__c = templateId,
                    Account__c = r.Proposal__r.Account__c,
                    Account_owner__c = r.Proposal__r.Account__r.OwnerId,
                    Letter_owner__c = UserInfo.getUserId(),
                    Milestone__c = r.Id,
                    Proposal__c = r.Proposal__c,
                    Region__c = r.Proposal__r.Region__c,
                    Custom_Reqs__c = r.Proposal__r.Custom_Reqs__c,
                    Emails__c = (es == null)
                        ? ''
                        : Utilities.stringJoinWithCharLimit(es, ',', 255)
                )
            );
        }
        if (ls.size() > 0) {
            insert ls;
            system.debug('buildLetters0: ls = ' + JSON.serialize(ls));
            // Reset the new letters.
            Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(ls);
            LetterController.resetLetters0(lMap.keySet(), emailFlg);
        }
        return ls;
    }

    // Get records for given ids.
    static private Milestone__c[] fetchRecords(Set<Id> ids) {
        system.debug('fetchRecords: ids = ' + JSON.serialize(ids));
        return [
            SELECT
                Id,
                Type__c,
                Proposal__c,
                Proposal__r.Account__c,
                Proposal__r.Account__r.OwnerId,
                Proposal__r.Status_numeric__c,
                Proposal__r.Region__c,
                Proposal__r.Custom_Reqs__c
            FROM Milestone__c
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

    // Build a new letter for the given milestone based on the given template.
    // Then email the letter.
    public static void buildAndEmailLetter(Id mId, Id templateId) {
        Template__c template = [
            SELECT Id, Name
            FROM Template__c
            WHERE Id = :templateId
        ];
        buildLetters0(new Set<Id>{ mId }, template.Name, true);
    }

    // Called to update fields in milestone record when a letter is sent.
    public static void letterSent(Id letterId) {
        Letter__c let = [
            SELECT Id, Date_sent__c, Template_name__c, Milestone__c
            FROM Letter__c
            WHERE Id = :letterId
        ];
        if (let.Date_sent__c == null || let.Milestone__c == null)
            return; // Bail if we shouldn't be here.
        Milestone__c m = [
            SELECT Id
            FROM Milestone__c
            WHERE Id = :let.Milestone__c
        ];
        String tName = let.Template_name__c;
        // Update appropriate date field in milestone record.
        if (tName == 'Milestone acknowledgement letter')
            m.Date_acknowledged__c = let.Date_sent__c;
        else if (tName == 'Milestone reminder letter')
            m.Date_reminder_sent__c = let.Date_sent__c;
        else if (tName == 'Milestone overdue letter')
            m.Date_overdue_letter_sent__c = let.Date_sent__c;
        else if (tName == 'Milestone follow up')
            m.Date_follow_up_letter_sent__c = let.Date_sent__c;
        // Update the counts of reminder/overdue letters sent.
        Letter__c[] lets = [
            SELECT Id, Template_name__c
            FROM Letter__c
            WHERE Milestone__c = :m.Id
        ];
        m.Num_overdue_notices_sent__c = 0;
        m.Num_reminders_sent__c = 0;
        for (Letter__c l : lets) {
            if (let.Template_name__c.contains('reminder letter'))
                m.Num_reminders_sent__c += 1;
            if (let.Template_name__c.contains('overdue letter'))
                m.Num_overdue_notices_sent__c += 1;
        }
        update m;
    }

    // Build new milestones for an awarded proposal.
    public static void buildMilestones(Id propId) {
        sObject[] milestonesToInsert = new List<sObject>(); // New milestone records
        Proposal__c p = (Proposal__c) Utilities.fetchRecord(
            'Proposal__c',
            propId,
            new List<String>{ '(SELECT Id FROM Milestones__r)' }
        );
        system.debug(
            'buildMilestones: propId = ' +
            propId +
            '; p.Amount_awarded__c = ' +
            p.Amount_awarded__c
        );
        // Bail if proposal hasn't been awarded, already has milestones, or doesn't have custom reqs.
        if (
            p.Date_awarded__c == null ||
            p.Milestones__r.size() > 0 ||
            p.Custom_Reqs__c == null
        )
            return;
        // Gather milestone specs.
        Milestone_Spec__c[] mSpecs = (Milestone_Spec__c[]) Utilities.fetchChildRecords(
            'Milestone_Spec__c',
            p.Custom_Reqs__c,
            'Custom_Reqs__c',
            null
        );
        // Track latest milestone date due
        Date latestDateDue;
        // Build a milestone for each milestone spec.
        for (Milestone_Spec__c mSpec : mSpecs) {
            system.debug('buildMilestones in mSpecs loop: mSpec = ' + mSpec);
            // Build new milestone with projected due date and (if payment milestone) planned amount
            Date projectedDateDue = mSpec.Date_due__c != null
                ? mSpec.Date_due__c
                : mSpec.Num_months_due__c != null
                        ? p.Date_awarded__c.addDays(
                                (Integer) (365 /
                                12 *
                                mSpec.Num_months_due__c)
                            )
                        : null;
            if (latestDateDue == null || projectedDateDue > latestDateDue)
                latestDateDue = projectedDateDue;
            String extId =
                p.Id +
                '-' +
                mSpec.Id +
                '-' +
                Utilities.generateRandomString(10);
            Milestone__c m = new Milestone__c(
                Proposal__c = p.Id,
                GM_Data__c = p.GM_Data__c,
                Type__c = mSpec.Type__c,
                Milestone_spec__c = mSpec.Id,
                Time_sensitive__c = mSpec.Time_sensitive_donor_report__c,
                Date_due__c = projectedDateDue,
                ExternalID__c = extId
            );
            milestonesToInsert.add(m);
            // Set planned amount for payment milestones, rounding off to nearest hundredth.
            if (
                mSpec.Type__c == 'Payment' &&
                mSpec.Fraction_of_amount_awarded__c != null
            ) {
                m.Planned_amount__c =
                    Math.round(
                        mSpec.Fraction_of_amount_awarded__c *
                        p.Amount_awarded__c *
                        100
                    ) / 100;
            }
        }
        system.debug(
            'buildMilestones: milestonesToInsert.size() = ' +
            milestonesToInsert.size()
        );
        // Consider changing to batch creation, especially if custom reqs specify many milestones.
        if (milestonesToInsert.size() > 0)
            insert milestonesToInsert;
        // Update proposal to ensure that lookup fields reflect the new milestones
        ProposalUpdate.updateProposal(p.Id, true);
    }
}