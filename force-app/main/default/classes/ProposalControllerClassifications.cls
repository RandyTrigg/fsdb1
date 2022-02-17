public with sharing class ProposalControllerClassifications {
    private ApexPages.StandardController standardController;

    public ProposalControllerClassifications(
        ApexPages.StandardController standardController
    ) {
        this.standardController = standardController;
    }

    public Proposal__c prop;
    public Proposal__c getProp() {
        return [
            SELECT Prop_num_with_renewal__c, Account__r.Name
            FROM Proposal__c
            WHERE Id = :standardController.getId()
        ];
    }
    // Selected IDs are mapped to a hidden input field on the page, and set by jquery.
    public String selectedIds { get; set; }

    // Wrapper class to prevent security breaches when injecting the HTML for the checkbox tags.
    // Source: http://www.laceysnr.com/2012/11/checkboxes-and-columns-line-em-up.html
    @TestVisible
    private class CCheckbox {
        public String label { get; set; }
        public String HTML { get; private set; }

        public CCheckbox(
            String label,
            String value,
            String title,
            Boolean isChecked
        ) {
            this.label = label;
            this.HTML =
                '<input type="checkbox" class="cboxChoice" onClick="saveValues();" id="' +
                value +
                '" title="' +
                title +
                '" ' +
                (isChecked ? 'checked' : '') +
                '/>';
        }
    }

    // Build three lists of checkboxes for admissible classifications.
    public List<CCheckbox> populations, strategies, issues;
    public List<CCheckbox> getPopulations() {
        return buildCheckboxes('Population');
    }
    public List<CCheckbox> getStrategies() {
        return buildCheckboxes('Strategy');
    }
    public List<CCheckbox> getIssues() {
        return buildCheckboxes('Issue');
    }

    // Build HTML for classification checkboxes, including IsChecked for the ones
    // currently assigned to given proposal.
    private List<CCheckbox> buildCheckboxes(String cType) {
        Id propId = standardController.getId();
        system.debug(
            'In buildCheckboxes: cType = ' +
            cType +
            '; propId = ' +
            propId
        );
        // Fetch classifications of given type
        List<Classification__c> cs = new List<Classification__c>(
            [
                SELECT Name_with_prefix__c, Definition__c
                FROM Classification__c
                WHERE Type__c = :cType
                ORDER BY Name_with_prefix__c
            ]
        );
        // Fetch classifications that have been assigned to this proposal.
        Map<Id, Classification__c> assigned = new Map<Id, Classification__c>(
            [
                SELECT Id
                FROM Classification__c
                WHERE
                    Id IN (
                        SELECT Classification__c
                        FROM Classification_Assign__c
                        WHERE Proposal__c = :propId
                    )
                    AND Type__c = :cType
            ]
        );
        system.debug(
            'In buildCheckboxes: cs.size() = ' +
            cs.size() +
            '; assigned.size() = ' +
            assigned.size()
        );
        // Stash list of initially selected IDs.
        //selectedIds = String.join(new List<Id> (assigned.keySet()), ';');
        // Build HTML for checkboxes.
        List<CCheckbox> checkboxes = new List<CCheckbox>();
        for (Classification__c c : cs)
            checkboxes.add(
                new CCheckbox(
                    c.Name_with_prefix__c,
                    c.Id,
                    c.Definition__c,
                    assigned.containsKey(c.Id)
                )
            );
        return checkboxes;
    }

    // Get selected classifications, then insert/delete join records to match.
    public void saveChanges() {
        Id propId = standardController.getId();
        // Get current classification assignments.
        Map<Id, Classification_Assign__c> assigned = new Map<Id, Classification_Assign__c>(
            [
                SELECT Id, Classification__c
                FROM Classification_Assign__c
                WHERE Proposal__c = :propId
            ]
        );
        system.debug('In doSave: assigned = ' + JSON.serialize(assigned));
        // Get selected classifications from VF hidden input field.
        Set<String> setIds = new Set<String>(selectedIds.split(';', 0));
        system.debug(
            'In doSave: selectedIds = ' +
            selectedIds +
            '; setIds = ' +
            JSON.serialize(setIds)
        );
        // Build list of classifications to delete - they were assigned, but are no longer selected.
        List<Classification_Assign__c> toDelete = new List<Classification_Assign__c>();
        for (Classification_Assign__c ca : assigned.values()) {
            if (!setIds.contains(String.valueof(ca.Classification__c)))
                toDelete.add(ca);
        }
        system.debug('In doSave: toDelete = ' + JSON.serialize(toDelete));
        // Build list of classifications to insert - they weren't originally assigned, but are now selected.
        List<Classification_Assign__c> toInsert = new List<Classification_Assign__c>();
        for (String s : setIds) {
            if (String.isBlank(s))
                continue;
            Id i = Id.valueOf(s);
            if (!assigned.containsKey(i))
                toInsert.add(
                    new Classification_Assign__c(
                        Classification__c = i,
                        Proposal__c = propId
                    )
                );
        }
        system.debug('In doSave: toInsert = ' + JSON.serialize(toInsert));
        if (toDelete.size() > 0)
            delete toDelete;
        if (toInsert.size() > 0)
            insert toInsert;
    }

    // Save and return from this page.
    public PageReference doSave() {
        saveChanges();
        return standardController.cancel();
    }

    // Save and stay on this page.
    public PageReference doQuickSave() {
        saveChanges();
        return null;
    }
}