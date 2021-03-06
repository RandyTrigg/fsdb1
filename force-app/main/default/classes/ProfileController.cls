public inherited sharing class ProfileController {
    public static String notificationTemplateName = 'Request to submit Updated Profile';

    /**********************************
     * For use in Grants Experience Site
     *********************************/

    // Fetches org name from Profile for site header
    public static String getRunningUserProfileHeaderName() {
        Id prfId = getRunningUserProfileId();
        Profile__c prfRecord = (Profile__c)Utilities.fetchRecord(
            'Profile__c', 
            prfId, 
            null
        );
        return prfRecord.Org_name_submitted__c;
    }
    
     // Fetches profile information, including child proposals and form instances.
    public without sharing class ProfileSummary {
        public Profile__c prf;
        public Id prId;
        public Boolean hasForms = false;
        public Boolean hasProposals = false;
        public List<Proposal__c> prpList = new List<Proposal__c>();
        public List<Form_Instance__c> formInstList = new List<Form_Instance__c>();
        public Boolean hasSubmittedPrf = false;
        public Integer pendingAnnualProposals = 0;
        public Integer pendingShortProposals = 0;
        public String language;
        public String prFormInstanceId;
        private String prFormName = 'bff_Profile';

        public ProfileSummary (Id prfId) { 
            List<String> prfSubQuery = new List<String>{
                Utilities.buildChildSubQuery(
                    'Proposal__c',
                    'Proposals__r',
                    null
                ),
                Utilities.buildChildSubQuery(
                    'Form_Instance__c', 
                    'Form_Instances__r', 
                    null
                )
            };
            prId = prfId;
            prf = (Profile__c)Utilities.fetchRecord('Profile__c', prfId, prfSubQuery);
            hasProposals = (prf.Proposals__r != null && prf.Proposals__r.size() > 0) ? true : false;
            prpList = prf.Proposals__r;
            formInstList = prf.Form_Instances__r;
            language = prf.Language__c != null ? prf.Language__c : 'English';
            // Retrieve Profile Form Instance
            for ( Form_Instance__c formInst : formInstList) {
                if (formInst.Form_name__c == prFormName) {
                    prFormInstanceId = formInst.Id;
                    hasSubmittedPrf = formInst.Date_submitted__c != null ? true : false;
                }
            }
            // If no Profile Form Instance, create new
            if (prFormInstanceId == null || prFormInstanceId == '') {
                Id fsOwnerId = Utilities.fsDefaultRecordOwnerIdByUser(UserInfo.getUserId());
                Form__c prForm = [SELECT Id FROM Form__c WHERE Name = :prFormName];
                try {
                    Form_Instance__c newPrfForm = new Form_Instance__c(
                        Form__c = prForm.Id,
                        Profile__c = prfId,
                        OwnerId = fsOwnerId
                    );
                    insert newPrfForm;
                    prFormInstanceId = newPrfForm.Id;
                } catch(Exception e) {
                    throw new GFW_Exception('ProfileController.ProfileSummary', 'Could not load Profile Info form', e);
                }
            }
        }
    }

    public static Id getRunningUserProfileId() {
        try {
            Id userId = UserInfo.getUserId();
            Id runningProfileId;
            User u = 
                [SELECT Id, FirstName, LastName, Email, Username, ContactId, Contact.AccountId, Contact.Preferred_language__c, Contact.Org_name_submitted__c 
                FROM User WHERE Id=:userId];
            List<Profile__c> runningProfile = new List<Profile__c>(
                [SELECT ID FROM Profile__c WHERE Community_contact__c =:u.ContactId LIMIT 1]);
            if (runningProfile.isEmpty()) {
                Id fsOwnerId = Utilities.fsDefaultRecordOwnerIdByUser(userId);
                Profile__c newPrf = new Profile__c (
                    Community_contact__c = u.ContactId,
                    Community_contact_username__c = u.Username,
                    Account__c = u.Contact.AccountId,
                    OwnerId = fsOwnerId,
                    Language__c = u.Contact.Preferred_language__c,
                    Org_name_submitted__c = u.Contact.Org_name_submitted__c
                );
                insert newPrf;
                runningProfileId = newPrf.Id;
            } else {
                runningProfileId = runningProfile[0].Id;
            }
            return runningProfileId;
        } catch (Exception e) {
            throw new GFW_Exception('ProfileController.getRunningUserProfileId', 'Could not load Profile Record', e);
        }
    }

    // Creates proposal and returns its application form instance id
    public static String createProposal(Id prfId, String grantType) {
        try{
            String formId;
            String formInstId;
            Profile__c prf = (Profile__c)Utilities.fetchRecord('Profile__c', prfId, null);        
            system.debug('PrfId: ' + prfId);
            system.debug('Account: ' + prf.Account__c);
            Proposal__c newProp = new Proposal__c (
                    Account__c = prf.Account__c,
                    Profile__c = prfId,
                    Grant_type__c = grantType
                );
                insert newProp;
            // Look up app Form from custom metadata grant type.
            String fsGroup = Utilities.fsGroupNameByUser(UserInfo.getUserId());
            Grant_type__mdt[] grantTypeMetadata = [
                SELECT Label, Default_custom_reqs_name__c, FS_Group__r.Public_Group_Name__c, Application_form_name__c 
                FROM Grant_type__mdt
                WHERE Label = :grantType AND FS_Group__r.Public_Group_Name__c=:fsGroup
            ];
            String appFormName = grantTypeMetadata.size() > 0
                ? grantTypeMetadata[0].Application_form_name__c
                : null;
            if (appFormName != null) {
                Form__c[] appForm = [
                    SELECT Id
                    FROM Form__c
                    WHERE Name = :appFormName AND FS_Group__c=:fsGroup
                ];
                if (appForm.size() > 0)
                    formId = appForm[0].Id;
            }
            if (formId!=null) {
                // Create new Form Instance
                Id fsOwnerId = Utilities.fsDefaultRecordOwnerIdByUser(UserInfo.getUserId());
                Form_Instance__c newFormInstance = new Form_Instance__c (
                    Form__c = formId,
                    Profile__c = prfId,
                    Proposal__c = newProp.Id,
                    OwnerId = fsOwnerId
                );
                insert newFormInstance;
                formInstId = newFormInstance.Id;
            }
            return formInstId;
        } catch(Exception e) {
            throw new GFW_Exception('ProfileController.createProposal', 'Could not load Proposal Record', e);
        }
    }

    /**********************************
     * For use in Lightning components
     *********************************/

    @AuraEnabled
    public static Profile__c getProfile(Id profileId) {
        String objName = 'Profile__c';
        String[] fieldNames = Utilities.fieldNamesForObject(objName);
        fieldNames.add('Decline_reason__r.Name');
        fieldNames.add('Account__r.Account_black_listed__c');
        String q =
            'SELECT ' +
            String.join(fieldNames, ', ') +
            ' FROM ' +
            objName +
            ' WHERE Id = : profileId';
        system.debug('getProfile: q = ' + q);
        return Database.query(q);
    }

    @AuraEnabled
    public static Profile__c saveProfile(Profile__c profile) {
        //system.debug('saveProfile before update: status = ' +profile.Status__c);
        update profile;
        profile = getProfile(profile.Id);
        system.debug('saveProfile after update: status = ' + profile.Status__c);
        return profile;
    }

    // Clone a profile.
    // Set the original profile's Next Profile link to point to the new profile.
    public static Profile__c profileDeepClone(Id profileId) {
        Profile__c p = getProfile(profileId);
        Profile__c pNew = new Profile__c(
            Account__c = p.Account__c,
            Prior_profile__c = profileId
        );
        insert pNew;
        // Update link in original profile.
        p.Next_profile__c = pNew.Id;
        update p;
        return pNew;
    }

    // Send email notification to the group whose profile was cloned.
    public static void sendCloneNotificationEmails(Set<Id> pIds) {
        // Build and email letters for new profiles.
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            buildLetters0(pIds, notificationTemplateName, true)
        );
    }

    @AuraEnabled
    public static ProfileInfo getProfileInfo(Id profileId) {
        return new ProfileInfo(profileId);
    }

    // Object that packages profile information including profile object and picklists.
    public with sharing class ProfileInfo {
        @AuraEnabled
        public Profile__c profile,
            priorProfile;
        @AuraEnabled
        public Id gmDataId;
        @AuraEnabled
        public Map<String, List<String>> picklists;
        @AuraEnabled
        public String[] declineReasonNames,
            classificationNames,
            portfolioNames,
            selectedClassificationNames,
            selectedPortfolioNames,
            unselectedClassificationNames,
            unselectedPortfolioNames;
        @AuraEnabled
        public String selectedDeclineReasonName,
            selectedClassificationIdsPacked,
            selectedPortfolioIdsPacked;
        @AuraEnabled
        public Map<Id, String> declineReasonNameMap,
            classificationNameMap,
            portfolioNameMap;
        @AuraEnabled
        public List<Review_Form_Component__c> reviewComponents = new List<Review_Form_Component__c>();

        public ProfileInfo(Id profileId) {
            this.profile = getProfile(profileId);
            // Fetch the profile whose Next Profile link points at this profile.
            Profile__c[] priorProfs = [
                SELECT Id, Name, Date_submitted__c
                FROM Profile__c
                WHERE Next_profile__c = :profileId
            ];
            if (priorProfs.size() > 0)
                priorProfile = priorProfs[0];
            // Look up values in picklists at the time the record is created, so they're up to date.
            picklists = Utilities.getPicklists('Profile__c');

            setDeclineReasonFields();
            setPortfolioFields();
            // Stash the review form components for the profile review form.
            Review_Form__c[] reviewForms = (Review_Form__c[]) Utilities.fetchRecords(
                'Review_Form__c',
                'WHERE Name = \'Profile\' AND Active__c = true',
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
                    SELECT Id, Name
                    FROM Decline_Reason__c
                    WHERE For_profile__c = true AND Active__c = true
                    ORDER BY Name
                ]
            );
            declineReasonNameMap = new Map<Id, String>();
            for (Decline_Reason__c dr : drMap.values())
                declineReasonNameMap.put(dr.Id, dr.Name);
            declineReasonNames = declineReasonNameMap.values();
            if (declineReasonNames.size() > 0)
                declineReasonNames.add(0, ''); // Add blank entry at the front.
            selectedDeclineReasonName = declineReasonNameMap.get(
                profile.Decline_reason__c
            );
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
                'ProfileController.apxc setPortfolioFields: portfolioNameMap = ' +
                JSON.serialize(portfolioNameMap)
            );
            if (portfolioNames.size() > 0)
                portfolioNames.add(0, ''); // Add blank entry at the front.
            // Fetch and stash priority portfolios that have been assigned to this profile.
            Map<Id, Portfolio__c> pAssigned = new Map<Id, Portfolio__c>(
                [
                    SELECT Id
                    FROM Portfolio__c
                    WHERE
                        Id IN (
                            SELECT Portfolio__c
                            FROM Portfolio_Profile_Assign__c
                            WHERE
                                Profile__c = :profile.Id
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
        Id profId
    ) {
        ClassificationInfo result = new ClassificationInfo(cType, profId);
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
            // Fetch and stash classifications that have been assigned to this profile.
            Map<Id, Classification__c> cAssigned = new Map<Id, Classification__c>(
                [
                    SELECT Id
                    FROM Classification__c
                    WHERE
                        Id IN (
                            SELECT Classification__c
                            FROM Classification_Profile_Assign__c
                            WHERE Profile__c = :pId
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

    // This method has a "2" in the name, because the String parameters can't be passed if it
    // is just called "saveProfileInfo".  Is "saveProfileInfo" reserved because ProfileInfo is a class name?
    @AuraEnabled
    public static Profile__c saveProfileInfo2(
        Profile__c pr,
        String populationIdsPacked,
        String strategyIdsPacked,
        String issueIdsPacked,
        String portfolioIdsPacked
    ) {
        system.debug(
            'In saveProfileInfo2: pr = ' +
            JSON.serialize(pr) +
            '; issueIdsPacked = ' +
            issueIdsPacked +
            '; strategyIdsPacked = ' +
            strategyIdsPacked +
            '; populationIdsPacked = ' +
            populationIdsPacked +
            '; portfolioIdsPacked = ' +
            portfolioIdsPacked
        );
        saveClassificationAssigns(
            pr,
            'Population',
            populationIdsPacked == null ? '' : populationIdsPacked
        );
        saveClassificationAssigns(
            pr,
            'Issue',
            issueIdsPacked == null ? '' : issueIdsPacked
        );
        saveClassificationAssigns(
            pr,
            'Strategy',
            strategyIdsPacked == null ? '' : strategyIdsPacked
        );
        savePortfolioAssigns(pr, portfolioIdsPacked);
        // Save the profile part and return the result (possibly errors).
        return saveProfile(pr);
    }

    private static void saveClassificationAssigns(
        Profile__c pr,
        String cType,
        String selectedIdsPacked
    ) {
        system.debug(
            'In saveClassificationAssigns: pr = ' +
            JSON.serialize(pr) +
            '; selectedIdsPacked = ' +
            selectedIdsPacked
        );
        Id pId = pr.Id;
        // Add/remove joins to align with new selections.
        // Get current assignments.
        Map<Id, Classification_Profile_Assign__c> cJoins = new Map<Id, Classification_Profile_Assign__c>(
            [
                SELECT Id, Classification__c
                FROM Classification_Profile_Assign__c
                WHERE
                    Profile__c = :pId
                    AND Classification__r.Type__c = :cType
                    AND Classification__r.Active__c = true
            ]
        );
        system.debug(
            'In saveClassificationAssigns: cJoins = ' + JSON.serialize(cJoins)
        );
        // Stash current classification ids.
        Set<Id> currentIds = new Set<Id>();
        for (Classification_Profile_Assign__c ca : cJoins.values())
            currentIds.add(ca.Classification__c);
        // Get selected classifications.
        Set<String> setIds = new Set<String>(selectedIdsPacked.split(';', 0));
        system.debug(
            'In saveClassificationAssigns: setIds = ' + JSON.serialize(setIds)
        );
        // Build list of classifications to delete - they were assigned, but are no longer selected.
        List<Classification_Profile_Assign__c> toDelete = new List<Classification_Profile_Assign__c>();
        for (Classification_Profile_Assign__c ca : cJoins.values()) {
            if (!setIds.contains(String.valueof(ca.Classification__c)))
                toDelete.add(ca);
        }
        system.debug(
            'In saveClassificationAssigns: toDelete = ' +
            JSON.serialize(toDelete)
        );
        // Build list of classifications to insert - they weren't originally assigned, but are now selected.
        List<Classification_Profile_Assign__c> toInsert = new List<Classification_Profile_Assign__c>();
        for (String s : setIds) {
            if (String.isBlank(s))
                continue;
            Id i = Id.valueOf(s);
            if (!currentIds.contains(i))
                toInsert.add(
                    new Classification_Profile_Assign__c(
                        Classification__c = i,
                        Profile__c = pId
                    )
                );
        }
        system.debug(
            'In saveClassificationAssigns: toInsert = ' +
            JSON.serialize(toInsert)
        );
        if (toDelete.size() > 0)
            delete toDelete;
        if (toInsert.size() > 0)
            insert toInsert;
    }

    private static void savePortfolioAssigns(
        Profile__c pr,
        String selectedIdsPacked
    ) {
        system.debug(
            'In savePortfolioAssigns: pr = ' +
            JSON.serialize(pr) +
            '; selectedIdsPacked = ' +
            selectedIdsPacked
        );
        Id pId = pr.Id;
        // Add/remove priority portfolio joins to align with new selections.
        // Get current assignments.
        Map<Id, Portfolio_Profile_Assign__c> pJoins = new Map<Id, Portfolio_Profile_Assign__c>(
            [
                SELECT Id, Portfolio__c
                FROM Portfolio_Profile_Assign__c
                WHERE Profile__c = :pId AND Portfolio__r.Type__c = 'Priority'
            ]
        );
        system.debug(
            'In savePortfolioAssigns: pJoins = ' + JSON.serialize(pJoins)
        );
        // Stash current classification ids.
        Set<Id> currentIds = new Set<Id>();
        for (Portfolio_Profile_Assign__c pa : pJoins.values())
            currentIds.add(pa.Portfolio__c);
        // Get selected classifications.
        Set<String> setIds = new Set<String>(selectedIdsPacked.split(';', 0));
        system.debug(
            'In savePortfolioAssigns: setIds = ' + JSON.serialize(setIds)
        );
        // Build list of classifications to delete - they were assigned, but are no longer selected.
        List<Portfolio_Profile_Assign__c> toDelete = new List<Portfolio_Profile_Assign__c>();
        for (Portfolio_Profile_Assign__c pa : pJoins.values()) {
            if (!setIds.contains(String.valueof(pa.Portfolio__c)))
                toDelete.add(pa);
        }
        system.debug(
            'In savePortfolioAssigns: toDelete = ' + JSON.serialize(toDelete)
        );
        // Build list of portfolios to insert - they weren't originally assigned, but are now selected.
        List<Portfolio_Profile_Assign__c> toInsert = new List<Portfolio_Profile_Assign__c>();
        for (String s : setIds) {
            if (String.isBlank(s))
                continue;
            Id i = Id.valueOf(s);
            if (!currentIds.contains(i))
                toInsert.add(
                    new Portfolio_Profile_Assign__c(
                        Portfolio__c = i,
                        Profile__c = pId
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
     * For use in VisualForce pages
     *********************************/

    private ApexPages.StandardController standardController;
    private ApexPages.StandardSetController standardSetController;

    public ProfileController(ApexPages.StandardController standardController) {
        this.standardController = standardController;
        this.selRecs = fetchRecords(new Set<Id>{ standardController.getId() });
        this.templates = Utilities.templatesMenu(
            objectName,
            START,
            selRecs,
            statusFieldName
        );
    }

    public ProfileController(
        ApexPages.StandardSetController standardSetController
    ) {
        this.standardSetController = standardSetController;
        Map<Id, Profile__c> selMap = new Map<Id, Profile__c>(
            (List<Profile__c>) standardSetController.getSelected()
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
    private static String objectName = 'Profile__c';
    private static final String START = '--Select Template--';
    private static String statusFieldName = 'Status_numeric__c';
    private List<Profile__c> selRecs;
    public List<selectOption> templates { get; private set; }
    public String selectedTemplate { get; set; }
    {
        selectedTemplate = START;
    }
    public List<Letter__c> newLetters = new List<Letter__c>();

    // Build and reset letters for selected records (VF context).
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
            Map<Id, Profile__c> selMap = new Map<Id, Profile__c>(
                (List<Profile__c>) standardSetController.getSelected()
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

    // Build and reset letters for given profiles (non-VF context).
    // The shape with ids parameter is for external callers; with records parameter is called from VF.
    public static List<Letter__c> buildLetters0(
        Set<Id> selIds,
        String selectedTemplate,
        Boolean emailFlg
    ) {
        return buildLetters0(fetchRecords(selIds), selectedTemplate, emailFlg);
    }
    public static List<Letter__c> buildLetters0(
        Profile__c[] selRecs,
        String selectedTemplate,
        Boolean emailFlg
    ) {
        Set<Id> accIds = new Set<Id>();
        for (Profile__c p : selRecs) {
            Id accId = p.Account__c;
            if (accId != null)
                accIds.add(accId);
        }
        Map<Id, List<String>> emails = Utilities.emailsForAccounts(accIds);
        // Build new letters for selected records.
        Id templateId = Utilities.recordIdFromName(
            'Template__c',
            selectedTemplate
        );
        List<Letter__c> ls = new List<Letter__c>();
        for (Profile__c r : selRecs) {
            List<String> es = emails.get(r.Account__c);
            ls.add(
                new Letter__c(
                    Template__c = templateId,
                    Account__c = r.Account__c,
                    Account_owner__c = r.Account__r.OwnerId,
                    Letter_owner__c = UserInfo.getUserId(),
                    Profile__c = r.Id,
                    // Use account emails if any.
                    Emails__c = Utilities.stringJoinWithCharLimit(es, ',', 255)
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
    static private Profile__c[] fetchRecords(Set<Id> ids) {
        system.debug('fetchRecords: ids = ' + JSON.serialize(ids));
        return [
            SELECT
                Id,
                Status_numeric__c,
                Account__c,
                Account__r.OwnerId
            FROM Profile__c
            WHERE Id IN :ids
        ];
    }

    public PageReference doCancel() {
        return (standardSetController != null)
            ? standardSetController.cancel()
            : standardController.cancel();
    }
}