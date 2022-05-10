/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global abstract class TDTM_Runnable {
    global TDTM_Runnable() {

    }
    global abstract npsp.TDTM_Runnable.DmlWrapper run(List<SObject> param0, List<SObject> param1, npsp.TDTM_Runnable.Action param2, Schema.DescribeSObjectResult param3);
global enum Action {AfterDelete, AfterInsert, AfterUndelete, AfterUpdate, BeforeDelete, BeforeInsert, BeforeUpdate}
global class DmlWrapper {
    global List<SObject> objectsToDelete;
    global List<SObject> objectsToInsert;
    global List<SObject> objectsToUndelete;
    global List<SObject> objectsToUpdate;
    global List<npsp.ErrorRecord> objectsWithError;
    global DmlWrapper() {

    }
}
}
