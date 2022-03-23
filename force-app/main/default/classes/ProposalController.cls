public with sharing class ProposalController {
    /**********************************
     * For use in Lightning components
     *********************************/

    @AuraEnabled
    public static ProposalInfo getProposalInfo(Id propId) {
        ProposalInfo result = new ProposalInfo(propId);
        return result;
    }

    // Object that packages proposal information including proposal record and picklists.
    // NOTE: Learned the hard way that this class can only contain one embedded class - any others aren't transmitted to lightning components.
    // So have to fetch GM Data and ClassificationInfo records separately.
    public with sharing class ProposalInfo {
        @AuraEnabled
        public Proposal__c prop;
        @AuraEnabled
        public Id gmDataId;
        @AuraEnabled
        public Map<String, List<String>> picklists;
        @AuraEnabled
        public String[] declineReasonNames,
            portfolioNames,
            selectedPortfolioNames,
            unselectedPortfolioNames;
        @AuraEnabled
        public String selectedDeclineReasonName,
            selectedPortfolioIdsPacked;
        @AuraEnabled
        public Map<Id, String> declineReasonNameMap,
            portfolioNameMap;
        @AuraEnabled
        public List<Review_Form_Component__c> reviewComponents = new List<Review_Form_Component__c>();

        public ProposalInfo(Id propId) {
            // Fetch proposal record.
            prop = (Proposal__c) Utilities.fetchRecord(
                'Proposal__c',
                propId,
                new List<String>{
                    'Custom_Reqs__r.Proposal_review_form__c',
                    'Account__r.Name'
                }
            );
            // Grab GM Data id for the proposal.
            GM_Data__c[] gmDatas = [
                SELECT Id
                FROM GM_Data__c
                WHERE Proposal__c = :propId
            ];
            // If there's no gm data for this proposal, then build a new one.
            if (gmDatas.size() == 0) {
                insert new GM_Data__c(
                    Proposal__c = propId,
                    Account__c = prop.Account__c
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
            picklists = Utilities.getPicklists('Proposal__c');

            setDeclineReasonFields();
            setPortfolioFields();
            // Stash the review form components for the appropriate proposal review form.
            // Use the linked custom req's review form if any, else the (active) one named 'Proposal'.
            Id revFormId = prop.Custom_Reqs__r.Proposal_review_form__c;
            String whereClause =
                'WHERE Active__c = true AND ' +
                (revFormId != null
                    ? 'Id = \'' + revFormId + '\''
                    : 'Name = \'Proposal\'');
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

        private void setDeclineReasonFields() {
            // Set fields for decline reason names and the currently selected decline reason name.
            Map<Id, Decline_Reason__c> drMap = new Map<Id, Decline_Reason__c>(
                [
                    SELECT Id, Name, For_proposal__c
                    FROM Decline_Reason__c
                    WHERE Active__c = true
                    ORDER BY Name
                ]
            );
            declineReasonNames = new List<String>();
            for (Decline_Reason__c dr : drMap.values())
                declineReasonNames.add(dr.Name);
            if (declineReasonNames.size() > 0) {
                declineReasonNames.add(0, ''); // Add blank entry at the front.
                selectedDeclineReasonName = prop.Decline_reason__c != null
                    ? drMap.get(prop.Decline_reason__c).Name
                    : null;
            }
        }

        private void setPortfolioFields() {
            // Fetch portfolio names and the currently selected ones.
            Map<Id, Portfolio__c> pMap = new Map<Id, Portfolio__c>(
                [
                    SELECT Id, Type__c, Name_with_type__c
                    FROM Portfolio__c
                    WHERE Type__c = 'Priority' AND Active__c = true
                    ORDER BY Name_with_type__c
                ]
            );
            portfolioNameMap = new Map<Id, String>();
            for (Portfolio__c p : pMap.values())
                portfolioNameMap.put(p.Id, p.Name_with_type__c);
            portfolioNames = portfolioNameMap.values();
            system.debug(
                'ProposalController.apxc setPortfolioFields: portfolioNameMap = ' +
                JSON.serialize(portfolioNameMap)
            );
            if (portfolioNames.size() > 0)
                portfolioNames.add(0, ''); // Add blank entry at the front.
            // Fetch and stash priority portfolios that have been assigned to this proposal.
            Map<Id, Portfolio__c> pAssigned = new Map<Id, Portfolio__c>(
                [
                    SELECT Id
                    FROM Portfolio__c
                    WHERE
                        Id IN (
                            SELECT Portfolio__c
                            FROM Portfolio_Assignment__c
                            WHERE
                                Proposal__c = :prop.Id
                                AND Portfolio__r.Type__c = 'Priority'
                        )
                ]
            );
            // Stash selected names and ids.
            List<id> ids = new List<Id>();
            selectedPortfolioNames = new List<String>();
            for (Portfolio__c p : pAssigned.values()) {
                String pName = portfolioNameMap.get(p.Id);
                ids.add(p.Id);
                selectedPortfolioNames.add(pName);
            }
            selectedPortfolioIdsPacked = String.join(ids, ';');
            // Stash the unselected names.
            unselectedPortfolioNames = new List<String>();
            for (Id pId : portfolioNameMap.keySet()) {
                system.debug(
                    'pId = ' +
                    pId +
                    '; portfolioNameMap.get(pId) = ' +
                    portfolioNameMap.get(pId)
                );
                if (!pAssigned.containsKey(pId))
                    unselectedPortfolioNames.add(portfolioNameMap.get(pId));
            }
        }
    }

    @AuraEnabled
    public static ClassificationInfo getClassificationInfo(
        String cType,
        Id propId
    ) {
        ClassificationInfo result = new ClassificationInfo(cType, propId);
        return result;
    }

    // Object that packages information (Ids and names) regarding selected and unselected classifications
    public with sharing class ClassificationInfo {
        @AuraEnabled
        public String selectedIdsPacked;
        @AuraEnabled
        public String[] names,
            selectedNames,
            unselectedNames;
        @AuraEnabled
        public Map<Id, String> nameMap;
        public ClassificationInfo(String cType, Id pId) {
            // Fetch classification names of given type and the currently selected ones.
            Map<Id, Classification__c> cMap = new Map<Id, Classification__c>(
                [
                    SELECT Id, Name_with_prefix__c
                    FROM Classification__c
                    WHERE Type__c = :cType AND Active__c = true
                    ORDER BY Name_with_prefix__c
                ]
            );
            nameMap = new Map<Id, String>();
            for (Classification__c c : cMap.values())
                nameMap.put(c.Id, c.Name_with_prefix__c);
            names = nameMap.values();
            if (names.size() > 0)
                names.add(0, ''); // Add blank entry at the front.
            // Fetch and stash classifications that have been assigned to this proposal.
            Map<Id, Classification__c> cAssigned = new Map<Id, Classification__c>(
                [
                    SELECT Id
                    FROM Classification__c
                    WHERE
                        Id IN (
                            SELECT Classification__c
                            FROM Classification_Assign__c
                            WHERE Proposal__c = :pId
                        )
                        AND Type__c = :cType
                ]
            );
            // Stash selected names and ids.
            List<id> ids = new List<Id>();
            selectedNames = new List<String>();
            for (Classification__c c : cAssigned.values()) {
                String cName = nameMap.get(c.Id);
                ids.add(c.Id);
                selectedNames.add(cName);
            }
            selectedIdsPacked = String.join(ids, ';');
            // Stash the unselected names.
            unselectedNames = new List<String>();
            for (Id cId : nameMap.keySet()) {
                system.debug(
                    'cId = ' +
                    cId +
                    '; nameMap.get(cId) = ' +
                    nameMap.get(cId)
                );
                if (!cAssigned.containsKey(cId))
                    unselectedNames.add(nameMap.get(cId));
            }
        }
    }

    // This method has a "1" in the name, because the String parameters can't be passed if it
    // is just called "saveProposalInfo".  Is "saveProposalInfo" reserved because ProposalInfo is a class name?
    // NOTE: When I modify the parameters, they seem to be unable to receive data from components.  Work-around was to make a new version of the method.  How weird is that?
    @AuraEnabled
    public static Proposal__c saveProposalInfo1(
        Proposal__c p,
        GM_Data__c d,
        String populationIdsPacked,
        String strategyIdsPacked,
        String issueIdsPacked,
        String portfolioIdsPacked
    ) {
        system.debug(
            'In saveProposalInfo1: p = ' +
            JSON.serialize(p) +
            '; d = ' +
            JSON.serialize(d) +
            '; issueIdsPacked = ' +
            issueIdsPacked +
            '; strategyIdsPacked = ' +
            strategyIdsPacked +
            '; portfolioIdsPacked = ' +
            portfolioIdsPacked
        );
        // Gather classification assigns to delete/insert of each of the three types.
        List<Classification_Assign__c> cAssignsToDelete = new List<Classification_Assign__c>();
        List<Classification_Assign__c> cAssignsToInsert = new List<Classification_Assign__c>();
        saveClassificationAssigns(
            p,
            'Population',
            populationIdsPacked == null ? '' : populationIdsPacked,
            cAssignsToDelete,
            cAssignsToInsert
        );
        saveClassificationAssigns(
            p,
            'Issue',
            issueIdsPacked == null ? '' : issueIdsPacked,
            cAssignsToDelete,
            cAssignsToInsert
        );
        saveClassificationAssigns(
            p,
            'Strategy',
            strategyIdsPacked == null ? '' : strategyIdsPacked,
            cAssignsToDelete,
            cAssignsToInsert
        );
        if (cAssignsToDelete.size() > 0)
            delete cAssignsToDelete;
        if (cAssignsToInsert.size() > 0)
            insert cAssignsToInsert;
        savePortfolioAssigns(p, portfolioIdsPacked);
        // Save the GMData and Proposal records and return the result (possibly errors).
        saveGMData(d);
        Proposal__c result = saveProposal(p);
        return result;
    }

    private static Proposal__c saveProposal(Proposal__c prop) {
        update prop;
        return prop;
    }

    private static GM_Data__c saveGMData(GM_Data__c gmData) {
        update gmData;
        return gmData;
    }

    private static void saveClassificationAssigns(
        Proposal__c p,
        String cType,
        String selectedIdsPacked,
        Classification_Assign__c[] toDelete,
        Classification_Assign__c[] toInsert
    ) {
        system.debug(
            'In saveClassificationAssigns: p = ' +
            JSON.serialize(p) +
            '; cType = ' +
            cType +
            '; selectedIdsPacked = ' +
            selectedIdsPacked
        );
        Id pId = p.Id;
        // Add/remove joins to align with new selections.
        // Get current assignments.
        Map<Id, Classification_Assign__c> cJoins = new Map<Id, Classification_Assign__c>(
            [
                SELECT Id, Classification__c
                FROM Classification_Assign__c
                WHERE
                    Proposal__c = :pId
                    AND Classification__r.Type__c = :cType
                    AND Classification__r.Active__c = true
            ]
        );
        system.debug(
            'In saveClassificationAssigns: cJoins = ' + JSON.serialize(cJoins)
        );
        // Stash current classification ids.
        Set<Id> currentIds = new Set<Id>();
        for (Classification_Assign__c ca : cJoins.values())
            currentIds.add(ca.Classification__c);
        // Get selected classifications.
        Set<String> setIds = new Set<String>(selectedIdsPacked.split(';', 0));
        system.debug(
            'In saveClassificationAssigns: setIds = ' + JSON.serialize(setIds)
        );
        // Augment list of classifications to delete - they were assigned, but are no longer selected.
        for (Classification_Assign__c ca : cJoins.values()) {
            if (!setIds.contains(String.valueof(ca.Classification__c)))
                toDelete.add(ca);
        }
        system.debug(
            'In saveClassificationAssigns: toDelete = ' +
            JSON.serialize(toDelete)
        );
        // Augment list of classifications to insert - they weren't originally assigned, but are now selected.
        for (String s : setIds) {
            if (String.isBlank(s))
                continue;
            Id i = Id.valueOf(s);
            if (!currentIds.contains(i))
                toInsert.add(
                    new Classification_Assign__c(
                        Classification__c = i,
                        Proposal__c = pId
                    )
                );
        }
        system.debug(
            'In saveClassificationAssigns: toInsert = ' +
            JSON.serialize(toInsert)
        );
    }

    private static void savePortfolioAssigns(
        Proposal__c p,
        String selectedIdsPacked
    ) {
        system.debug(
            'In savePortfolioAssigns: p = ' +
            JSON.serialize(p) +
            '; selectedIdsPacked = ' +
            selectedIdsPacked
        );
        Id pId = p.Id;
        // Add/remove priority portfolio joins to align with new selections.
        // Get current assignments.
        Map<Id, Portfolio_Assignment__c> pJoins = new Map<Id, Portfolio_Assignment__c>(
            [
                SELECT Id, Portfolio__c
                FROM Portfolio_Assignment__c
                WHERE Proposal__c = :pId AND Portfolio__r.Type__c = 'Priority'
            ]
        );
        system.debug(
            'In savePortfolioAssigns: pJoins = ' + JSON.serialize(pJoins)
        );
        // Stash current assignment ids.
        Set<Id> currentIds = new Set<Id>();
        for (Portfolio_Assignment__c pa : pJoins.values())
            currentIds.add(pa.Portfolio__c);
        // Get selected assignments.
        Set<String> setIds = new Set<String>(selectedIdsPacked.split(';', 0));
        system.debug(
            'In savePortfolioAssigns: setIds = ' + JSON.serialize(setIds)
        );
        // Build list of assignments to delete - they were assigned, but are no longer selected.
        List<Portfolio_Assignment__c> toDelete = new List<Portfolio_Assignment__c>();
        for (Portfolio_Assignment__c pa : pJoins.values()) {
            if (!setIds.contains(String.valueof(pa.Portfolio__c)))
                toDelete.add(pa);
        }
        system.debug(
            'In savePortfolioAssigns: toDelete = ' + JSON.serialize(toDelete)
        );
        // Build list of portfolios to insert - they weren't originally assigned, but are now selected.
        List<Portfolio_Assignment__c> toInsert = new List<Portfolio_Assignment__c>();
        for (String s : setIds) {
            if (String.isBlank(s))
                continue;
            Id i = Id.valueOf(s);
            if (!currentIds.contains(i))
                toInsert.add(
                    new Portfolio_Assignment__c(
                        Portfolio__c = i,
                        Proposal__c = pId
                    )
                );
        }
        system.debug(
            'In savePortfolioAssigns: toInsert = ' + JSON.serialize(toInsert)
        );
        if (toDelete.size() > 0)
            delete toDelete;
        if (toInsert.size() > 0)
            insert toInsert;
    }

    /**********************************
     * For general use
     *********************************/

    // Build a new letter for the given proposal based on the given template.
    // Then email the letter.
    public static void buildAndEmailLetter(Id propId, Id templateId) {
        Template__c template = [
            SELECT Id, Name
            FROM Template__c
            WHERE Id = :templateId
        ];
        buildLetters0(new Set<Id>{ propId }, template.Name, true);
    }

    // Copy classification assigns from given profile to given proposal - only include ones the proposal doesn't already have.
    public static void copyClassificationAssignsFromProfile(
        Id propId,
        Id profileId
    ) {
        // Fetch the proposal's current classifications.
        Classification_Assign__c[] propClassAssigns = [
            SELECT Id, Classification__c
            FROM Classification_Assign__c
            WHERE Proposal__c = :propId
        ];
        Set<Id> classIds = new Set<Id>();
        for (Classification_Assign__c cAssign : propClassAssigns)
            classIds.add(cAssign.Classification__c);
        // Get the profile's classification assigns.
        List<Classification_Profile_Assign__c> profClassAssigns = new List<Classification_Profile_Assign__c>(
            [
                SELECT Id, Classification__c, Rank__c
                FROM Classification_Profile_Assign__c
                WHERE Profile__c = :profileId
            ]
        );
        // Build classification joins for the proposal, omitting those it already has.
        List<Classification_Assign__c> newPropClassAssigns = new List<Classification_Assign__c>();
        for (Classification_Profile_Assign__c cAssign : profClassAssigns) {
            if (!classIds.contains(cAssign.Classification__c)) {
                newPropClassAssigns.add(
                    new Classification_Assign__c(
                        Classification__c = cAssign.Classification__c,
                        Proposal__c = propId,
                        Rank__c = cAssign.Rank__c
                    )
                );
            }
        }
        if (newPropClassAssigns.size() > 0)
            insert newPropClassAssigns;
    }

    /**********************************
     * For use in VisualForce pages
     *********************************/

    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;

    public ProposalController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
        this.selRecs = fetchRecords(new Set<Id>{ standardController.getId() });
        this.templates = Utilities.templatesMenu(
            objectName,
            START,
            selRecs,
            statusFieldName
        );
    }

    public ProposalController(
        ApexPages.StandardSetController standardSetController
    ) {
        this.standardSetController = standardSetController;
        Map<Id, Proposal__c> selMap = new Map<Id, Proposal__c>(
            (List<Proposal__c>) standardSetController.getSelected()
        );
        this.selRecs = fetchRecords(selMap.keySet());
        this.templates = Utilities.templatesMenu(
            objectName,
            START,
            selRecs,
            statusFieldName
        );
    }

    public with sharing class buildSubmissionsException extends Exception {
    }

    // Build the menu of admissible correspondence templates for this object.
    private static String objectName = 'Proposal__c';
    private static final String START = '--Select Template--';
    private static String statusFieldName = 'Status_numeric__c';
    private List<Proposal__c> selRecs;
    public List<selectOption> templates { get; private set; }
    public String submissions { get; private set; } // Combined submission documents for selected props
    public String selectedTemplate { get; set; }
    {
        selectedTemplate = START;
    }
    public List<Letter__c> newLetters = new List<Letter__c>();

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
        newLetters = buildLetters0(selIds, selectedTemplate, false);
        // Changes have been saved; jump to the new letter if there's only one.
        if (standardController != null && newLetters.size() == 1)
            return Utilities.pageReferenceForRecord(newLetters[0]);
        else
            return doCancel(); // Stay in current layout.
    }

    // Build and reset letters for given proposals (non-VF context).
    // The shape with ids parameter is for external callers; with records parameter is called from VF.
    public static List<Letter__c> buildLetters0(
        Set<Id> selIds,
        String selectedTemplate,
        Boolean emailFlg
    ) {
        return buildLetters0(fetchRecords(selIds), selectedTemplate, emailFlg);
    }
    public static List<Letter__c> buildLetters0(
        Proposal__c[] selRecs,
        String selectedTemplate,
        Boolean emailFlg
    ) {
        Set<Id> accIds = new Set<Id>();
        for (Proposal__c p : selRecs) {
            Id accId = p.Account__c;
            if (accId != null)
                accIds.add(accId);
        }
        Map<Id, List<String>> emails = Utilities.emailsForAccounts(
            accIds
        );
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName(
            'Template__c',
            selectedTemplate
        );
        List<Letter__c> ls = new List<Letter__c>();
        for (Proposal__c r : selRecs) {
            List<String> es = emails.get(r.Account__c);
            ls.add(
                new Letter__c(
                    Template__c = templateId,
                    Account__c = r.Account__c,
                    Account_owner__c = r.Account__r.OwnerId,
                    Letter_owner__c = UserInfo.getUserId(),
                    Proposal__c = r.Id,
                    Payment_Method__c = r.Current_payment_method__c,
                    Region__c = r.Region__c,
                    Custom_Reqs__c = r.Custom_Reqs__c,
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

    // Build and combine submission materials for selected proposals.
    // Currently (5/7/19) this functionality is hard-wired rather than using a template to specify fields and layout.
    public PageReference buildSubmissions() {
        // Grab selected proposals, including necessary fields.
        Set<Id> selIds = getSelectedIds();
        Proposal__c[] props = [
            SELECT
                Name,
                Account__r.Name,
                Account__r.GM_country__r.Name,
                Account__r.GM_region__r.Name,
                Account__r.Highlights__c,
                Account__r.Website,
                Account__r.Social_media__c,
                Description__c,
                Amount_awarded__c,
                Amount_recommended__c,
                Thematic_priority__c,
                Staff_analysis__c,
                Reason_for_soliciting_committee_approval__c,
                Rationale_for_committee_approval__c
            FROM Proposal__c
            WHERE Id IN :selIds
        ];
        // Build the submission text for each proposal.
        String[] propTexts = new List<String>();
        String alert = '**MISSING**';
        String amountAlert = '**EITHER AMOUNT OR AMOUNT RECOMMENDED MUST BE NON-BLANK**';
        for (Proposal__c p : props) {
            Account a = p.Account__r;
            Boolean missingAmount =
                p.Amount_awarded__c == null &&
                p.Amount_recommended__c == null;
            propTexts.add(
                '<li>' +
                '<p><b>Organization name</b>: ' +
                a.Name +
                '</p>' +
                '<p><b>Country</b>: ' +
                (a.GM_country__r.Name != null ? a.GM_country__r.Name : 'N/A') +
                ' (' +
                a.GM_region__r.Name +
                ')</p>' +
                '<p><b>Proposal #</b>: ' +
                p.Name +
                '</p>' +
                '<p><b>Organization purpose</b>: ' +
                display(a.Highlights__c, alert) +
                '</p>' +
                '<p><b>Website</b>: ' +
                (a.Website != null
                    ? '<a href="' + a.Website + '">' + a.Website + '</a>'
                    : '') +
                '</p>' +
                '<p><b>Social media</b>: ' +
                display(a.Social_media__c) +
                '</p>' +
                '<p><b>Grant request</b>: ' +
                display(p.Description__c, alert) +
                '</p>' +
                '<p><b>Grant amount</b>: ' +
                (p.Amount_awarded__c != null
                    ? '$' + Utilities.formatCurrency(p.Amount_awarded__c)
                    : (missingAmount ? amountAlert : '')) +
                '</p>' +
                '<p><b>Grant amount recommended</b>: ' +
                (p.Amount_recommended__c != null
                    ? '$' + Utilities.formatCurrency(p.Amount_recommended__c)
                    : (missingAmount ? amountAlert : '')) +
                '</p>' +
                '<p><b>Alignment with Global Fund for Women priorities</b>: ' +
                display(p.Thematic_priority__c, alert) +
                '</p>' +
                '<p><b>Staff analysis</b>: ' +
                display(p.Staff_analysis__c, alert) +
                '</p>' +
                '<p><b>Reason for soliciting Board/EC approval</b>: ' +
                display(p.Reason_for_soliciting_committee_approval__c, alert) +
                '</p>' +
                '<p><b>Rationale for Board/EC approval</b>: ' +
                display(p.Rationale_for_committee_approval__c, alert) +
                '</p>' +
                '<p>&nbsp;</p>' +
                '</li>'
            );
        }
        submissions = '<ol>' + String.join(propTexts, '') + '</ol>';
        return null;
    }

    // Display a value if non-blank.  Else display alert if any, else blank.
    private String display(String value) {
        return display(value, null);
    }
    private String display(String value, String alert) {
        return value != null ? value : (alert != null ? alert : '');
    }

    // Perform OFAC lookup using batch class and batch size of 1 (processing each prop id requires callouts).
    public PageReference performOFACLookupBatch() {
        Set<Id> selIds = getSelectedIds();
        if (selIds.size() > 0)
            Id jobId = Database.executeBatch(new OFACLookupBatch(selIds), 1);
        return doCancel();
    }

    // Get records for given ids.
    static private Proposal__c[] fetchRecords(Set<Id> ids) {
        system.debug('fetchRecords: ids = ' + JSON.serialize(ids));
        return [
            SELECT
                Id,
                Status_numeric__c,
                Account__c,
                Account__r.OwnerId,
                Region__c,
                Custom_Reqs__c,
                Current_payment_method__c
            FROM Proposal__c
            WHERE Id IN :ids
        ];
    }

    public PageReference doCancel() {
        return (standardSetController != null)
            ? standardSetController.cancel()
            : standardController.cancel();
    }

    private Set<Id> getSelectedIds() {
        Set<Id> selIds;
        if (standardSetController != null) {
            Map<Id, Proposal__c> selMap = new Map<Id, Proposal__c>(
                (List<Proposal__c>) standardSetController.getSelected()
            );
            selIds = selMap.keySet();
        } else {
            selIds = new Set<Id>{ standardController.getId() };
        }
        return selIds;
    }
}