public class GMDataController {
    /**********************************
     * For use in Lightning components
     *********************************/

    // Build structure for a gmData record.
    @AuraEnabled
    public static GMDataInfo getGMDataInfo(Id gmDataId) {
        return new GMDataInfo(gmDataId);
    }

    // Object that packages GM Data information including restricted classifications and picklists.
    public with sharing class GMDataInfo {
        @AuraEnabled
        public GM_Data__c gmData;
        @AuraEnabled
        public Map<String, String[]> picklists;
        @AuraEnabled
        public Portfolio__c portfolio;
        @AuraEnabled
        public Map<String, String> selectedIdsPacked = new Map<String, String>();
        @AuraEnabled
        public Map<String, String[]> selectedNames = new Map<String, List<String>>(),
            unselectedNames = new Map<String, List<String>>();
        @AuraEnabled
        public Map<Id, String> nameMap;
        @AuraEnabled
        public Map<String, List<Indicator__c>> indicatorMap = new Map<String, List<Indicator__c>>();
        @AuraEnabled
        public Map<Id, Indicator_Assign__c> indicatorAssignMap = new Map<Id, Indicator_Assign__c>();
        @AuraEnabled
        // New/changed indicator assignments in review form
        public Map<String, String> indicatorAssignInfo = new Map<String, String>();

        public GMDataInfo(Id gmDataId) {
            if (gmDataId == null)
                return;
            // Get the GM Data record.
            gmData = (GM_Data__c) Utilities.fetchRecord(
                'GM_Data__c',
                gmDataId,
                null
            );
            // Look up values in picklists at the time the GMDataInfo record is created, so they're up to date.
            picklists = Utilities.getPicklists('GM_Data__c');
            // Fetch portfolio if one is linked from the gm data.
            Id portId = gmData.Portfolio__c;
            if (portId != null) {
                portfolio = [
                    SELECT Id, Name
                    FROM Portfolio__c
                    WHERE Id = :portId
                ];

                // Fetch legal restricted classification names, i.e. the ones specified in the portfolio.
                Map<Id, Restricted_Classification_Portfolio__c> rcpMap = new Map<Id, Restricted_Classification_Portfolio__c>(
                    [
                        SELECT
                            Id,
                            Restricted_Classification__c,
                            Restricted_Classification__r.Name,
                            Restricted_Classification__r.Type__c
                        FROM Restricted_Classification_Portfolio__c
                        WHERE Portfolio__c = :portId
                        ORDER BY Restricted_Classification__r.Name
                    ]
                );
                nameMap = new Map<Id, String>();
                for (Restricted_Classification_Portfolio__c c : rcpMap.values())
                    nameMap.put(
                        c.Restricted_Classification__c,
                        c.Restricted_Classification__r.Name
                    );
                // Fetch and stash restricted classifications that have been assigned to this gm data.
                Map<Id, Restricted_Classification__c> cAssigned = new Map<Id, Restricted_Classification__c>(
                    [
                        SELECT Id, Type__c
                        FROM Restricted_Classification__c
                        WHERE
                            Id IN (
                                SELECT Restricted_Classification__c
                                FROM Restricted_Classification_GM_Data__c
                                WHERE GM_Data__c = :gmDataId
                            )
                    ]
                );
                // Stash the names from the portfolio's legal ones that haven't been selected.
                for (
                    Restricted_Classification_Portfolio__c rcp : rcpMap.values()
                ) {
                    Id cId = rcp.Restricted_Classification__c;
                    String type = rcp.Restricted_Classification__r.Type__c;
                    system.debug(
                        'cId = ' +
                        cId +
                        '; nameMap.get(cId) = ' +
                        nameMap.get(cId)
                    );
                    // Ensure that unselected and selected maps have values for each type.
                    if (!unselectedNames.containsKey(type))
                        unselectedNames.put(type, new List<String>());
                    if (!selectedNames.containsKey(type))
                        selectedNames.put(type, new List<String>());
                    if (!cAssigned.containsKey(cId))
                        unselectedNames.get(type).add(nameMap.get(cId));
                }
                // Stash selected names and ids.
                for (Restricted_Classification__c c : cAssigned.values()) {
                    String cName = nameMap.get(c.Id);
                    if (!selectedIdsPacked.containsKey(c.Type__c))
                        selectedIdsPacked.put(c.Type__c, c.Id);
                    else
                        selectedIdsPacked.put(
                            c.Type__c,
                            selectedIdsPacked.get(c.Type__c) +
                            ';' +
                            c.Id
                        );
                    selectedNames.get(c.Type__c).add(cName);
                }
            }
            // Stash indicators in a map indexed by the Type field.
            for (
                Indicator__c i : (Indicator__c[]) Utilities.fetchRecords(
                    'Indicator__c',
                    'WHERE Active__c = true ORDER BY Code__c',
                    null
                )
            ) {
                String fName = i.Type__c;
                if (fName != null) {
                    if (!indicatorMap.containsKey(fName))
                        indicatorMap.put(fName, new List<Indicator__c>());
                    indicatorMap.get(fName).add(i);
                }
            }
            system.debug(
                'GMDataInfo: indicatorMap = ' + JSON.serialize(indicatorMap)
            );
            // Stash indicator assigns in a map indexed by the indicator Id.
            for (
                Indicator_Assign__c ia : (Indicator_Assign__c[]) Utilities.fetchRecords(
                    'Indicator_Assign__c',
                    'WHERE GM_Data__c =  \'' +
                    gmDataId +
                    '\'',
                    null
                )
            )
                indicatorAssignMap.put(ia.Indicator__c, ia);
            system.debug(
                'GMDataInfo: indicatorAssignMap = ' +
                JSON.serialize(indicatorAssignMap)
            );
        }
    }

