@isTest
public class FundControllerTest {
    static testMethod void FundControllerTest1() {
        // Build new records.
        insert new ChartofAccounts__c(Name = 'Test c-of-a');
        ChartofAccounts__c cOfA = [
            SELECT Id
            FROM ChartofAccounts__c
            WHERE Name = 'Test c-of-a'
            LIMIT 1
        ];
        String fy = String.valueOf(Date.today().year());
        insert new Fund__c(
            // Record type Overhead is currently (10/14/20) hidden for FFDB
            RecordTypeId = Utilities.getRecTypeId(
                'Fund__c',
                'Standard' // 'Overhead'
            ),
            Name = 'Testfundoverhead',
            Amount_funded__c = 0,
            Fiscal_year__c = fy
        );
        insert new Fund__c(
            RecordTypeId = Utilities.getRecTypeId('Fund__c', 'Standard'),
            Name = 'Testfundstandard',
            Amount_funded__c = 100,
            Fiscal_year__c = fy
        );
        Fund__c fund1 = [
            SELECT Id
            FROM Fund__c
            WHERE Name = 'Testfundstandard'
            LIMIT 1
        ];
        insert new Fund__c(
            // Record type Pending is currently (10/14/20) hidden for FFDB
            RecordTypeId = Utilities.getRecTypeId(
                'Fund__c',
                'Standard' // 'Pending'
            ),
            Name = 'Testfundpending',
            Amount_funded__c = 100,
            Fiscal_year__c = fy
        );
        Fund__c fund2 = [
            SELECT Id
            FROM Fund__c
            WHERE Name = 'Testfundpending'
            LIMIT 1
        ];
        insert new Projection__c(
            ChartofAccounts__c = cOfA.Id,
            Fiscal_year__c = fy,
            Fund__c = fund1.Id,
            Grantmaking_amount__c = 100,
            Non_grantmaking_amount__c = 10
        );
        insert new Distribution__c(
            Source_fund__c = fund2.Id,
            Target_fund__c = fund1.Id,
            Fiscal_year__c = fy,
            Amount__c = 200
        );
        // Build a fund with no projections/distributions whose total amount projected needs to be zeroed out.
        insert new Fund__c(
            RecordTypeId = Utilities.getRecTypeId('Fund__c', 'Standard'),
            Name = 'Testfundstandard 3',
            Amount_funded__c = 100,
            Total_available__c = 10
        );

        Test.StartTest();
        FundController.updateTotals(null);
        Test.StopTest();
        Fund__c fund0 = [
            SELECT Id, Total_available__c
            FROM Fund__c
            WHERE Name = 'Testfundoverhead'
            LIMIT 1
        ];
        fund1 = [
            SELECT Id, Total_available__c
            FROM Fund__c
            WHERE Name = 'Testfundstandard'
            LIMIT 1
        ];
        fund2 = [
            SELECT Id, Total_available__c
            FROM Fund__c
            WHERE Name = 'Testfundpending'
            LIMIT 1
        ];
        Fund__c fund3 = [
            SELECT Id, Total_available__c
            FROM Fund__c
            WHERE Name = 'Testfundstandard 3'
            LIMIT 1
        ];
        // Asserts temporarily commented out (10/14/20). Bring them back when fund record types are reactivated.
        /*
        system.assertEquals(10, fund0.Total_available__c);
        system.assertEquals(300, fund1.Total_available__c);
        system.assertEquals(null, fund2.Total_available__c);
        system.assertEquals(0, fund3.Total_available__c);
        */
        // Update total via invocable and schedule for code coverage.
        FundUpdateTotalInvocable.updateTotal(new List<Id>{ fund1.Id });
        System.schedule(
            'UpdateTotals test',
            '0 0 0 15 3 ?',
            new FundUpdateTotalsSchedule()
        );
    }

