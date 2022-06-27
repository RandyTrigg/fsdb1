// Build CSV file containing form data pivoted on form component name. Resulting CSV linked to given log record.
// Show form instances for proposals with given form names plus their profile form instance.
Id logId = Id.valueOf('a2D5d000005rHQREA2');
String[] propFormNames = new List<String> {'bff_SolidarityApplication'};
String[] fiFieldLabels = new List<String> {'Profile', 'Org', 'Form', 'Form instance', 'Date submitted'};
String[] fiFieldNames = new List<String> {'Profile__r.Name', 'Profile__r.Org_name__c', 'Form__r.Name', 'Name', 'Date_submitted__c'};

String[] formNames = new List<String> {'bff_Profile'};
formNames.addAll(propFormNames);
system.debug('propFormNames = ' +propFormNames);
system.debug('formNames = ' +formNames);

// Fetch profiles that have a prop form instance with given form name(s)
Profile__c[] profs = [
    SELECT Id 
    FROM Profile__c 
    WHERE Id IN (SELECT Profile__c FROM Form_Instance__c WHERE Form__r.Name IN :propFormNames AND Date_submitted__c <> null)
];
system.debug('profs = ' +profs);
// Fetch form instances and form data
Form_Instance__c[] fis = [
    SELECT Id, Name, Form__r.Name, Profile__r.Name, Profile__r.Org_name__c, Date_submitted__c,
    (SELECT Form_Component__c, Form_Component__r.Name, Form_Component__r.Type__c, Data_text__c, Data_textarea__c 
    FROM Form_Data__r
    )
    FROM Form_Instance__c
    WHERE Form__r.Name IN :formNames
    AND Profile__c IN :profs
    AND Date_submitted__c <> null
    ORDER BY Profile__r.Org_name__c, Form__r.Sort_number__c
];
// Gather ids of referenced form components
Set<Id> fcIds = new Set<Id>();
for (Form_Instance__c fi : fis) {
    for (Form_Data__c fd : fi.Form_Data__r) fcIds.add(fd.Form_Component__c);
}
// Fetch ordered list of form components referenced by the form data of the form instances
Form_Component__c[] fcs = [
    SELECT Id, Name
    FROM Form_Component__c
    WHERE Id IN :fcIds
    ORDER BY Form__r.Sort_number__c, Hierarchical_sort_num__c
];
// Generate CSV
String[] rowsCSV = new List<String>();
// Build column headings row
String[] colLabels = new List<String>();
colLabels.addAll(fiFieldLabels); // First columns are for fields reachable from form instance 
for (Form_Component__c fc : fcs) colLabels.add(fc.Name); // Rest of columns are for pivoted form data
system.debug(colLabels);
rowsCSV.add(String.join(colLabels, ',')); // First row is column names
// Build one data row per form instance
for (Form_Instance__c fi : fis) {
    String[] colVals = new List<String>();
    // Fill in values of form instance fields
    for (String fName : fiFieldNames) {
        String val = String.valueOf(Utilities.getValue(fi, fName));
        colVals.add(val != null ? val.escapeCSV() : '');
    }
    // Gather values of pivoted form data fields mapped by form component id
    Map<Id, String> pivotedVals = new Map<Id, String>();
    for (Form_Data__c fd : fi.Form_Data__r) {
        String dataText = fd.Data_text__c;
        String dataTextarea = fd.Data_textarea__c;
        String formCompType = fd.Form_Component__r.Type__c;
        String pivotVal = String.isBlank(dataText) ? dataTextarea :
            // Use currency format depending on form component type
            formCompType == 'currency' && isNumericOrDecimal(dataText) ? Utilities.formatCurrency(Double.valueOf(dataText)) :
            dataText;
        system.debug(pivotVal);
        pivotedVals.put(fd.Form_Component__c, pivotVal);
    }
    // Fill in columns with pivoted data
    for (Form_Component__c fc : fcs) {
        String val = pivotedVals.get(fc.Id);
        colVals.add(val != null ? val.escapeCSV() : '');
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

/*
// Could be useful to have links in csv for columns based on lookup fields, but how to get excel to render as links?
public String buildLink (String recId, String label) {
    return '<a href="https://globalfundforwomen.lightning.force.com/' +recId+ '>' +label+ '</a>';
}
*/