    // Save a GMDataInfo record, including its restricted classification joins.
    @AuraEnabled
    public static GM_Data__c saveGMDataInfo(String gmDataInfoSerialized) {
        system.debug(
            'saveGMDataInfo: gmDataInfoSerialized = ' +
            JSON.serialize(gmDataInfoSerialized)
        );
        // Deserialize the gmDataInfo record.
        GMDataInfo gmDataInfo = (GMDataInfo) JSON.deserialize(
            gmDataInfoSerialized,
            GMDataInfo.class
        );
        system.debug(
            'saveGMDataInfo: gmDataInfo = ' + JSON.serialize(gmDataInfo)
        );
        GM_Data__c gmData = gmDataInfo.gmData;
        system.debug('saveGMDataInfo: gmData = ' + JSON.serialize(gmData));
        // Get current assignments.
        Map<Id, Restricted_Classification_GM_Data__c> cJoins = new Map<Id, Restricted_Classification_GM_Data__c>(
            [
                SELECT Id, GM_Data__c, Restricted_Classification__c
                FROM Restricted_Classification_GM_Data__c
                WHERE GM_Data__c = :gmData.Id
            ]
        );
        system.debug('saveGMDataInfo: cJoins = ' + JSON.serialize(cJoins));
        // Stash current classification ids.
        Set<Id> currentIds = new Set<Id>();
        for (Restricted_Classification_GM_Data__c j : cJoins.values())
            currentIds.add(j.Restricted_Classification__c);
        // Get selected classification ids after initializing map.
        Set<Id> selIds = new Set<Id>();
        if (gmDataInfo.selectedIdsPacked != null) {
            for (String idsPacked : gmDataInfo.selectedIdsPacked.values())
                for (String s : idsPacked.split(';', 0))
                    if (s.trim().length() > 0)
                        selIds.add(Id.valueOf(s.trim()));
        }
        system.debug('saveGMDataInfo: selIds = ' + JSON.serialize(selIds));
        // Build list of classifications to delete - they were assigned, but are no longer selected.
        List<Restricted_Classification_GM_Data__c> toDelete = new List<Restricted_Classification_GM_Data__c>();
        for (Restricted_Classification_GM_Data__c j : cJoins.values()) {
            Id cId = j.Restricted_Classification__c;
            if (!selIds.contains(cId))
                toDelete.add(j);
        }
        system.debug(
            'In saveGMDataInfo: toDelete = ' + JSON.serialize(toDelete)
        );
        // Build list of classifications to insert - they weren't originally assigned, but are now selected.
        List<Restricted_Classification_GM_Data__c> toInsert = new List<Restricted_Classification_GM_Data__c>();
        for (Id cId : new List<Id>(selIds)) {
            if (!currentIds.contains(cId))
                toInsert.add(
                    new Restricted_Classification_GM_Data__c(
                        Restricted_Classification__c = cId,
                        GM_Data__c = gmData.Id
                    )
                );
        }
        system.debug(
            'In saveGMDataInfo: toInsert = ' + JSON.serialize(toInsert)
        );
        if (toDelete.size() > 0)
            delete toDelete;
        if (toInsert.size() > 0)
            insert toInsert;
        // Update any indicator assigns that have changed.
        updateIndicatorAssigns(gmDataInfo);
        // Save and return the GM Data record.
        update gmData;
        return gmData;
    }

