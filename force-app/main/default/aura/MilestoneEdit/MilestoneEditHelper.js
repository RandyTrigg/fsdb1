({
    init: function(cmp) {
        console.log('MilestoneEditHelper init');
        this.getCoreInfo(cmp);
    },
    getCoreInfo: function(cmp) {
        // Fetch the milestone information, packaged in a MilestoneInfo record, from the database.
        this.disableEdits(cmp);
        cmp.set('v.fetching', true);
        var action = cmp.get('c.getMilestoneInfo');
        action.setParams({
            mId: cmp.get('v.milestoneId')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.milestoneInfo', response.getReturnValue());
                var milestone = cmp.get('v.milestoneInfo.m');
                cmp.set('v.milestone', milestone);
                cmp.set('v.gmDataId', cmp.get('v.milestoneInfo.gmDataId'));
                if (!milestone.Date_submitted__c)
                    cmp.set('v.notReceived', true);
                console.log(
                    'MilestoneEditHelper getMilestoneInfo: v.milestoneInfo = ' +
                        JSON.stringify(cmp.get('v.milestoneInfo'))
                );
                // Now get the GM Data info.
                this.getGMDataInfo(cmp);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'MilestoneEditHelper getMilestoneInfo Error message: ' +
                        JSON.stringify(response.getError())
                );
            }
        });
        $A.enqueueAction(action);
    },
    getReviewComponentsCore: function(cmp) {
        return cmp.get('v.milestoneInfo.reviewComponents');
    },
    getPicklistCore: function(cmp, fieldName) {
        var picklists = cmp.get('v.milestoneInfo.picklists');
        return picklists[fieldName.toLowerCase()];
    },
    getValueCore: function(cmp, fieldName) {
        return cmp.get('v.milestone.' + fieldName);
    },
    setSelectLookupAttrsCore: function(cmp, attrs, fieldName) {},
    setSelectMultiAttrsCore: function(cmp, attrs, joinObjName, childType) {},
    // Save latest changes to the database
    updateDatabase: function(cmp) {
        console.log('MilestoneEditHelper updateDatabase...');
        var action = cmp.get('c.saveMilestoneInfo');
        action.setParams({
            m: cmp.get('v.milestone'),
            d: cmp.get('v.gmData')
        });
        action.setCallback(this, function(response) {
            console.log(
                'MilestoneEditHelper updateDatabase response.getError() = ' +
                    JSON.stringify(response.getError())
            );
            var state = response.getState();
            var errResponse = JSON.stringify(response.getError());
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.milestone', response.getReturnValue());
                console.log('MilestoneEditHelper updateDatabase SUCCESS...');
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log('state=ERROR: errResponse: ' + errResponse);
            } else if (cmp.isValid() && state === 'INCOMPLETE') {
                console.log('state=INCOMPLETE: errResponse: ' + errResponse);
                return;
            }
            cmp.set(
                'v.errResponseCore',
                errResponse == '[]' ? null : errResponse
            );
            // Update any GM Data records.
            this.updateDatabaseGMData(cmp);
        });
        $A.enqueueAction(action);
    },
    // Called when setting field values in super-component.  Defined here where the field's record is visible.
    setFieldCore: function(cmp, objName, fieldName, fieldValue) {
        cmp.set('v.' + objName + '.' + fieldName, fieldValue);
    },
    // Called when submitting review in super-component.  Set date reviewed field here where the field's record is visible.
    setDateReviewedCore: function(cmp) {
        // Don't overwrite an existing date.
        if (!cmp.get('v.milestone.Date_reviewed__c'))
            cmp.set('v.milestone.Date_reviewed__c', this.todayDate(cmp));
    }
});