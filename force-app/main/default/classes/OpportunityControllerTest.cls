@isTest
public class OpportunityControllerTest {
    static testMethod void OpportunityControllerTest1() {
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        insert new Opportunity(
            Name = 'test opportunity 1',
            StageName = 'Closed Won',
            CloseDate = Date.today()
        );
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        String typeVal = Utilities.picklistValues(
            'Task_Spec_Group__c',
            'Type__c'
        )[0];
        insert new Task_Spec_Group__c(
            Name = 'task spec group 1',
            Object_name__c = 'Opportunity',
            Type__c = typeVal
        );
        Task_Spec_Group__c tsg = [SELECT Id FROM Task_Spec_Group__c LIMIT 1];
        insert new Task_Spec__c(
            Task_Spec_Group__c = tsg.Id,
            Assigned_to__c = u.Id,
            Subject__c = 'sss',
            Type__c = Utilities.picklistValues('Task_Spec__c', 'Type__c')[0],
            Comments__c = 'ccc',
            Days_after__c = 2
        );
        Task_Spec__c taskSpec = [SELECT Id FROM Task_Spec__c LIMIT 1];
        String jsonString1 = JSON.serialize(
            new Map<String, Object>{
                'oppId' => opp.Id,
                'taskSpecId' => taskSpec.Id,
                'reportTaskAssignedToOverrideId' => u.Id,
                'baseDate' => null
            }
        );
        String jsonString2 = JSON.serialize(
            new Map<String, Object>{
                'oppId' => opp.Id,
                'taskSpecGroupId' => tsg.Id,
                'reportTaskAssignedToOverrideId' => u.Id,
                'baseDate' => null
            }
        );

        test.startTest();
        String jsonStr = OpportunityController.getTasksPlus(opp.Id);
        Task_Spec_Group__c[] tsgs = OpportunityController.getTaskSpecGroups(
            typeVal
        );
        system.assertNotEquals(tsgs, null);
        OpportunityController.buildTasksFromTSG(opp.Id, tsgs[0].Id, u.Id);
        OpportunityController.buildTasksFromTSGType(opp.Id, typeVal, u.Id);
        OpportunityController.instantiateTaskSpec(jsonString1);
        OpportunityController.instantiateTaskSpecGroup(jsonString2);
        test.stopTest();
        Task[] ts = OpportunityController.getTasks(opp.Id);
        system.assert(ts.size() > 0);
        Task t = ts[0];
        Date origDueDate = t.ActivityDate;
        Date newDueDate = t.ActivityDate.addDays(100);
        t.ActivityDate = newDueDate;
        String tasksJSON = JSON.serialize(new List<Task>{ t });
        OpportunityController.updateTasks(tasksJSON);
        t = [SELECT Id, ActivityDate FROM Task WHERE Id = :t.Id];
        system.assertNotEquals(origDueDate, t.ActivityDate);
    }

    static testMethod void OpportunityControllerTest2() {
        // Build new Opportunity records
        InitTestOpportunities();
        Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>(
            [
                SELECT Name, AccountId, Amount, StageName, CloseDate
                FROM Opportunity
            ]
        );

        Test.StartTest();
        Opportunity oppToClose;
        // Close the opportunity with StageName = Negotiation, causing it to be cloned.
        for (Opportunity opp : oppsMap.values()) {
            if (opp.StageName == 'Negotiation') {
                opp.StageName = 'Closed Won';
                opp.CloseDate = date.today();
                oppToClose = opp;
                break;
            }
        }
        update oppsMap.values();
        // If process that calls invocable class is in place and active, then clone should be triggered.  In case it's not,
        // call invocable class explicitly.
        OpportunityCloneInvocable.opportunityClone(
            new List<Id>{ oppToClose.Id }
        );
        Test.StopTest();

        // Get the opportunities (new and old) and validate.
        Map<Id, Opportunity> allOppsMap = new Map<Id, Opportunity>(
            [SELECT Id FROM Opportunity]
        );
        Validate(allOppsMap.keyset());
    }

    // Build two opportunities under an account.
    static void InitTestOpportunities() {
        ChartofAccounts__c objChartOfAccounts = new ChartofAccounts__c(
            Name = '#Unrestricted'
        );
        insert objChartOfAccounts;

        insert new Account(Name = 'opptest_acct_' + datetime.now());
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];

        // Build opportunities linked to appropriate account.
        List<Opportunity> opps = new List<Opportunity>();
        // The first opp will be forced to close during the test.
        string fyForOppToBeClosed = Utilities.FYfromDate(Date.today());
        opps.add(
            new Opportunity(
                Name = fyForOppToBeClosed + ': Opp for ' + acc.Name,
                Type = 'Major Gift Opportunity: Annual Gift',
                StageName = 'Negotiation',
                CloseDate = Date.Today().addDays(-1),
                AccountId = acc.Id,
                Amount = 10,
                ChartofAccounts__c = objChartOfAccounts.Id
            )
        );
        // Second and third opps will stay open during the test.
        opps.add(
            new Opportunity(
                Name = fyForOppToBeClosed + ': Open opp #1 for ' + acc.Name,
                Type = 'Major Gift Opportunity: Annual Gift',
                StageName = 'Cultivation',
                CloseDate = Date.Today().addMonths(-2), // Closes in the past
                AccountId = acc.Id,
                Amount = 20,
                ChartofAccounts__c = objChartOfAccounts.Id
            )
        );
        opps.add(
            new Opportunity(
                Name = fyForOppToBeClosed + ': Open opp #2 for ' + acc.Name,
                Type = 'Major Gift Opportunity: Annual Gift',
                StageName = 'Cultivation',
                CloseDate = Date.Today().addDays(-2), // Closes in the future
                AccountId = acc.Id,
                Amount = 21,
                ChartofAccounts__c = objChartOfAccounts.Id
            )
        );
        system.debug('InitTestOpportunities: opps = ' + JSON.serialize(opps));
        if (opps.size() > 0)
            insert opps;
    }

    // Validate the new opportunities against the old opportunities (now closed).
    public static void Validate(Set<ID> oppsIds) {
        // Grab info from accounts and linked opportunities.
        Account acc = [
            SELECT
                Id,
                OwnerId,
                Name,
                (
                    SELECT Id, AccountId, CloseDate, StageName, Amount, Name
                    FROM Opportunities
                )
            FROM Account
            WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN :oppsIds)
            ORDER BY Name
        ];

        // Not doing Assert statements, instead just displaying account and its linked opps for eyeballing.
        system.debug('Account: ' + acc.Name);
        for (Opportunity o : acc.Opportunities) {
            system.debug(
                'Validate: Opportunity: ' +
                o.Name +
                '; Stage: ' +
                o.StageName +
                '; CloseDate: ' +
                o.CloseDate +
                '; Amount: ' +
                o.Amount
            );
        }
    }
}