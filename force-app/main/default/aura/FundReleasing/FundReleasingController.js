({
	doInit : function(component, event, helper) {
        helper.init(component);		
	},
    
    recordUpdated: function (cmp, event, helper) {
        console.log('recordUpdated before: v.simpleRecord.Active__c = ' +cmp.get('v.simpleRecord.Active__c'));
        var changeType = event.getParams().changeType;
        if (changeType === "CHANGED") { 
            cmp.find("recordData").reloadRecord(true, $A.getCallback(function() {
                console.log('recordUpdated CHANGED: v.simpleRecord.Active__c = ' +cmp.get('v.simpleRecord.Active__c'));
            }));
        }
        else if (changeType === "LOADED") { 
            console.log('recordUpdated LOADED: v.simpleRecord.Active__c = ' +cmp.get('v.simpleRecord.Active__c'));
        }
        helper.resetDescriptions(cmp);
    },
    
    // Set the appropriate field in v.simpleRecord when checkbox is modified, ensuring that SaveRecord call will work.
    activeCheckboxChanged : function(cmp, event, helper){
        var val = event.getSource().get("v.value");
        console.log('activeCheckboxChanged: val = ' +val);
        cmp.set('v.simpleRecord.Active__c', val);
    },
    
    handleSave: function(cmp, event, helper) {
        cmp.find("recordData").saveRecord($A.getCallback(function(saveResult) {
            // NOTE: If you want a specific behavior(an action or UI behavior) when this action is successful 
            // then handle that in a callback (generic logic when record is changed should be handled in recordUpdated event handler)
            if (saveResult.state === "SUCCESS" || saveResult.state === "DRAFT") {
                console.log('handleSave: v.simpleRecord.Active__c = ' +cmp.get('v.simpleRecord.Active__c'));
                // handle component related logic in event handler
            } else if (saveResult.state === "INCOMPLETE") {
                console.log("User is offline, device doesn't support drafts.");
            } else if (saveResult.state === "ERROR") {
                console.log('Problem saving record, error: ' + JSON.stringify(saveResult.error));
            } else {
                console.log('Unknown problem, state: ' + saveResult.state + ', error: ' + JSON.stringify(saveResult.error));
            }
        }));
    },

    changedReleaseDate: function (cmp, event, helper) {
        helper.resetDescriptions(cmp);        
    },

    chargesSelected: function (cmp, event, helper) {
        helper.resetChargesStats(cmp);
        helper.resetDescriptions(cmp);
    },

    projectionSelected: function (cmp, event, helper) {
        var selectedRows = event.getParam('selectedRows');
        cmp.set('v.selProjection', selectedRows.length > 0 ? selectedRows[0] : null);
        helper.resetDescriptions(cmp);
    },

    distributionSelected: function (cmp, event, helper) {
        var selectedRows = event.getParam('selectedRows');
        cmp.set('v.selDistribution', selectedRows.length > 0 ? selectedRows[0] : null);
        helper.resetDescriptions(cmp);
    },
    
    // Invoke apex to release selected charges against selected projection.
    releaseAgainstProjection: function (cmp, event, helper) {
        var selRows = cmp.find('chargesTable').getSelectedRows();
        helper.releaseCharges(cmp, selRows, cmp.get('v.selProjection').Id, null);
    },

    // Invoke apex to release selected charges against selected distribution.
    releaseAgainstDistribution: function (cmp, event, helper) {
        var selRows = cmp.find('chargesTable').getSelectedRows();
        helper.releaseCharges(cmp, selRows, null, cmp.get('v.selDistribution').Id);
    },

    // Invoke apex to unrelease selected charges.
    unrelease: function (cmp, event, helper) {
        var selRows = cmp.find('chargesTable').getSelectedRows();
        helper.unreleaseCharges(cmp, selRows);
    },
    
    // Perform release or unrelease for a single row in the charges table.
    handleRowAction: function (cmp, event, helper) {
        var action = event.getParam('action');
        var charges = [event.getParam('row')]; // The singleton charge is the current row.
        switch (action.name) {
            case 'unrelease':
                helper.unreleaseCharges(cmp, charges);                
                break;
            case 'releaseAgainstProjection':
                helper.releaseCharges(cmp, charges, cmp.get('v.selProjection').Id, null);
                break;
            case 'releaseAgainstDistribution':
                helper.releaseCharges(cmp, charges, null, cmp.get('v.selDistribution').Id);
                break;
        }
    },
    
    // Client-side controller called by the onsort event handler
    updateColumnSorting: function (cmp, event, helper) {
        var fieldName = event.getParam('fieldName');
        var sortDirection = event.getParam('sortDirection');
        var auraId = event.getSource().getLocalId();
        var dataName = 
            auraId == 'chargesTable' ? 'charges' :
        	auraId == 'projectionsTable' ? 'projections' : 
        	auraId == 'distributionsTable' ? 'distributions' : null;
        console.log('updateColumnSorting: dataName = ' +dataName+ '; fieldName = ' +fieldName+ '; sortDirection = ' +sortDirection);
        // assign the latest attribute with the sorted column fieldName and sorted direction
        cmp.set('v.' +dataName+ 'SortedBy', fieldName);
        cmp.set('v.' +dataName+ 'SortedDirection', sortDirection);
        helper.sortData(cmp, dataName, fieldName, sortDirection);
    },
    
    
})