    // Make changes to the current indicator assignments for given GM Data record.
    private static void updateIndicatorAssigns(GMDataInfo gmDataInfo) {
        Indicator_Assign__c[] toInsert = new List<Indicator_Assign__c>(),
            toUpdate = new List<Indicator_Assign__c>(),
            toDelete = new List<Indicator_Assign__c>();
        // Get indicator Ids.
        Map<Id, Indicator__c> inds = new Map<Id, Indicator__c>(
            [
                SELECT Id, GM_Data_field_name__c, Type__c
                FROM Indicator__c
                WHERE Active__c = true
            ]
        );
        Id gmDataId = gmDataInfo.gmData.Id;
        // Gather current indicator assigns.
        List<Indicator_Assign__c> ias = [
            SELECT Id, Indicator__c, GM_Data__c, Quantity__c, Comment__c
            FROM Indicator_Assign__c
            WHERE GM_Data__c = :gmDataId
        ];
        // Gather indicator assigns needing updating.
        Map<Id, Indicator_Assign__c> indAssignsOld = new Map<Id, Indicator_Assign__c>();
        for (Indicator_Assign__c ia : ias)
            indAssignsOld.put(ia.Indicator__c, ia);
        // Convert new assignments to a Map by indicator id.
        Map<String, String> indAssignInfo = gmDataInfo.indicatorAssignInfo;
        Map<Id, String> indAssignsNew = new Map<Id, String>();
        for (String indIdString : indAssignInfo.keySet())
            indAssignsNew.put(
                Id.valueof(indIdString),
                indAssignInfo.get(indIdString)
            );
        system.debug(
            'updateIndicatorAssigns: gmDataId = ' +
            gmDataId +
            '; indAssignsOld = ' +
            JSON.serialize(indAssignsOld) +
            '; indAssignsNew = ' +
            JSON.serialize(indAssignsNew)
        );
        // Track which checkboxes in GM Data need to be set/unset to align with assigned indicators.
        Map<String, Boolean> checkboxesAssigned = new Map<String, Boolean>();
        // Initialize the checkbox values to false.
        for (Id indId : indAssignsNew.keySet())
            checkboxesAssigned.put(
                inds.get(indId).GM_Data_field_name__c,
                false
            );
        // For each indicator, determine whether there's an assign to delete, update, or insert.
        for (Indicator__c ind : inds.values()) {
            Indicator_Assign__c iaOld = indAssignsOld.get(ind.Id);
            String q, comment;
            Integer sepIndex, quantity;
            String iaNewInfo = indAssignsNew.get(ind.Id);
            if (iaNewInfo == '')
                iaNewInfo = null;
            if (iaNewInfo != null) {
                sepIndex = iaNewInfo.indexOf(';');
                if (sepIndex > -1) {
                    q = iaNewInfo.left(sepIndex);
                    if (q != null && q.length() > 0)
                        quantity = Integer.valueOf(q);
                    comment = iaNewInfo.right(
                        iaNewInfo.length() -
                        sepIndex -
                        1
                    );
                }
                // Indicate that checkbox in GM Data should be set for this indicator group.
                checkboxesAssigned.put(
                    inds.get(ind.Id).GM_Data_field_name__c,
                    true
                );
            }
            // Check if existing indicator assign should be deleted.
            if (iaOld != null && iaNewInfo == null)
                toDelete.add(iaOld);
            else if (iaOld == null && iaNewInfo != null)
                // Build a new indicator assign record.
                toInsert.add(
                    new Indicator_Assign__c(
                        Indicator__c = ind.Id,
                        GM_Data__c = gmDataId,
                        Quantity__c = quantity,
                        Comment__c = comment
                    )
                );
            else if (iaOld != null && iaNewInfo != null) {
                if (
                    quantity != iaOld.Quantity__c ||
                    comment != iaOld.Comment__c
                ) {
                    // Update an existing indicator assign record.
                    iaOld.Quantity__c = quantity;
                    iaOld.Comment__c = comment;
                    toUpdate.add(iaOld);
                }
            }
        }
        // Update the checkboxes in the GM Data record.
        for (Indicator__c ind : inds.values()) {
            String fName = ind.GM_Data_field_name__c;
            if (fName != null && checkboxesAssigned.containsKey(fName))
                gmDataInfo.gmData.put(fName, checkboxesAssigned.get(fName));
        }
        if (toInsert.size() > 0)
            insert toInsert;
        if (toUpdate.size() > 0)
            update toUpdate;
        if (toDelete.size() > 0)
            delete toDelete;
    }

