({
    checkBlankFields: function(cmp) {
        var prop = cmp.get('v.propRecord');
        var acc = cmp.get('v.accRecord');
        var hasBlankFields =
            !acc.Highlights__c ||
            !prop.Description__c ||
            (!prop.Amount_awarded__c && !prop.Amount_recommended__c) ||
            !prop.Thematic_priority__c ||
            !prop.Staff_analysis__c ||
            !prop.Reason_for_soliciting_committee_approval__c ||
            !prop.Rationale_for_committee_approval__c;
        cmp.set('v.requiredFieldsBlank', hasBlankFields);
    },

    // Check dirty flags for the editable fields, and set saveNeeded if any are true.
    setSaveNeeded: function(cmp) {
        console.log('setSaveNeeded: ...');
        var fNames = cmp.get('v.fieldNamesEditable');
        var dirtyFlags = cmp.get('v.dirtyFlags');
        var saveNeeded = false;
        for (var i = 0; i < fNames.length; i++) {
            var fName = fNames[i];
            console.log(
                'setSaveNeeded: fName = ' +
                    fName +
                    '; dirtyFlags[fName]' +
                    dirtyFlags[fName]
            );
            if (dirtyFlags[fName]) saveNeeded = true;
        }
        cmp.set('v.saveNeeded', saveNeeded);
    }
});