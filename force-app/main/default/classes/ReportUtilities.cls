public with sharing class ReportUtilities {

// For reasons unclear, the SelectOption class is not serializable as JSON in Apex, hence this simple substitute inner-class
// "Apex Type unsupported in JSON: System.SelectOption
@TestVisible private class Option {
    public String label;
    public String value;

    public Option(String l, String v) {
        this.label = l;
        this.value = v;
    }
}

@TestVisible private class TableColumn {
    public String label;
    public String fieldName;
    public String type;
    public Boolean sortable;

    public TableColumn (String label, String fieldName, String type, Boolean sortable) {
        this.label = label;
        this.fieldName = fieldName;
        this.type = type;
        this.sortable = sortable;
    }
}

// Apex Objects to simplify report data handling.  Adapted from: https://developer.salesforce.com/blogs/developer-relations/2015/03/transforming-analytics-api-data-salesforce1-lightning-components.html
public class TabularReportResponse {
    public List < fieldDef > reportFields {get; set;}
    public List< List< fieldData >> fieldDataList {get; set;}
    public Integer totalResultsCount {get; set;}
    public TabularReportResponse(){}
}

public class SummaryReportResponse {
    public List < fieldDef > reportFields {get; set;}
    public List < SummaryReportGroup > groupList {get; set;}
    public Integer totalResultsCount {get; set;}
    public SummaryReportResponse(){}
}   
 
public class SummaryReportGroup {
    public String fieldName {get; set;}
    public String fieldValue {get; set;}
    public String fieldLabel {get; set;}
    public String groupKey {get; set;} 
    public Integer fieldsInGroup {get; set;}                    
    public List<List<fieldData>> fieldDataList {get; set;}
    public SummaryReportGroup(){}
}
 
public class fieldDef {
    public String fieldName {get; set;}
    public String fieldLabel {get; set;}
    public String dataType {get; set;}
    public fieldDef(){}
}
 
public class fieldData {
    public String fieldValue {get; set;}
    public String fieldLabel {get; set;}
    public String dataType  {get; set;}
}
//-------------------------------------------------------------------------------------------------------------------------

@AuraEnabled(cacheable=true)
public static String getAvailableObjects(){
    List < Option > returnList = new List < Option >();
    List < String > objectTypes = Utilities.picklistValues('Template__c', 'Source_object__c');
    for (String obj: objectTypes) {
        returnList.add(new Option(obj,obj));
    }
    return JSON.serialize(returnList);
}   

@AuraEnabled
public static String getReportList(String objectType){
    System.debug('object type for report list: '+objectType);

    // For testing, we do not accurately get the id of recently run reports, even when using the metadata api to run them in the test
    // Therefore we have special handling for test contexts to fake the recently run report
    // Get object type from Template
    try {
        Date d = System.today().addDays(-7);
        List < Report > reports = new List < Report >();
        if (test.isRunningTest()) {
            reports = [SELECT Id, Name, DeveloperName FROM Report WHERE DeveloperName = 'Accounts_GM_TEMPLATE' OR DeveloperName = 'Proposals_TEMPLATE'];
        } else {
            reports = [SELECT Id, Name, DeveloperName FROM Report WHERE LastViewedDate>=:d ORDER BY LastViewedDate DESC LIMIT 5];
        }

        //only return reports that have an id Field for the selected object
        List < Option > optionList = filterReportsByObject(reports, objectType);
        return JSON.serialize(optionList);
    } catch (Exception e) {
        return null;
    }
    
}


//Given a list of report IDs, returns the reports that have a detail column for SObject ID matching the given object as an Option List
//Limited to 20
public static List < Option > filterReportsByObject(List < Report > reportsList, String objectName){
    //List to hold the IDs of all the reports to return
    List < Option > returnReportOptions = new List < Option >();

    // The column we're looking for is the target object ID.  Usually this is in the form of ObjectName.Id, but occasionally it is ObjectName_Id
    String sourceIdFieldName = objectName + '.Id';
    String sourceIdFieldNameAlt = objectName + '_Id';

    for (Report r: reportsList) {
        //Adding a check here for how many DML rows we're at.  Even though we have detail=false, each row in the report dings us for a DML Row, which is silly
        System.debug('Query Rows: '+Limits.getQueryRows());
        System.debug('report to run: '+r);
        if (Limits.getQueryRows()<=40000) { 
            Reports.ReportResults acctReportResults = Reports.ReportManager.runReport(r.Id, false);
            Reports.ReportMetadata rm = acctReportResults.getReportMetadata();
            List < String > columns = rm.getDetailColumns();

            Boolean idFound = false;
            if (columns.size()>0) {
                String fieldsPrefix;
                for (String detailColumn: columns) {   
                    if (detailColumn==sourceIdFieldName || detailColumn==sourceIdFieldNameAlt) {
                        idFound = true;
                        returnReportOptions.add(new Option(rm.getName(),r.Id));
                    } 
                    // Grab the Prefix on columns for use if we need to check CUST_ID
                    if (detailColumn.contains('.')){
                        List < String > parts = detailColumn.split('\\.');
                        fieldsPrefix = parts[0];
                    }  
                }
                // If we didn't get the ID, try and grab it based on prefix and CUST_ID
                if (idFound!=true && fieldsPrefix==objectName) {
                    for (String detailColumn: columns) {
                        if (detailColumn=='CUST_ID') {
                            returnReportOptions.add(new Option(rm.getName(),r.Id));
                        }
                    }
                }
            }
        }
        
    }
    return returnReportOptions;
    
}

public static List < ID > getRecordIdsFromTabularReport(String reportId, String objectName) {
    List < ID > objectRecordIds = new List < ID >();

    TabularReportResponse results = getTabularReportResponse(reportId, null);

    // First, get the index of the column with the object ID
    Integer idColumnIndex;
    String idFieldName;
    for (integer i=0; i<results.reportFields.size(); i++) {
        if (results.reportFields[i].fieldName==objectName+'.Id' || results.reportFields[i].fieldName==objectName+'_ID' || results.reportFields[i].fieldName=='CUST_ID') {
            idColumnIndex = i;
            idFieldName = results.reportFields[i].fieldName;
            break;
        }
    }

    // Grab the IDs from complete results
    for (List< fieldData > fieldList: results.fieldDataList) {
        objectRecordIds.add(fieldList[idColumnIndex].fieldValue);
    }

    // Get the rest of the results if over 2k (or 10 if test)
    Integer resultsLimit = 2000;
    if (Test.isRunningTest()) {
        resultsLimit = 10;
    }
    system.debug('ReportUtilities.getRecordIdsFromTabularReport: results.totalResultsCount = ' +results.totalResultsCount);

    if (results.totalResultsCount>resultsLimit) {
        Boolean resultsNotComplete = true;

        while (resultsNotComplete) {
            String concatenatedIds = String.join(objectRecordIds,',');
            Reports.ReportFilter RF = new Reports.ReportFilter(idFieldName, 'notEqual', concatenatedIds);
            TabularReportResponse additionalResults = getTabularReportResponse(reportId, RF);
            // Add to the ID list
            for (List< fieldData > fieldList: additionalResults.fieldDataList) {
                objectRecordIds.add(fieldList[idColumnIndex].fieldValue);
            }

            // are we done? 
            if (objectRecordIds.size()>=results.totalResultsCount) {
                resultsNotComplete = false;  //our id list has all of the possible results.  We're done
            }
            
        }
    }
    return objectRecordIds;
}

public static List < ID > getRecordIdsFromSummaryReport(String reportId, String objectName) {
    List < ID > objectRecordIds = new List < ID >();
    SummaryReportResponse results = getSummaryReportResponse(reportId, null);
 
    // First, get the index of the column with the object ID
    Integer idColumnIndex;
    String idFieldName;
    for (integer i=0; i<results.reportFields.size(); i++) {
        if (results.reportFields[i].fieldName==objectName+'.Id' || results.reportFields[i].fieldName==objectName+'_ID' || results.reportFields[i].fieldName=='CUST_ID') {
            idColumnIndex = i;
            idFieldName = results.reportFields[i].fieldName;
            break;
        }
    }

    for (SummaryReportGroup reportGrouping: results.groupList) {
        for (List< fieldData > fieldList: reportGrouping.fieldDataList) {
            if (idColumnIndex!=null) {
                objectRecordIds.add(fieldList[idColumnIndex].fieldValue);
            }
            
        }
    }

    // Get the rest of the results if over 2k
    if (results.totalResultsCount>2000) {
        Boolean resultsNotComplete = true;

        while (resultsNotComplete) {
            String concatenatedIds = String.join(objectRecordIds,',');
            Reports.ReportFilter RF = new Reports.ReportFilter(idFieldName, 'notEqual', concatenatedIds);
            SummaryReportResponse additionalResults = getSummaryReportResponse(reportId, RF);
            // Add to the ID list
            for (SummaryReportGroup reportGrouping: additionalResults.groupList) {
                for (List< fieldData > fieldList: reportGrouping.fieldDataList) {
                    objectRecordIds.add(fieldList[idColumnIndex].fieldValue);
                }
            }

            // are we done? 
            if (objectRecordIds.size()>=results.totalResultsCount) {
                resultsNotComplete = false;  //our id list has all of the possible results.  We're done
            }
            
        }
    }

    return objectRecordIds;

}


@AuraEnabled
public static Integer getRowCount(String reportId){
    
    Reports.ReportResults results = Reports.ReportManager.runReport(reportId, true);
    // Get the fact map from the report results
    Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get('T!T');

    //get the aggregate values in the report, this includes the RowCount (Grand Total) and any columns that have been summarized.
    List<Reports.SummaryValue> counts = factDetails.getAggregates();

    //The row count will be the last aggregate in the list, any summaries will come first and you can loop through them in the method below.
    Integer grandTotal =  Integer.valueOf((Decimal)counts.get(counts.size()-1).getValue());
    return grandTotal;  

}

// Methods for parsing Reports Data ------------------------------------------------------------------------------------------------------------------------
public Static TabularReportResponse getTabularReportResponse(Id reportId, Reports.ReportFilter optionalFilter) {
    TabularReportResponse trr = new TabularReportResponse();
    List < fieldDef > reportFields = new List < fieldDef >(); 
    List< List< fieldData >> fieldDataList = new List< List< fieldData >>();  

    Reports.ReportResults results;  
    if (optionalFilter!=null) {
        // get filters without running for details yet
        Reports.ReportDescribeResult reportDescribe = Reports.ReportManager.describeReport(reportId);
        Reports.ReportMetadata RM = reportDescribe.getReportMetadata();

        list<Reports.ReportFilter>allfilters = new list<Reports.ReportFilter> {optionalFilter};  //new list of filters with the passed in filter
        allfilters.addAll(RM.getReportFilters()); //add in any filters that were already on the report

        // Handle any filter logic
        String booleanFilter = RM.getReportBooleanFilter();
        if (String.isNotBlank(booleanFilter)) {
            RM.setReportBooleanFilter('(' + booleanFilter + ') AND ' + allfilters.size());
        }
        RM.setReportFilters(allfilters);
        //get the report result
        results = Reports.ReportManager.runReport(reportId, RM, true);
    } else {
        //No filter provided, run as-is
        results = Reports.ReportManager.runReport(reportId, true);
    }
 
    // Get the grand Total
    Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get('T!T');     
    List<Reports.SummaryValue> counts = factDetails.getAggregates();
    Integer grandTotal =  Integer.valueOf((Decimal)counts.get(counts.size()-1).getValue());

    // // Can only support up to 5k rows currentl (could stretch to 8k max, but risk cpu limits)
    // if (grandTotal>8000 && Test.isRunningTest()!= true) {
    //     throw new GFW_Exception('getTabularReportResponse', 'Report Utilities can only support reports with up to 8,000 rows. Add filters to your report to reduce size or pick another report with fewer results.');
    // }

    //get the metadata
    Reports.ReportMetadata reportMetadata = results.getReportMetadata();
 
    //get a string array of the field names
    List < String > fieldNames = reportMetadata.getDetailColumns();    
 
    //get the extended metadata
    Reports.ReportExtendedMetadata reportExtendedMetadata = results.getReportExtendedMetadata();
 
    //get the map of the column names to their name and label
    Map<String, Reports.DetailColumn> detailColumnMap = reportExtendedMetadata.getDetailColumnInfo();
    //loop over the detailColumnMap and get the name, label, and data type
    for (String fieldName: fieldNames) {
        Reports.DetailColumn detailColumn = detailColumnMap.get(fieldName);
        fieldDef fd = new fieldDef();
        fd.fieldName = detailColumn.getName(); 
        fd.fieldLabel = detailColumn.getLabel();
        //There is an issue with calling getDataType on certain fields, namely a field with datatype of Address.  We will skip the dataType when we can't determine it
        if (detailColumn.getDataType()!=null) {
            fd.dataType = detailColumn.getDataType().name(); 
        }
        reportFields.add(fd);
        
    }

    List<Reports.ReportDetailRow> reportDetailRowList = factDetails.getRows();
    //loop over the rows
    for (Reports.ReportDetailRow reportDetailRow: reportDetailRowList) {
        Integer cellCounter = 0;
        List<fieldData> fieldDataRow = new List<fieldData>();
        //loop over the cells in the row
        for (Reports.ReportDataCell reportDataCell: reportDetailRow.getDataCells()) {
            fieldData fd = new fieldData();
            fd.dataType = reportFields[cellCounter].dataType;
            fd.fieldLabel = (String)reportDataCell.getLabel();
            fd.fieldValue = String.valueOf(reportDataCell.getValue());
            cellCounter++;
            fieldDataRow.add(fd);
        }
 
        //add the row to the list
        fieldDataList.add(fieldDataRow);
    }

    trr.reportFields = reportFields;
    trr.fieldDataList = fieldDataList;
    trr.totalResultsCount = grandTotal;
    return trr;
}

public static SummaryReportResponse getSummaryReportResponse(Id reportId, Reports.ReportFilter optionalFilter) {
    SummaryReportResponse srr = new SummaryReportResponse();
    List < fieldDef > reportFields = new List < fieldDef >(); 
    
    Reports.ReportResults results;  
    if (optionalFilter!=null) {
        // get filters without running for details yet
        Reports.ReportDescribeResult reportDescribe = Reports.ReportManager.describeReport(reportId);
        Reports.ReportMetadata RM = reportDescribe.getReportMetadata();

        list<Reports.ReportFilter>allfilters = new list<Reports.ReportFilter> {optionalFilter};  //new list of filters with the passed in filter
        allfilters.addAll(RM.getReportFilters()); //add in any filters that were already on the report

        // Handle any filter logic
        String booleanFilter = RM.getReportBooleanFilter();
        if (String.isNotBlank(booleanFilter)) {
            RM.setReportBooleanFilter('(' + booleanFilter + ') AND ' + allfilters.size());
        }
        RM.setReportFilters(allfilters);
        //get the report result
        results = Reports.ReportManager.runReport(reportId, RM, true);

    } else {
        //No filter provided, run as-is
        results = Reports.ReportManager.runReport(reportId, true);
    }
    // Get the grand Total
    Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get('T!T');     
    List<Reports.SummaryValue> counts = factDetails.getAggregates();
    Integer grandTotal =  Integer.valueOf((Decimal)counts.get(counts.size()-1).getValue());

    // // Can only support up to 5k rows currentl (could stretch to 8k max, but risk cpu limits)
    // if (grandTotal>8000) {
    //     throw new GFW_Exception('getSummaryReportResponse', 'Report Utilities can only support reports with up to 8,000 rows. Add filters to your report to reduce size or pick another report with fewer results.');
    // }

    //get the metadata
    Reports.ReportMetadata reportMetadata = results.getReportMetadata();
 
    //get a string array of the field names
    List < String > fieldNames = reportMetadata.getDetailColumns();       

    //get the extended metadata
    Reports.ReportExtendedMetadata reportExtendedMetadata = results.getReportExtendedMetadata();
 
    //get the map of the column names to their name and label
    Map<String, Reports.DetailColumn> detailColumnMap = reportExtendedMetadata.getDetailColumnInfo();

    //get the map of the grouping column names to their name and label
    Map<String, Reports.GroupingColumn> groupingColumnMap = reportExtendedMetadata.getGroupingColumnInfo();       
 
    //get the grouping column info
    Reports.GroupingInfo groupingInfo = reportMetadata.getGroupingsDown()[0]; //only supports one grouping level
    Reports.GroupingColumn groupingColumnDetail = groupingColumnMap.get(groupingInfo.getName());                
 
    //loop over the detailColumnMap and get the name, label, and data type
    for (String fieldName: fieldNames) {
        Reports.DetailColumn detailColumn = detailColumnMap.get(fieldName);
        fieldDef fd = new fieldDef();
        fd.fieldName = detailColumn.getName(); 
        fd.fieldLabel = detailColumn.getLabel();
        //There is an issue with calling getDataType on certain fields, namely a field with datatype of Address.  We will skip the dataType when we can't determine it
        if (detailColumn.getDataType()!=null) {
            fd.dataType = detailColumn.getDataType().name();
        }
        reportFields.add(fd);
    }
    srr.reportFields = reportFields;
 
    //get the summary grouping down dimension grouping values.  only going 1 level deep
    List < SummaryReportGroup > groupList = new List < SummaryReportGroup > ();
    for (Reports.GroupingValue groupingValue: results.getGroupingsDown().getGroupings()) {
        SummaryReportGroup srg = new SummaryReportGroup();
        srg.fieldName = groupingColumnDetail.getLabel();            
        srg.fieldValue = (String)groupingValue.getValue();
        srg.fieldLabel = groupingValue.getLabel();
        srg.groupKey = groupingValue.getKey();

        //use our group key to get the group rows from the fact map
        Reports.ReportFactWithDetails groupedFactDetails = (Reports.ReportFactWithDetails)results.getFactMap().get(srg.groupKey+'!T'); 
        List<Reports.ReportDetailRow> reportDetailRowList = groupedFactDetails.getRows();           
 
        List<List<fieldData>> fieldDataList = new List<List<fieldData>>();
 
        //loop over the rows
        for (Reports.ReportDetailRow reportDetailRow: reportDetailRowList) {
            Integer cellCounter = 0;
            List<fieldData> fieldDataRow = new List<fieldData>();
            //loop over the cells in the row
            for (Reports.ReportDataCell reportDataCell: reportDetailRow.getDataCells()) {
                fieldData fd = new fieldData();
                fd.dataType = reportFields[cellCounter].dataType;
                fd.fieldLabel = (String)reportDataCell.getLabel();
                fd.fieldValue = String.valueOf(reportDataCell.getValue());
                cellCounter++;
                fieldDataRow.add(fd);
            }
 
            //add the row to the list
            fieldDataList.add(fieldDataRow);
        }           
        srg.fieldsInGroup = srr.reportFields.size();            
        srg.fieldDataList = fieldDataList;
        groupList.add(srg);
    }
    srr.groupList = groupList;
    srr.totalResultsCount = grandTotal;
 
    return srr;
}


}