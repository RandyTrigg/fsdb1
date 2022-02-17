({
    propRecordUpdated: function(component, event, helper) {
        console.log('propRecordUpdated: ...');
        component.set("v.propLoaded", true);
        component.find('accData').reloadRecord(true); // Refetch the account data now that we've gotten the acc id from the proposal.
    },
    
    accRecordUpdated: function(component, event, helper) {
        console.log('accRecordUpdated: ...');
        helper.checkBlankFields(component);
        component.set("v.saveNeeded", false);
        component.set("v.accLoaded", true);
    },
    
    // See if the input field's value actually changed - indicate with a dirty flag.
    // NOTE: This depends on the inputField having the full field name (with record prefix) as aura:id. 
    fieldEdited: function(component, event, helper) {
        console.log('fieldEdited: ...');
        var dirtyFlags = component.get('v.dirtyFlags') || new Object();
        var fName = event.getSource().getLocalId();
        var value = event.getSource().get("v.value");
        var storedVal = component.get('v.'+fName);
        console.log('fieldEdited: fName = ' +fName+ '; value: ' +value+ '; storedVal = ' +storedVal);
        dirtyFlags[fName] = !!(storedVal != value && (value || storedVal)); // Handle case when value is blank and storedVal is null.
        console.log('fieldEdited: dirtyFlags = ' +JSON.stringify(dirtyFlags));
        component.set('v.dirtyFlags', dirtyFlags);
        helper.setSaveNeeded(component);
    },
    
    handleSuccess: function(component, event, helper) {
        console.log('handleSuccess: ...');
        component.set("v.saveNeeded", false);
        component.set('v.waiting', false);
    },
    
    handleSaveChanges: function(component, event, helper) {
        console.log('handleSaveChanges: ...');
        helper.checkBlankFields(component);
        component.set('v.waiting', true);
    },
    
    handleSubmitRequest: function(component, event, helper) {
        console.log('handleSubmitRequest: ...');
        component.set('v.waiting', true);
        var buttonName = event.getSource().get("v.name");
        console.log('handleSubmitRequest: buttonName = ' +buttonName);
        var fields = {};
        console.log('handleSubmitRequest: fields = ' +JSON.stringify(fields));
        fields.Date_requested_Board_EC_approval__c = $A.localizationService.formatDate(new Date(), "YYYY-MM-DD"); 
        console.log('handleSubmitRequest: fields = ' +JSON.stringify(fields));
        component.find('submitRequestForm').submit(fields);
    },
    
})