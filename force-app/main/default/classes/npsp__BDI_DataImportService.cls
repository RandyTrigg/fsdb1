/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class BDI_DataImportService {
    global npsp__Data_Import_Settings__c diSettings {
        get;
    }
    global Boolean isDryRun {
        get;
    }
    global List<npsp__DataImport__c> listDI;
    global static List<String> listStrDataImportFields {
        get;
        set;
    }
    global Account AccountFromDi(npsp__DataImport__c dataImport, Integer iAcc) {
        return null;
    }
    global Contact contactFromDi(npsp__DataImport__c dataImport, Integer contactNumber) {
        return null;
    }
    global static Map<String,String> mapFieldsForDIObject(String dataImportObjectName, String targetObjectName, List<String> dataImportFields) {
        return null;
    }
}