    static testMethod void FundControllerTest2() {
        // Build new records.
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'acc test',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Proposal__c(Account__c = acc.Id);
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new ChartofAccounts__c(Name = 'Test c-of-a');
        ChartofAccounts__c cOfA = [
            SELECT Id
            FROM ChartofAccounts__c
            WHERE Name = 'Test c-of-a'
            LIMIT 1
        ];
        String fy = String.valueOf(Date.today().year());
        insert new Fund__c(
            RecordTypeId = Utilities.getRecTypeId('Fund__c', 'Standard'),
            Name = 'Testfundstandard',
            Amount_funded__c = 100,
            Active__c = true
        );
        Fund__c fund1 = [
            SELECT Id
            FROM Fund__c
            WHERE Name = 'Testfundstandard'
            LIMIT 1
        ];
        insert new Fund__c(
            // Record type Pending is currently (10/14/20) hidden for FFDB
            RecordTypeId = Utilities.getRecTypeId(
                'Fund__c',
                'Standard' // 'Pending'
            ),
            Name = 'Testfundpending',
            Amount_funded__c = 100,
            Active__c = true
        );
        Fund__c fund2 = [
            SELECT Id
            FROM Fund__c
            WHERE Name = 'Testfundpending'
            LIMIT 1
        ];
        insert new Projection__c(
            ChartofAccounts__c = cOfA.Id,
            Fiscal_year__c = fy,
            Fund__c = fund1.Id,
            Grantmaking_amount__c = 100,
            Non_grantmaking_amount__c = 0
        );
        Projection__c proj = [SELECT Id FROM Projection__c LIMIT 1];
        insert new Distribution__c(
            Source_fund__c = fund2.Id,
            Target_fund__c = fund1.Id,
            Fiscal_year__c = fy,
            Amount__c = 200
        );
        insert new Charge__c(
            Proposal__c = prop.Id,
            Projection__c = proj.Id,
            Fund__c = fund1.Id,
            Amount_charged__c = 100
        );
        Charge__c chg = [SELECT Id FROM Charge__c LIMIT 1];
        String jsonString = JSON.serialize(
            new Map<String, Object>{
                'chargeIds' => new List<String>{ chg.Id },
                'projectionId' => proj.Id,
                'distributionId' => null,
                'dateReleased' => Date.today()
            }
        );

        Test.StartTest();
        FundController.getRecordsForReleasing(fund1.Id);
        Test.StopTest();

        proj = [SELECT Id, Amount_released__c FROM Projection__c LIMIT 1];
        system.assertEquals(100, proj.Amount_released__c);
    }

    static testMethod void FundControllerTest3() {
        // Build new records.
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'acc test',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Proposal__c(Account__c = acc.Id);
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new ChartofAccounts__c(Name = 'Test c-of-a');
        ChartofAccounts__c cOfA = [
            SELECT Id
            FROM ChartofAccounts__c
            WHERE Name = 'Test c-of-a'
            LIMIT 1
        ];
        String fy = String.valueOf(Date.today().year());
        insert new Fund__c(
            RecordTypeId = Utilities.getRecTypeId('Fund__c', 'Standard'),
            Name = 'Testfundstandard',
            Amount_funded__c = 100,
            Active__c = true
        );
        Fund__c fund1 = [
            SELECT Id
            FROM Fund__c
            WHERE Name = 'Testfundstandard'
            LIMIT 1
        ];
        insert new Fund__c(
            // Record type Pending is currently (10/14/20) hidden for FFDB
            RecordTypeId = Utilities.getRecTypeId(
                'Fund__c',
                'Standard' // 'Pending'
            ),
            Name = 'Testfundpending',
            Amount_funded__c = 100,
            Active__c = true
        );
        Fund__c fund2 = [
            SELECT Id
            FROM Fund__c
            WHERE Name = 'Testfundpending'
            LIMIT 1
        ];
        insert new Projection__c(
            ChartofAccounts__c = cOfA.Id,
            Fiscal_year__c = fy,
            Fund__c = fund1.Id,
            Grantmaking_amount__c = 100,
            Non_grantmaking_amount__c = 0
        );
        Projection__c proj = [SELECT Id FROM Projection__c LIMIT 1];
        insert new Distribution__c(
            Source_fund__c = fund2.Id,
            Target_fund__c = fund1.Id,
            Fiscal_year__c = fy,
            Amount__c = 200
        );
        insert new Charge__c(
            Proposal__c = prop.Id,
            Projection__c = proj.Id,
            Fund__c = fund1.Id,
            Amount_charged__c = 100
        );
        Charge__c chg = [SELECT Id FROM Charge__c LIMIT 1];
        String jsonString = JSON.serialize(
            new Map<String, Object>{
                'chargeIds' => new List<String>{ chg.Id },
                'projectionId' => proj.Id,
                'distributionId' => null,
                'dateReleased' => Date.today()
            }
        );

        Test.StartTest();
        // Unrelease that single charge.
        String responseString = FundController.unreleaseCharges(jsonString);
        system.debug('responseString = ' + responseString);
        chg = [
            SELECT Id, Date_released__c, Projection__c
            FROM Charge__c
            LIMIT 1
        ];
        system.assertEquals(null, chg.Projection__c);
        system.assertEquals(null, chg.Date_released__c);
        // Reset the projection's released amount.
        FundController.updateProjsDistsReleasing(fund1.Id);
        Test.StopTest();
    }

