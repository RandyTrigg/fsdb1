@isTest
private class ReportUtilitiesTest {
    

    @isTest
    static void getAvailableObjectsTest() {
        String jsonReturnList = ReportUtilities.getAvailableObjects();
        List < ReportUtilities.Option > options = (List < ReportUtilities.Option >)JSON.deserialize(jsonReturnList, List < ReportUtilities.Option>.class);
        Set < String > optionSet = new Set < String >();
        for (ReportUtilities.Option opt: options) {
            optionSet.add(opt.value);
        }
        System.assertEquals(true, optionSet.contains('Account'));

    }   

    //https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_analytics_test_reports.htm
    @isTest(SeeAllData='true') //SeeAllData gives us access to reports & report runs use seealldata=true regardless of this setting
    static void getReportListTest() {
        
        List <Report> reportList = [SELECT Id, DeveloperName FROM Report WHERE DeveloperName LIKE 'Accounts_GM_TEMPLATE%'];
        String reportId = (String)reportList.get(0).get('Id');
      
        // Create Account/Proposal
        insert new Region__c (Name = 'test region');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account (Name = 'test account', GM_region__c = reg.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Proposal__c (Account__c = a.Id);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];

        // Get Report Metadata
        Reports.ReportMetadata reportMetadata = Reports.ReportManager.describeReport(reportId).getReportMetadata();
        
        // Since report runs in test mode ALWAYS uses seealldata=true, apply a filter
        List<Reports.ReportFilter> filters = new List<Reports.ReportFilter>(); 
        Reports.ReportFilter newFilter = new Reports.ReportFilter();
        newFilter.setColumn('Account.GM_region__c');
        newFilter.setOperator('equals');
        newFilter.setValue(reg.Id);
        filters.add(newFilter);
        reportMetadata.setReportFilters(filters);

        Test.startTest();
       
        Reports.ReportInstance instanceObj = Reports.ReportManager.runAsyncReport(reportId,reportMetadata,false);
        String instanceId = instanceObj.getId();
        
        // Report instance is not available yet.
        Test.stopTest();
        // After the stopTest method, the report has finished executing and should be avail in ReportUtilities
        String returnReportList = ReportUtilities.getReportList('Account');
        List < ReportUtilities.Option > reportOptions = (List < ReportUtilities.Option >)JSON.deserialize(returnReportList, List < ReportUtilities.Option >.class);
  
    }

    @isTest(SeeAllData='true') //SeeAllData gives us access to reports & report runs use seealldata=true regardless of this setting
    static void getTabularRealReportDataTest() {
        List <Report> reportList = [SELECT Id,DeveloperName FROM Report where DeveloperName LIKE 'Accounts_GM_TEMPLATE%'];
        String reportId = (String)reportList.get(0).get('Id');
      
        // Create Account/Proposal
        insert new Region__c (Name = 'test region');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account (Name = 'test account', GM_region__c = reg.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Proposal__c (Account__c = a.Id);
        Proposal__c p = [SELECT Id FROM Proposal__c LIMIT 1];


        Reports.ReportMetadata reportMetadata = Reports.ReportManager.describeReport(reportId).getReportMetadata();
        
        List < String > columns = reportMetadata.getDetailColumns();
        System.debug('columns: '+columns);

        // Since report runs in test mode ALWAYS use seealldata=true, apply a filter
        List<Reports.ReportFilter> filters = new List<Reports.ReportFilter>(); 
        Reports.ReportFilter newFilter = new Reports.ReportFilter();
        newFilter.setColumn('Account.GM_region__c');
        newFilter.setOperator('equals');
        newFilter.setValue(String.valueOf(reg.Id));
        filters.add(newFilter);
        reportMetadata.setReportFilters(filters);

        Test.startTest();
       
        Reports.ReportInstance instanceObj = Reports.ReportManager.runAsyncReport(reportId,reportMetadata,false);
        String instanceId = instanceObj.getId();
        
        // Report instance is not available yet.
        Test.stopTest();
        // After the stopTest method, the report has finished executing and should be avail in ReportUtilities
        ReportUtilities.getRecordIdsFromTabularReport (reportId, 'Account');


    }


    @isTest(SeeAllData='true') //SeeAllData gives us access to reports & report runs use seealldata=true regardless of this setting
    static void getSummaryRealReportDataTest() {
        List <Report> reportList = [SELECT Id,DeveloperName FROM Report where DeveloperName LIKE 'Proposals_TEMPLATE%'];
        String reportId = (String)reportList.get(0).get('Id');
      
        // Create Account/Proposal
        insert new Region__c (Name = 'test region');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account (Name = 'test account', GM_region__c = reg.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        Account a = [SELECT Id FROM Account LIMIT 1];
        insert new Proposal__c (Account__c = a.Id, SavedSetNames__c = 'test savedsetname');
        Proposal__c p = [SELECT Id, SavedSetNames__c FROM Proposal__c LIMIT 1];


        Reports.ReportMetadata reportMetadata = Reports.ReportManager.describeReport(reportId).getReportMetadata();
        
        List < String > columns = reportMetadata.getDetailColumns();
        System.debug('columns: '+columns);

        // Since report runs in test mode ALWAYS use seealldata=true, apply a filter
        List<Reports.ReportFilter> filters = new List<Reports.ReportFilter>(); 
        Reports.ReportFilter newFilter = new Reports.ReportFilter();
        newFilter.setColumn('Proposal__c.SavedSetNames__c');
        newFilter.setOperator('equals');
        newFilter.setValue('test savedsetname');
        filters.add(newFilter);
        reportMetadata.setReportFilters(filters);

        Test.startTest();
       
        Reports.ReportInstance instanceObj = Reports.ReportManager.runAsyncReport(reportId,reportMetadata,false);
        String instanceId = instanceObj.getId();
        
        // Report instance is not available yet.
        Test.stopTest();
        // After the stopTest method, the report has finished executing and should be avail in ReportUtilities
        ReportUtilities.getRecordIdsFromSummaryReport (reportId, 'Proposal__c');

    }

    @isTest(SeeAllData='true') //SeeAllData gives us access to reports & report runs use seealldata=true regardless of this setting
    static void getRowCountTest() {
        List <Report> reportList = [SELECT Id,DeveloperName FROM Report where DeveloperName LIKE 'Accounts_GM_TEMPLATE%'];
        String reportId = (String)reportList.get(0).get('Id');

        // test the row Count method-- Because the report will always run with seealldata=true, we can't know how many rows there will be
        //https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_analytics_test_reports.htm
        Integer rowCount = ReportUtilities.getRowCount(reportId);
        System.assertEquals(true, rowCount>0);
        
    }

}