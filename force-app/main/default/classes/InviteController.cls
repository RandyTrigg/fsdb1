public class InviteController {
    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;

    public InviteController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
        this.selRecs = fetchRecords(new Set<Id>{ standardController.getId() });
        this.templates = Utilities.templatesMenu(objectName, START, selRecs, statusFieldName);
    }

    public InviteController(ApexPages.StandardSetController standardSetController) {
        this.standardSetController = standardSetController;
        Map<Id, Invite__c> selMap = new Map<Id, Invite__c>((List<Invite__c>) standardSetController.getSelected());
        this.selRecs = fetchRecords(selMap.keySet());
        this.templates = Utilities.templatesMenu(objectName, START, selRecs, statusFieldName);
    }

    // Build the menu of admissible correspondence templates for this object.
    private static String objectName = 'Invite__c';
    private static final String START = '--Select Template--';
    private static String statusFieldName = 'Status_numeric__c';
    private List<Invite__c> selRecs;
    public List<selectOption> templates { get; private set; }
    public String selectedTemplate { get; set; } { selectedTemplate = START; }

    // Get selected records, then build and reset letters for them.
    public PageReference buildLetters() {
        // Generate error if no selected template - assign error to the templateType field.
        if (selectedTemplate == null || selectedTemplate == START) {
            ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                'Please select a template',
                'Must select a template before building new letters'
                )
            );
            selectedTemplate = START; // If I don't reset to the START value, it gets set to one of the non-disabled values.
            return null;
        }
        // Gather email addresses from the invites' accounts.
        Set<Id> accIds = new Set<Id>();
        for (Invite__c i : selRecs)
            accIds.add(i.Account__c);
        Map<Id, List<String>> emails = Utilities.emailsForAccounts(
            accIds
        );
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName(
            'Template__c',
            selectedTemplate
        );
        List<Letter__c> ls = new List<Letter__c>();
        for (Invite__c r : selRecs) {
            List<String> es = emails.get(r.Account__c);
            ls.add(
                new Letter__c(
                    Template__c = templateId,
                    Account__c = r.Account__c,
                    Account_owner__c = r.Account__r.OwnerId,
                    Letter_owner__c = UserInfo.getUserId(),
                    Invite__c = r.Id,
                    Region__c = r.Account__r.GM_Region__c,
                    Emails__c = (es == null) ? '' : Utilities.stringJoinWithCharLimit(es, ',', 255)
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
    static private Invite__c[] fetchRecords(Set<Id> ids) {
        system.debug('fetchRecords: ids = ' + JSON.serialize(ids));
        return [
            SELECT Id, Status_numeric__c, Account__c, Account__r.OwnerId, Account__r.GM_Region__c
            FROM Invite__c
            WHERE Id IN :ids
        ];
    }

    public PageReference doCancel() {
        return (standardSetController != null) ? standardSetController.cancel() : standardController.cancel();
    }

    /**********************************
     * For general use
     *********************************/

    // Build invites and singleton allocations.
    static String LEIUserTitle = 'Senior Learning and Evaluation Officer';
    static User[] LEIUsers = [
        SELECT Id
        FROM User
        WHERE Title = :LEIUserTitle
        LIMIT 1
    ];
    static Id LEIUserId = LEIUsers.size() > 0 ? LEIUsers[0].Id : null;
    static String allocInviteComment =
        DateTime.now() + ': Built by automated process.  DO NOT REPLICATE.';

    // Build invites and singleton allocations for any charges in the given fund that don't already belong to an invite/allocation.
    public static void newAllocationsInvitesForFund(Id fundId) {
        Fund__c fund = [SELECT Id FROM Fund__c WHERE Id = :fundId];
        // List of all proposals charged to the fund.
        Map<Id, Proposal__c> pChargedMap = new Map<Id, Proposal__c>(
            [
                SELECT
                    Id,
                    Account__c,
                    Amount_awarded__c,
                    Custom_Reqs__c,
                    Staff_responsible__c,
                    Date_awarded__c,
                    Date_invited__c,
                    Grant__c,
                    Profile__c
                FROM Proposal__c
                WHERE
                    Id IN (
                        SELECT Proposal__c
                        FROM Charge__c
                        WHERE Fund__c = :fund.Id
                    )
            ]
        );
        // Lookup map of the subset of these proposals that already have invites.
        Map<Id, Proposal__c> pInvitedMap = new Map<Id, Proposal__c>(
            [
                SELECT Id
                FROM Proposal__c
                WHERE
                    Id IN :pChargedMap.keySet()
                    AND Id IN (SELECT Proposal__c FROM Invite__c)
            ]
        );
        // Walk through charged props building new invites/allocations where necessary.
        Invite__c[] invitesToInsert = new List<Invite__c>();
        Allocation__c[] allocsToInsert = new List<Allocation__c>();
        for (Proposal__c p : pChargedMap.values()) {
            if (!pInvitedMap.containsKey(p.Id)) {
                // Use external ids to link invites to allocations.
                String extId =
                    p.Id +
                    '-' +
                    Datetime.now() +
                    '-' +
                    Utilities.generateRandomString(10);
                allocsToInsert.add(newAllocationForProp(p, extId, fund.Id));
                invitesToInsert.add(newInviteForProp(p, extId));
            }
        }
        if (allocsToInsert.size() > 0)
            insert allocsToInsert;
        if (invitesToInsert.size() > 0)
            insert invitesToInsert;
    }

    // Build invites and singleton allocations for given proposals that don't already belong to an invite/allocation.
    // Note that unlike the above version for fund, this one skips props with split charges.
    public static void newAllocationsInvitesForProps(Set<Id> propIds) {
        // Build map of proposals that have charges.
        Map<Id, Proposal__c> pChargedMap = new Map<Id, Proposal__c>(
            [
                SELECT
                    Id,
                    Account__c,
                    Amount_awarded__c,
                    Custom_Reqs__c,
                    Staff_responsible__c,
                    Date_awarded__c,
                    Date_invited__c,
                    Grant__c,
                    Profile__c
                FROM Proposal__c
                WHERE
                    Id IN :propIds
                    AND Id IN (SELECT Proposal__c FROM Charge__c)
            ]
        );
        // Lookup map of the subset of these proposals that already have invites.
        Map<Id, Proposal__c> pInvitedMap = new Map<Id, Proposal__c>(
            [
                SELECT Id
                FROM Proposal__c
                WHERE
                    Id IN :pChargedMap.keySet()
                    AND Id IN (SELECT Proposal__c FROM Invite__c)
            ]
        );
        // Lookup map of unique fund per proposal (if prop has split charges, then don't include).
        AggregateResult[] groupedProps = [
            SELECT Proposal__c, Count(Id) countCharges, MAX(Fund__c) fundId
            FROM Charge__c
            WHERE Proposal__c IN :pChargedMap.keySet()
            GROUP BY Proposal__c
        ];
        Map<Id, Id> pRstIdMap = new Map<Id, Id>();
        for (AggregateResult ar : groupedProps) {
            pRstIdMap.put(
                (Id) ar.get('Proposal__c'),
                (Integer) ar.get('countCharges') == 1
                    ? (Id) ar.get('fundId')
                    : null
            );
        }
        // Walk through charged props, building new invites/allocations where appropriate.
        Invite__c[] invitesToInsert = new List<Invite__c>();
        Allocation__c[] allocsToInsert = new List<Allocation__c>();
        for (Proposal__c p : pChargedMap.values()) {
            // For the moment, only process proposals with singleton charges (that is, unique fund).
            Id fundId = pRstIdMap.get(p.Id);
            if (!pInvitedMap.containsKey(p.Id) && fundId != null) {
                // Use external ids to link invites to allocations.
                String extId =
                    p.Id +
                    '-' +
                    Datetime.now() +
                    '-' +
                    Utilities.generateRandomString(10);
                allocsToInsert.add(newAllocationForProp(p, extId, fundId));
                invitesToInsert.add(newInviteForProp(p, extId));
            }
        }
        if (allocsToInsert.size() > 0)
            insert allocsToInsert;
        if (invitesToInsert.size() > 0)
            insert invitesToInsert;
    }

    // Create a new allocation drawing on fields from the given proposal.
    private static Allocation__c newAllocationForProp(
        Proposal__c p,
        String allocExtId,
        Id fundId
    ) {
        return new Allocation__c(
            ExternalId__c = allocExtId,
            Fund__c = fundId,
            Grant_size__c = p.Amount_awarded__c,
            Num_grants__c = 1,
            Num_to_invite__c = 1,
            Custom_Reqs__c = p.Custom_Reqs__c,
            Staff_responsible__c = p.Staff_responsible__c,
            Comments__c = allocInviteComment
        );
    }

    // Create a new invite drawing on fields from the given proposal.
    private static Invite__c newInviteForProp(
        Proposal__c p,
        String allocExtId
    ) {
        return new Invite__c(
            Account__c = p.Account__c,
            Proposal__c = p.Id,
            Allocation__r = new Allocation__c(ExternalId__c = allocExtId),
            Amount_awarded__c = p.Amount_awarded__c,
            Custom_Reqs__c = p.Custom_Reqs__c,
            Date_invited__c = p.Date_invited__c,
            Date_approved__c = p.Date_awarded__c,
            Grant__c = p.Grant__c,
            Profile__c = p.Profile__c,
            Comments__c = allocInviteComment
        );
    }

    // Build a new proposal for given invite by "cloning" the prior proposal.
    @AuraEnabled
    public static String cloneProposal(Id inviteId) {
        strike_responseData responseData = new strike_responseData();
        String[] inviteRelatedFields = new List<String>{
            'Allocation__r.Date_prop_due__c',
            'Allocation__r.Date_of_award_notification__c',
            'Allocation__r.Staff_responsible__c',
            'Allocation__r.Custom_reqs__c'
        };
        Invite__c i = (Invite__c) Utilities.fetchRecord(
            'Invite__c',
            inviteId,
            inviteRelatedFields
        );
        Id propToCloneId = i.Proposal_to_clone__c;
        if (propToCloneId == null) {
            responseData.addError('Must have a proposal to clone');
            return responseData.getJsonString();
        }
        // Fetch all fields of existing proposal.
        Proposal__c p = (Proposal__c) Utilities.fetchRecord(
            'Proposal__c',
            propToCloneId,
            null
        );
        Proposal__c pNew = new Proposal__c(Account__c = p.Account__c);
        // Look up fields to copy from custom metadata.
        Proposal_clone_field_to_copy__mdt[] flds = [
            SELECT Field_name__c
            FROM Proposal_clone_field_to_copy__mdt
            WHERE Active__c = true
        ];
        for (Proposal_clone_field_to_copy__mdt fld : flds)
            pNew.put(fld.Field_name__c, p.get(fld.Field_name__c));
        // Tweak a few other fields.
        pNew.Prior_proposal__c = p.Id;
        pNew.Invite__c = i.Id;
        pNew.Custom_Reqs__c = i.Custom_Reqs__c;
        pNew.Profile__c = i.Profile__c;
        pNew.Proposal_submit_deadline__c = i.Allocation__r.Date_prop_due__c;
        pNew.Award_notification_deadline__c = i.Allocation__r.Date_of_award_notification__c;
        pNew.Staff_responsible__c = i.Allocation__r.Staff_responsible__c;
        pNew.Custom_reqs__c = i.Allocation__r.Custom_reqs__c;
        pNew.Highlights__c =
            'Proposal record (pre-award) cloned from earlier prop# ' +
            p.Name +
            '.  Refer to the earlier prop for notes/further details (if any).';
        insert pNew;
        // Fetch new proposal's Name field for use in Lightning component.
        pNew = [SELECT Id, Name FROM Proposal__c WHERE Id = :pNew.Id];
        // Link invite to the new proposal.
        i.Proposal__c = pNew.Id;
        update i;

        // Clone classification assigns, portfolio assigns.
        sObject[] toInsert = new List<sObject>();
        Classification_Assign__c[] cAssigns = Utilities.fetchChildRecords(
            'Classification_Assign__c',
            p.Id,
            'Proposal__c',
            null
        );
        for (Classification_Assign__c ca : cAssigns) {
            Classification_Assign__c caClone = ca.clone(false, true);
            caClone.Proposal__c = pNew.Id;
            toInsert.add(caClone);
        }
        Portfolio_Assignment__c[] pAssigns = Utilities.fetchChildRecords(
            'Portfolio_Assignment__c',
            p.Id,
            'Proposal__c',
            null
        );
        for (Portfolio_Assignment__c pa : pAssigns) {
            Portfolio_Assignment__c paClone = pa.clone(false, true);
            paClone.Proposal__c = pNew.Id;
            toInsert.add(paClone);
        }
        // Insert the newly cloned child records.
        if (toInsert.size() > 0)
            insert toInsert;

        responseData.results = new Map<String, Object>{ 'proposal' => pNew };
        return responseData.getJsonString();
    }

    // Fetch invite and related records.
    @AuraEnabled
    public static String getInfo(Id inviteId) {
        strike_responseData responseData = new strike_responseData();
        // Fetch invite data and related records/fields.
        String[] relFields = new List<String>{
            'Account__r.Name',
            'Allocation__r.Fund__r.Name',
            'Allocation__r.Custom_Reqs__r.Name'
        };
        String[] relRecords = new List<String>{ 'Profile__r', 'Allocation__r' };
        Invite__c i = (Invite__c) Utilities.fetchRecordAndRelatedRecords(
            'Invite__c',
            inviteId,
            relFields,
            relRecords
        );
        // Grab Name field of proposal to clone (if any) for use in lightning component.
        Proposal__c propToClone;
        if (i.Proposal_to_clone__c != null)
            propToClone = [
                SELECT Name
                FROM Proposal__c
                WHERE Id = :i.Proposal_to_clone__c
            ];
        Allocation__c alloc = i.Allocation__r;
        Custom_Reqs__c reqs = alloc.Custom_Reqs__r;
        try {
            responseData.results = new Map<String, Object>{
                'invite' => i,
                'propToClone' => propToClone
            };
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        system.debug('getInfo: responseData = ' + JSON.serialize(responseData));
        system.debug(
            'getInfo: responseData.getJsonString() = ' +
            responseData.getJsonString()
        );
        return responseData.getJsonString();
    }

    // Classes used to deserialize the JSON returned by getInfo, basically a specialization of the strike_responseData class, omitting isSuccess and errMsg fields.
    private class InviteInfo {
        private InviteObjs results;
    }
    private class InviteObjs {
        private Invite__c invite;
    }
    // Build a new proposal for given invite.  Json string includes a couple of other fields.  Get associated records by calling getInfo.
    // In addition to proposal, build GM Data and clone classification assigns from the profile (if any).
    @AuraEnabled
    public static String newProposal(String jsonString) {
        strike_responseData responseData = new strike_responseData();
        try {
            system.debug('newProposal: jsonString = ' + jsonString);
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(
                jsonString
            );
            system.debug('newProposal: jsonMap = ' + JSON.serialize(jsonMap));
            Id inviteId = (Id) jsonMap.get('inviteId');
            Date invitationDeadline = jsonMap.get('invitationDeadline') != null
                ? Date.valueOf((String) jsonMap.get('invitationDeadline'))
                : null;
            Date awardNotificationDeadline = jsonMap.get(
                    'awardNotificationDeadline'
                ) != null
                ? Date.valueOf(
                        (String) jsonMap.get('awardNotificationDeadline')
                    )
                : null;
            // Fetch associated records.
            String getInfoResponseString = getInfo(inviteId);
            system.debug(
                'newProposal: getInfoResponseString = ' + getInfoResponseString
            );
            InviteInfo inviteInfo = (InviteInfo) JSON.deserialize(
                getInfoResponseString,
                InviteInfo.class
            );
            system.debug(
                'newProposal: inviteInfo = ' + JSON.serialize(inviteInfo)
            );
            Invite__c i = inviteInfo.results.invite;
            Account acc = i.Account__r;
            Profile__c prof = i.Profile__r;
            Allocation__c alloc = i.Allocation__r;
            Custom_Reqs__c reqs = alloc.Custom_Reqs__r;
            // New records
            String appType = alloc.Type__c;
            Proposal__c prop = new Proposal__c(
                Account__c = acc.Id,
                Invite__c = i.Id,
                Profile__c = prof != null ? prof.Id : null,
                Custom_Reqs__c = reqs != null ? reqs.Id : null,
                Staff_responsible__c = alloc.Staff_responsible__c,
                Proposal_submit_deadline__c = invitationDeadline,
                Award_notification_deadline__c = awardNotificationDeadline
            );
            insert prop;
            // Fetch new proposal's Name field for use in Lightning component.
            prop = [SELECT Id, Name FROM Proposal__c WHERE Id = :prop.Id];
            // Update invite with link to new proposal.
            i.Proposal__c = prop.Id;
            update i;
            // Seed proposal's classification assigns by cloning from profile.
            if (prof != null)
                ProposalController.copyClassificationAssignsFromProfile(
                    prop.Id,
                    prof.Id
                );
            responseData.results = new Map<String, Object>{
                'proposal' => prop
            };
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        system.debug(
            'newProposal: responseData = ' + JSON.serialize(responseData)
        );
        return responseData.getJsonString();
    }
}