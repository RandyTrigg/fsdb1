({
    init : function(cmp) {
        console.log('ObjectFields init enter...');
        var fieldNames = cmp.get('v.fieldNames');
        console.log('ObjectFields init: fieldNames = ' +JSON.stringify(fieldNames));
        var fNames = fieldNames.split(',');
        var fieldsArray = [];
        // Trim spaces from each field name.
        for(var i=0; i<fNames.length; i++) fieldsArray.push(fNames[i].trim());
        console.log('ObjectFields init: fieldsArray = ' +JSON.stringify(fieldsArray));
        cmp.set('v.fieldsArray', fieldsArray);
        // Use server-side apex to compute id of target record if there's a lookup field name, else use current record id. 
        if (cmp.get('v.lookupFieldName')) this.lookupFieldValue(cmp);
        else cmp.set('v.targetRecordId', cmp.get('v.recordId'));
        console.log('ObjectFields init: targetRecordId = ' +cmp.get('v.targetRecordId'));
        console.log('ObjectFields init exit...');
    },
    
    // Invoke server-side controller to look up the id of the related record using given field name.
    lookupFieldValue : function(cmp) {
        console.log('lookupFieldValue...');
        cmp.set('v.waiting', true);
        var action = cmp.get('c.fieldValueFromRecordId');
        action.setParams({
            jsonString: JSON.stringify({
                recordId: cmp.get('v.recordId'),
                fieldName: cmp.get('v.lookupFieldName')
            })
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var returnVal = JSON.parse(response.getReturnValue());
                console.log('lookupFieldValue: returnVal = ' +JSON.stringify(returnVal));
                cmp.set('v.targetRecordId', returnVal.results.fieldValue);
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
        }));
        $A.enqueueAction(action);
    },
    
})