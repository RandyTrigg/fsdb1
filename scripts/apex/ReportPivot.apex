// Build CSV file containing data from given report, "pivoting" on given field. Resulting CSV linked to given log record.
// Requirements on input report:
// - based on Form Data
// - includes columns for form component name, form component type, Data text, and Data textarea
// - has one grouper (e.g. form instance)
// - includes column to pivot on with given api name (e.g. form component)
// - total rows less than 5K
Id repId = Id.valueOf('00O5d000006qq6rEAA');
Id logId = Id.valueOf('a2D5d000005rHQREA2');
String pivotColName = 'Form_Data__c.Form_Component__c.Name__lookup';
String dataTextColName = 'Form_Data__c.Data_text__c';
String dataTextareaColName = 'Form_Data__c.Data_textarea__c';
String formCompTypeColName = 'Form_Data__c.Form_Component__c.Type__c';
String formDataIdName = 'Form_Data__c.Id';

// Fetch summary report info, including data organized by groups
ReportUtilities.SummaryReportResponse srr = ReportUtilities.getSummaryReportResponse(repId, null);
ReportUtilities.fieldDef[] fieldDefs = srr.reportFields;
ReportUtilities.SummaryReportGroup[] groups = srr.groupList;
Integer rowCount = srr.totalResultsCount;
system.debug(fieldDefs[0]);
system.debug(groups[0]);
system.debug('num columns = ' +fieldDefs.size());
system.debug('num rows = ' +rowCount);
system.debug('num groups = ' +groups.size());
// Compute indexes of key columns
Integer pivotColIndex, dataTextColIndex, dataTextareaColIndex, formCompTypeColIndex, FormDataIdIndex;
for (Integer i=0; i<fieldDefs.size(); i++) {
    ReportUtilities.fieldDef f = fieldDefs[i];
    system.debug(f.fieldName);
    if (f.fieldName == pivotColName) pivotColIndex = i;
    else if (f.fieldName == dataTextColName) dataTextColIndex = i;
    else if (f.fieldName == dataTextareaColName) dataTextareaColIndex = i;
    else if (f.fieldName == formCompTypeColName) formCompTypeColIndex = i;
    else if (f.fieldName == formDataIdName) FormDataIdIndex = i;
}
system.debug('dataTextColIndex,dataTextareaColIndex,formCompTypeColIndex,FormDataIdIndex = ' +
    dataTextColIndex +','+ dataTextareaColIndex +','+ formCompTypeColIndex +','+ FormDataIdIndex);
system.debug('pivotColIndex = ' +pivotColIndex);
// Gather unique values of pivotCol across entire report
Set<String> pivotVals = new Set<String>();
Set<Id> formDataIds = new Set<Id>();
for (ReportUtilities.SummaryReportGroup grp : groups) {
    for (List<ReportUtilities.fieldData> row : grp.fieldDataList) {
        pivotVals.add(row[pivotColIndex].fieldLabel);
        formDataIds.add(Id.valueOf(row[FormDataIdIndex].fieldLabel));
    }
}
// Fetch all referenced form components, and sort by form sort number and component sort number
Form_Component__c[] fcs = [
    SELECT Name
    FROM Form_Component__c
    WHERE Id IN (SELECT Form_Component__c FROM Form_Data__c WHERE Id IN :formDataIds)
    ORDER BY FORM__r.Sort_number__c, Hierarchical_sort_num__c
];
// Turn pivot col values into an ordered list of column labels
List<String> pivotedColLabels = new List<String>();
for (Form_Component__c fc : fcs) {
    if (pivotVals.contains(fc.Name)) pivotedColLabels.add(fc.Name);
}
system.debug(pivotedColLabels);
// Generate CSV
String[] rowsCSV = new List<String>();
// Compute first row of column labels
String[] colLabels = new List<String>();
colLabels.add(groups[0].fieldName); // First column is the grouper
for (Integer i=0; i<fieldDefs.size(); i++) {
    ReportUtilities.fieldDef f = fieldDefs[i];
    system.debug(f.fieldName);
    // Grab field labels, skipping fields in Form Data, and replacing pivot column by list of pivoted column names
    if (f.fieldName.countMatches('.') > 1) { // Skip unless related field
        String fName = f.fieldName;
        if (i == pivotColIndex) colLabels.addAll(pivotedColLabels);
        else if (!fName.contains('Form_Component__c')) {
            system.debug('Not skipping column for related field: ' +fName);
            colLabels.add(f.fieldLabel);
        }
        else system.debug('Skipped column for related field: ' +fName);
    }
}
system.debug(colLabels);
rowsCSV.add(String.join(colLabels, ',')); // First row is column names
// Compute data rows by converting each group into a single csv row
for (ReportUtilities.SummaryReportGroup grp : groups) {
    String[] colVals = new List<String>();
    List<List<ReportUtilities.fieldData>> rows = grp.fieldDataList;
    // Gather form data values for each form component in the group
    Map<String, String> pivotedVals = new Map<String, String>();
    for (List<ReportUtilities.fieldData> row : rows) {
        String dataText = row[dataTextColIndex].fieldValue;
        String dataTextarea = row[dataTextareaColIndex].fieldValue;
        String formCompType = formCompTypeColIndex >= 0 ? row[formCompTypeColIndex].fieldValue : null;
        String pivotVal = String.isBlank(dataText) ? dataTextarea :
            // Use currency format depending on form component type
            formCompType == 'currency' && isNumericOrDecimal(dataText) ? Utilities.formatCurrency(Double.valueOf(dataText)) :
            dataText;
        system.debug(pivotVal);
        pivotedVals.put(row[pivotColIndex].fieldLabel, pivotVal);
    }
    // Build csv from values in the first row of the group, inserting columns for the pivoted values
    colVals.add(grp.fieldLabel.escapeCSV()); // First column is grouper
    for (Integer i=0; i<fieldDefs.size(); i++) {
        ReportUtilities.fieldDef f = fieldDefs[i];
        // Grab field values, skipping fields in Form Data, and replacing pivot column by list of pivoted column values
        if (f.fieldName.countMatches('.') > 1) { // Skip unless related field
            String fName = f.fieldName;
            if (i == pivotColIndex) { // At pivot column insert ordered list of pivoted values
                for (String pivLabel : pivotedColLabels) {
                    String pivVal = pivotedVals.get(pivLabel);
                    colVals.add(pivVal != null ? pivVal.escapeCSV() : '');
                }
            }
            else if (!fName.contains('Form_Component__c')) { // Ignore columns for form component
                String val = rows[0][i].fieldLabel;
                colVals.add(val != null ? val.escapeCSV() : '');
            }
        }
    }
    rowsCSV.add(String.join(colVals, ','));
}
system.debug('num output rows = ' +rowsCSV.size());
system.debug(rowsCSV[0]);
system.debug(rowsCSV[1]);
String dataCSV = String.join(rowsCSV, '\n');
// Stash in file linked to log record
Utilities.buildFileRecord(dataCSV, '.csv', 'Pivoted Report', logId);

// Should this be added to Utilities? Does it recognize negative decimals?
public Boolean isNumericOrDecimal(String s){
    if(s == null) return false;
    else if(s.contains('.') && s.indexOf('.') == s.lastIndexOf('.'))
        s = s.replace('.','');
    return s.isNumeric();
}
// Could be useful to have links in csv for columns based on lookup fields, but how to get excel to render as links?
public String buildLink (String recId, String label) {
    return '<a href="https://globalfundforwomen.lightning.force.com/' +recId+ '>' +label+ '</a>';
}