    /**********************************
     * For use in VisualForce pages
     *********************************/

    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;

    public GMDataController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
    }

    public GMDataController(
        ApexPages.StandardSetController standardSetController
    ) {
        this.standardSetController = standardSetController;
    }

    // Build the menu of admissible correspondence templates for this object.
    private static String objectName = 'GM_Data__c';
    private static final String START = '--Select Template--';
    public List<selectOption> templates { get; private set; }
    {
        templates = Utilities.templatesForObject(objectName, START);
    }
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
            Map<Id, GM_Data__c> selMap = new Map<Id, GM_Data__c>(
                (List<GM_Data__c>) standardSetController.getSelected()
            );
            selIds = selMap.keySet();
        } else {
            selIds = new Set<Id>{ standardController.getId() };
        }
        Map<Id, GM_Data__c> selMap = new Map<Id, GM_Data__c>(
            [
                SELECT
                    Id,
                    Account__c,
                    Account__r.OwnerId,
                    Account__r.GM_email__c,
                    Profile__c
                FROM GM_Data__c
                WHERE Id IN :selIds
            ]
        );
        // Get account emails.
        Map<Id, Account> aMap = new Map<Id, Account>(
            [
                SELECT Id
                FROM Account
                WHERE
                    Id IN (
                        SELECT Account__c
                        FROM GM_Data__c
                        WHERE Id IN :selMap.keySet()
                    )
            ]
        );
        Map<Id, List<String>> emails = AccountController.emailsForAccounts(
            aMap.keySet()
        );
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName(
            'Template__c',
            selectedTemplate
        );
        for (GM_Data__c r : selMap.values()) {
            List<String> es = emails.get(r.Account__c);
            newLetters.add(
                new Letter__c(
                    Template__c = templateId,
                    Account__c = r.Account__c,
                    Account_owner__c = r.Account__r.OwnerId,
                    Letter_owner__c = UserInfo.getUserId(),
                    GM_Data__c = r.Id,
                    Profile__c = r.Profile__c,
                    // Use account emails.
                    Emails__c = Utilities.stringJoinWithCharLimit(es, ',', 255)
                )
            );
        }
        insert newLetters;
        // Reset the new letters.
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(newLetters);
        LetterController.resetLetters0(lMap.keySet(), false);
        // Changes have been saved; jump to the new letter if there's only one.
        if (standardController != null && newLetters.size() == 1)
            return Utilities.pageReferenceForRecord(newLetters[0]);
        else
            return doCancel(); // Stay in current layout.
    }

    public PageReference doCancel() {
        return (standardSetController != null)
            ? standardSetController.cancel()
            : standardController.cancel();
    }

    /**********************************
     * For general use
     *********************************/

    // Update GM Data record(s).
    public static void updateGMData(Set<Id> gmDataIds) {
    }
}