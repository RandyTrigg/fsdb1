({
    init: function(cmp) {
        console.log('ProfileEditHelper init...');
        this.getCoreInfo(cmp);
    },
    // Overwrites the inherited "getCoreInfo" method from super.
    getCoreInfo: function(cmp) {
        // Fetch the profile information, packaged in a ProfileInfo record, from the database.
        this.disableEdits(cmp);
        cmp.set('v.fetching', true);
        var action = cmp.get('c.getProfileInfo');
        action.setParams({
            profileId: cmp.get('v.profileId')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.profileInfo', response.getReturnValue());
                var profile = response.getReturnValue()['profile'];
                cmp.set('v.profile', profile);
                if (!profile.Date_submitted__c) cmp.set('v.notReceived', true);
                //console.log('ProfileEdit getProfileInfo: v.profileInfo = ' +JSON.stringify(cmp.get("v.profileInfo")));
                //console.log('ProfileEdit getProfileInfo: v.profileInfo.profile = ' +cmp.get("v.profileInfo.profile"));
                console.log(
                    'ProfileEdit getProfileInfo: v.profileInfo.portfolioNameMap = ' +
                        JSON.stringify(
                            cmp.get('v.profileInfo.portfolioNameMap')
                        )
                );
                // Next, fetch the issues classification info.
                this.getIssuesInfo(cmp);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'ProfileEdit getProfileInfo Error message: ' +
                        JSON.stringify(response.getError())
                );
            }
            cmp.set('v.fetching', false);
            cmp.set('v.submitting', false);
            this.enableEdits(cmp);
        });
        $A.enqueueAction(action);
    },
    getIssuesInfo: function(cmp) {
        // Fetch the issues classification info from the database.
        this.disableEdits(cmp);
        cmp.set('v.fetching', true);
        var action = cmp.get('c.getClassificationInfo');
        action.setParams({
            cType: 'Issue',
            profId: cmp.get('v.profileId')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.issuesInfo', response.getReturnValue());
                console.log(
                    'ProfileEdit getIssuesInfo: v.issuesInfo = ' +
                        cmp.get('v.issuesInfo')
                );
                // Next, fetch the populations classification info.
                this.getPopulationsInfo(cmp);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'ProfileEdit getIssuesInfo Error message: ' +
                        JSON.stringify(response.getError())
                );
            }
        });
        $A.enqueueAction(action);
    },
    getPopulationsInfo: function(cmp) {
        // Fetch the populations classification info from the database.
        this.disableEdits(cmp);
        cmp.set('v.fetching', true);
        var action = cmp.get('c.getClassificationInfo');
        action.setParams({
            cType: 'Population',
            profId: cmp.get('v.profileId')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.populationsInfo', response.getReturnValue());
                console.log(
                    'ProfileEdit getPopulationsInfo: v.populationsInfo = ' +
                        cmp.get('v.populationsInfo')
                );
                // Next, fetch the strategies classification info.
                this.getStrategiesInfo(cmp);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'ProfileEdit getPopulationsInfo Error message: ' +
                        JSON.stringify(response.getError())
                );
            }
        });
        $A.enqueueAction(action);
    },
    getStrategiesInfo: function(cmp) {
        // Fetch the strategies classification info from the database.
        this.disableEdits(cmp);
        cmp.set('v.fetching', true);
        var action = cmp.get('c.getClassificationInfo');
        action.setParams({
            cType: 'Strategy',
            profId: cmp.get('v.profileId')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.strategiesInfo', response.getReturnValue());
                console.log(
                    'ProfileEdit getStrategiesInfo: v.strategiesInfo = ' +
                        JSON.stringify(cmp.get('v.strategiesInfo'))
                );
                // Call the get GM Data info, which will do nothing, as there's currently no gm data at the profile.
                this.getGMDataInfo(cmp);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'ProfileEdit getStrategiesInfo Error message: ' +
                        JSON.stringify(response.getError())
                );
            }
        });
        $A.enqueueAction(action);
    },
    getReviewComponentsCore: function(cmp) {
        return cmp.get('v.profileInfo.reviewComponents');
    },
    getPicklistCore: function(cmp, fieldName) {
        var picklists = cmp.get('v.profileInfo.picklists');
        return picklists[fieldName.toLowerCase()];
    },
    getValueCore: function(cmp, fieldName) {
        return cmp.get('v.profile.' + fieldName);
    },
    setSelectLookupAttrsCore: function(cmp, attrs, fieldName) {
        if (fieldName.indexOf('Decline_reason') > -1) {
            attrs['selected'] = cmp.get(
                'v.profileInfo.selectedDeclineReasonName'
            );
            attrs['idNameMap'] = cmp.get('v.profileInfo.declineReasonNameMap');
            attrs['picklist'] = cmp.get('v.profileInfo.declineReasonNames');
        }
    },
    setSelectMultiAttrsCore: function(cmp, attrs, joinObjName, childType) {
        if (joinObjName == 'Classification_Assign__c') {
            var objName =
                childType == 'Issue'
                    ? 'issuesInfo'
                    : childType == 'Strategy'
                    ? 'strategiesInfo'
                    : childType == 'Population'
                    ? 'populationsInfo'
                    : null;
            if (objName != null) {
                attrs['type'] = 'idList'; // Is this attribute being used?
                attrs['objName'] = objName;
                attrs['fieldName'] = 'selectedIdsPacked';
                attrs['value'] = cmp.get('v.' + objName + '.selectedIdsPacked');
                attrs['selecteds'] = cmp.get('v.' + objName + '.selectedNames');
                attrs['unselecteds'] = cmp.get(
                    'v.' + objName + '.unselectedNames'
                );
                attrs['idNameMap'] = cmp.get('v.' + objName + '.nameMap');
            }
        } else if (joinObjName == 'Portfolio_Assignment__c') {
            attrs['type'] = 'idList'; // Is this attribute being used?
            attrs['objName'] = 'profileInfo';
            attrs['fieldName'] = 'selectedPortfolioIdsPacked';
            attrs['value'] = cmp.get(
                'v.profileInfo.selectedPortfolioIdsPacked'
            );
            attrs['selecteds'] = cmp.get(
                'v.profileInfo.selectedPortfolioNames'
            );
            attrs['unselecteds'] = cmp.get(
                'v.profileInfo.unselectedPortfolioNames'
            );
            attrs['idNameMap'] = cmp.get('v.profileInfo.portfolioNameMap');
        }
    },
    // Save latest changes to the database, first for the Profile and then for any GM Data records.
    // Overrides this function at the super.
    updateDatabase: function(cmp) {
        var _this = this;
        console.log(
            'ProfileEdit updateDatabase; v.profileInfo.selectedPortfolioIdsPacked = ' +
                cmp.get('v.profileInfo.selectedPortfolioIdsPacked') +
                '; v.populationsInfo.selectedIdsPacked = ' +
                cmp.get('v.populationsInfo.selectedIdsPacked')
        );
        console.log(
            'ProfileEdit updateDatabase; v.profile = ' +
                JSON.stringify(cmp.get('v.profile'))
        );
        var action = cmp.get('c.saveProfileInfo2');
        action.setParams({
            pr: cmp.get('v.profile'),
            populationIdsPacked: cmp.get('v.populationsInfo.selectedIdsPacked'),
            strategyIdsPacked: cmp.get('v.strategiesInfo.selectedIdsPacked'),
            issueIdsPacked: cmp.get('v.issuesInfo.selectedIdsPacked'),
            portfolioIdsPacked: cmp.get(
                'v.profileInfo.selectedPortfolioIdsPacked'
            )
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            var errResponse = JSON.stringify(response.getError());
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.profile', response.getReturnValue());
                console.log(
                    'ProfileEdit updateDatabase SUCCESS: status = ' +
                        cmp.get('v.profile.Status__c')
                );
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
    // Called by super to determine whether required fields tests are necessary for submit.
    overrideRequiredFieldsTest: function(cmp, reviewCmps) {
        // Build array of fields that currently have values.
        var nonBlankFields = [];
        for (var i = 0; i < reviewCmps.length; i++) {
            if (!reviewCmps[i].get('v.readonly')) {
                var fName = reviewCmps[i].get('v.fieldName');
                var val = reviewCmps[i].get('v.value');
                if (val) nonBlankFields.push(fName);
            }
        }
        var fieldsToCheck = cmp.get('v.overrideRequiredFields');
        // Return true if every field in the override list has non-blank value.
        return fieldsToCheck.every(function(fld) {
            return nonBlankFields.indexOf(fld) >= 0;
        });
    },
    // Called when submitting review in super-component.  Set date reviewed field here where the field's record is visible.
    setDateReviewedCore: function(cmp) {
        // Don't overwrite an existing date.
        if (!cmp.get('v.profile.Date_review_completed__c'))
            cmp.set('v.profile.Date_review_completed__c', this.todayDate(cmp));
    }
});