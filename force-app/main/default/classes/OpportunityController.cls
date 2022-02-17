public class OpportunityController {
    /**********************************
     * For use in Lightning components
     *********************************/

    // Look up the active task spec groups for opportunities.
    @AuraEnabled
    public static Task_Spec_Group__c[] getTaskSpecGroups(String type) {
        return [
            SELECT Id, Name, Description__c
            FROM Task_Spec_Group__c
            WHERE
                Object_name__c = 'Opportunity'
                AND Type__c = :type
                AND Active__c = true
            ORDER BY Name
        ];
    }

    // Fetch all local fields of the tasks belonging to the given opportunity.
    @AuraEnabled
    public static Task[] getTasks(Id oppId) {
        return Utilities.fetchChildRecords('Task', oppId, 'WhatId', null);
    }

    // Build the RFC tasks for given opportunity from given task spec group.
    @AuraEnabled
    public static void buildTasksFromTSG(
        String oppId,
        String tsgId,
        String reportTaskAssignedToOverrideId
    ) {
        system.debug(
            'buildTasksFromTSG: oppId = ' +
            oppId +
            '; tsgId = ' +
            tsgId +
            '; reportTaskAssignedToOverrideId = ' +
            reportTaskAssignedToOverrideId
        );
        // Build tasks from selected task spec group.
        Utilities.instantiateTaskSpecs(
            (Id) oppId,
            (Id) tsgId,
            (Id) reportTaskAssignedToOverrideId,
            null
        );
    }

    // Build the RFC tasks for given opportunity from task spec groups with given type.
    @AuraEnabled
    public static void buildTasksFromTSGType(
        String oppId,
        String tsgType,
        String reportTaskAssignedToOverrideId
    ) {
        system.debug(
            'buildTasksFromTSGType: oppId = ' +
            oppId +
            '; tsgType = ' +
            tsgType +
            '; reportTaskAssignedToOverrideId = ' +
            reportTaskAssignedToOverrideId
        );
        Task_Spec_Group__c[] tsgs = getTaskSpecGroups(tsgType);
        for (Task_Spec_Group__c tsg : tsgs)
            Utilities.instantiateTaskSpecs(
                (Id) oppId,
                (Id) tsg.Id,
                (Id) reportTaskAssignedToOverrideId,
                null
            );
    }

    // Build tasks for given opportunity from given task spec group using JSON parameter.
    @AuraEnabled
    public static String instantiateTaskSpecGroup(String jsonString) {
        strike_responseData responseData = new strike_responseData();
        try {
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(
                jsonString
            );
            Id oppId = jsonMap.get('oppId') != null
                ? Id.valueOf((String) jsonMap.get('oppId'))
                : null;
            Id taskSpecGroupId = jsonMap.get('taskSpecGroupId') != null
                ? Id.valueOf((String) jsonMap.get('taskSpecGroupId'))
                : null;
            Id reportTaskAssignedToOverrideId = jsonMap.get(
                    'reportTaskAssignedToOverrideId'
                ) != null
                ? Id.valueOf(
                        (String) jsonMap.get('reportTaskAssignedToOverrideId')
                    )
                : null;
            Date baseDate = jsonMap.get('baseDate') != null
                ? Date.valueOf((String) jsonMap.get('baseDate'))
                : null;
            system.debug(
                'instantiateTaskSpecGroup: oppId = ' +
                oppId +
                '; taskSpecGroupId = ' +
                taskSpecGroupId +
                '; reportTaskAssignedToOverrideId = ' +
                reportTaskAssignedToOverrideId +
                '; baseDate = ' +
                baseDate
            );
            // Build tasks from selected task spec group.
            Utilities.instantiateTaskSpecs(
                oppId,
                taskSpecGroupId,
                reportTaskAssignedToOverrideId,
                baseDate
            );
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        system.debug(
            'instantiateTaskSpecGroup: responseData = ' +
            JSON.serialize(responseData)
        );
        return responseData.getJsonString();
    }

    // Build task for given opportunity from given task spec.
    @AuraEnabled
    public static String instantiateTaskSpec(String jsonString) {
        strike_responseData responseData = new strike_responseData();
        try {
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(
                jsonString
            );
            system.debug(
                'instantiateTaskSpec: jsonMap = ' + JSON.serialize(jsonMap)
            );
            Id oppId = jsonMap.get('oppId') != null
                ? Id.valueOf((String) jsonMap.get('oppId'))
                : null;
            Id taskSpecId = jsonMap.get('taskSpecId') != null
                ? Id.valueOf((String) jsonMap.get('taskSpecId'))
                : null;
            Id reportTaskAssignedToOverrideId = jsonMap.get(
                    'reportTaskAssignedToOverrideId'
                ) != null
                ? Id.valueOf(
                        (String) jsonMap.get('reportTaskAssignedToOverrideId')
                    )
                : null;
            Date baseDate = jsonMap.get('baseDate') != null
                ? Date.valueOf((String) jsonMap.get('baseDate'))
                : null;
            system.debug(
                'instantiateTaskSpec: oppId = ' +
                oppId +
                '; taskSpecId = ' +
                taskSpecId +
                '; reportTaskAssignedToOverrideId = ' +
                reportTaskAssignedToOverrideId +
                '; baseDate = ' +
                baseDate
            );
            // Build task from selected task spec.
            Task t = Utilities.instantiateTaskSpec(
                oppId,
                taskSpecId,
                reportTaskAssignedToOverrideId,
                baseDate
            );
            if (t != null)
                insert t;
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        system.debug(
            'instantiateTaskSpec: responseData = ' +
            JSON.serialize(responseData)
        );
        return responseData.getJsonString();
    }

    // Fetch tasks for given opportunity, plus first gift date and task specs and task spec groups.
    @AuraEnabled
    public static String getTasksPlus(Id oppId) {
        strike_responseData responseData = new strike_responseData();
        // Skip the Miscellaneous group - those are grabbed in the task spec search.
        Task_Spec_Group__c[] tsgs = [
            SELECT Id, Name, Description__c
            FROM Task_Spec_Group__c
            WHERE
                Object_name__c = 'Opportunity'
                AND Active__c = true
                AND Name != 'Miscellaneous'
            ORDER BY Name
        ];
        // Only grab task specs in the Miscellaneous group - the others are included in task spec groups.
        Task_spec__c[] tss = [
            SELECT Id, Name, Subject__c
            FROM Task_Spec__c
            WHERE Active__c = true AND Task_Spec_Group__r.Name = 'Miscellaneous'
            ORDER BY Name
        ];
        try {
            responseData.results = new Map<String, Object>{
                'tasks' => Utilities.fetchChildRecords(
                    'Task',
                    oppId,
                    'WhatId',
                    new List<String>{ 'Owner.Name', 'CreatedBy.Name' }
                ),
                'taskSpecs' => tss,
                'taskSpecGroups' => tsgs
            };
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        system.debug(
            'getTasksPlus: responseData = ' + JSON.serialize(responseData)
        );
        return responseData.getJsonString();
    }

    // Update task records as specified in the updateSpec JSON (list of records, each of which lists fields to change plus Id).
    @AuraEnabled
    public static String updateTasks(String tasksJSON) {
        strike_responseData responseData = new strike_responseData();
        try {
            List<Task> tasks = (List<Task>) JSON.deserialize(
                tasksJSON,
                List<Task>.class
            );
            update tasks;
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        return responseData.getJsonString();
    }

    /**********************************
     * For general use
     *********************************/

    /*
     * Assume that caller is ensuring that opp's stage just changed to Closed Won.  That is, we
     * shouldn't later re-clone if they delete the clone that was created when the opp was closed.
     * Conditions for cloning:
     * (1) the current stage is closed-won,
     * (2) the current type is "Major Gift Opportunity: Annual Gift",
     * (3) there's no open opportunity for this account with
     * type = "Major Gift Opportunity: Annual Gift" and
     * close date after the closed opp's close date (check with Renee on that last one!).
     */
    public static void opportunityClone(Id oppId) {
        // Constrain that opp is closed-won and of the correct type
        Opportunity opp = [
            SELECT
                CloseDate,
                StageName,
                Type,
                OwnerId,
                Amount,
                AccountId,
                Name,
                Notes__c,
                ChartofAccounts__c,
                ChartofAccounts__r.Name,
                Soft_ask__c,
                Account.Name,
                CampaignId
            FROM Opportunity
            WHERE
                Id = :oppId
                AND StageName = 'Closed Won'
                AND Type = 'Major Gift Opportunity: Annual Gift'
                AND AccountId != null
        ];
        if (opp == null)
            return; // Bail if inappropriate to do an auto-clone.

        // Build a pattern that matches strings like "FY2013-2014" in opportunity names.
        Pattern fyPat = Pattern.compile('FY(\\d{4})-(\\d{4})');

        // Fetch all open opportunities for the opp's account.
        Account acc = [
            SELECT
                Id,
                OwnerId,
                (
                    SELECT Id, AccountId, CloseDate, StageName
                    FROM Opportunities
                    WHERE
                        (NOT StageName LIKE '%Closed%')
                        AND Type = 'Major Gift Opportunity: Annual Gift'
                    ORDER BY CloseDate DESC
                    LIMIT 1
                )
            FROM Account
            WHERE Id = :opp.AccountId
        ];
        system.debug('OpportunityClone: acc = ' + JSON.serialize(acc));
        List<Opportunity> openOpps = acc.Opportunities;
        Opportunity newOpp;
        // Skip unless there's an open opp for the account with more recent close date.
        system.debug(
            'OpportunityClone before if: openOpps = ' + JSON.serialize(openOpps)
        );
        if (
            openOpps.size() == 0 ||
            openOpps[0].CloseDate == null ||
            openOpps[0].CloseDate < opp.CloseDate
        ) {
            // Look for an FY pattern in the closed opp's name.
            Matcher pm = fyPat.matcher(opp.Name);
            integer fyYear1, fyYear2;
            if (pm.find()) {
                fyYear1 = integer.valueof(pm.group(1));
                fyYear2 = integer.valueof(pm.group(2));
            }
            date newCloseDate = opp.CloseDate.addYears(1);
            string newCloseDateFY = Utilities.FYfromDate(newCloseDate);
            // Designation description is based on closed opp's chart-of-accounts.
            string designationDesc = (opp.ChartofAccounts__c == null ||
                opp.ChartofAccounts__r.Name.toLowerCase()
                    .contains('unrestricted'))
                ? 'General Support'
                : opp.ChartofAccounts__r.Name;
            // The FY for the new opp name is based on close date, unless this is a multi-year opp,
            // in which case base it on the FY pattern in the closed opp's name.
            string fyNew = (pm.find() &&
                fyYear2 > integer.valueOf(newCloseDateFY.Right(4)))
                ? Utilities.FYfromDate(date.newInstance(fyYear2 + 1, 1, 1))
                : newCloseDateFY;
            // Build the new opp name by string replace of the FY in the closed opp's name.
            // If it doesn't contain an FY pattern, then build a new name from scratch.
            string newOppName = (pm.matches())
                ? opp.Name.replace(
                        'FY' +
                        pm.group(1) +
                        '-' +
                        pm.group(2),
                        fyNew
                    )
                : fyNew + ' ' + designationDesc + ': ' + opp.Account.Name;

            // Now clone the closed opportunity.
            newOpp = new Opportunity(
                Amount = opp.Amount,
                AccountId = opp.AccountId,
                Type = opp.Type,
                ChartofAccounts__c = opp.ChartofAccounts__c,
                Soft_ask__c = opp.Soft_ask__c,
                OwnerId = opp.OwnerId,
                CampaignId = opp.CampaignId,
                StageName = 'Identification',
                Notes__c = 'Auto-cloned from prior closed opportunity, ' +
                    opp.Name,
                CloseDate = newCloseDate,
                Name = newOppName
            );
        }
        if (newOpp <> null)
            insert newOpp;
    }
}