    // Release a charge that is more than the projection, forcing clone/split of the charge.
    static testMethod void FundControllerTest4() {
        // Build new records.
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'acc test',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Proposal__c(Account__c = acc.Id);
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        insert new ChartofAccounts__c(Name = 'Test c-of-a');
        ChartofAccounts__c cOfA = [
            SELECT Id
            FROM ChartofAccounts__c
            WHERE Name = 'Test c-of-a'
            LIMIT 1
        ];
        String fy = String.valueOf(Date.today().year());
        insert new Fund__c(
            RecordTypeId = Utilities.getRecTypeId('Fund__c', 'Standard'),
            Name = 'Testfundstandard',
            Amount_funded__c = 100,
            Active__c = true
        );
        Fund__c fund1 = [
            SELECT Id
            FROM Fund__c
            WHERE Name = 'Testfundstandard'
            LIMIT 1
        ];
        insert new Fund__c(
            // Record type Pending is currently (10/14/20) hidden for FFDB
            RecordTypeId = Utilities.getRecTypeId(
                'Fund__c',
                'Standard' // 'Pending'
            ),
            Name = 'Testfundpending',
            Amount_funded__c = 100,
            Active__c = true
        );
        Fund__c fund2 = [
            SELECT Id
            FROM Fund__c
            WHERE Name = 'Testfundpending'
            LIMIT 1
        ];
        insert new Projection__c(
            ChartofAccounts__c = cOfA.Id,
            Fiscal_year__c = fy,
            Fund__c = fund1.Id,
            Grantmaking_amount__c = 100,
            Non_grantmaking_amount__c = 0
        );
        Projection__c proj = [SELECT Id FROM Projection__c LIMIT 1];
        insert new Distribution__c(
            Source_fund__c = fund2.Id,
            Target_fund__c = fund1.Id,
            Fiscal_year__c = fy,
            Amount__c = 200
        );
        insert new Charge__c(
            Proposal__c = prop.Id,
            Fund__c = fund1.Id,
            Amount_charged__c = 130
        );
        Charge__c chg = [SELECT Id FROM Charge__c LIMIT 1];
        String jsonString = JSON.serialize(
            new Map<String, Object>{
                'chargeIds' => new List<String>{ chg.Id },
                'projectionId' => proj.Id,
                'distributionId' => null,
                'dateReleased' => Date.today()
            }
        );

        Test.StartTest();
        FundController.releaseCharges(jsonString);
        Test.StopTest();

        Charge__c[] chgs = [
            SELECT Id, Date_released__c, Projection__c, Amount_charged__c
            FROM Charge__c
            ORDER BY CreatedDate
        ];
        // There should be two charges; the original is released, the new one still not released.
        system.assertEquals(2, chgs.size());
        system.assertEquals(100, chgs[0].Amount_charged__c);
        system.assertEquals(proj.Id, chgs[0].Projection__c);
        system.assertNotEquals(null, chgs[0].Date_released__c);
        system.assertEquals(30, chgs[1].Amount_charged__c);
        system.assertEquals(null, chgs[1].Projection__c);
        system.assertEquals(null, chgs[1].Date_released__c);
    }
}