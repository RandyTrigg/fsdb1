({
    init: function(cmp) {
        console.log('ProposalEditHelper init');
        this.getCoreInfo(cmp);
    },
    getCoreInfo: function(cmp) {
        // Fetch the proposal information, packaged in a ProposalInfo record, from the database.
        this.disableEdits(cmp);
        cmp.set('v.fetching', true);
        var action = cmp.get('c.getProposalInfo');
        action.setParams({
            propId: cmp.get('v.proposalId')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.proposalInfo', response.getReturnValue());
                var proposal = cmp.get('v.proposalInfo.prop');
                cmp.set('v.proposal', proposal);
                cmp.set('v.gmDataId', cmp.get('v.proposalInfo.gmDataId'));
                if (!proposal.Date_received__c) cmp.set('v.notReceived', true);
                console.log(
                    'ProposalEdit getProposalInfo: v.proposalInfo = ' +
                        JSON.stringify(cmp.get('v.proposalInfo'))
                );
                // Next, fetch the issues classification info.
                this.getIssuesInfo(cmp);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'ProposalEdit getProposalInfo Error message: ' +
                        JSON.stringify(response.getError())
                );
            }
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
            propId: cmp.get('v.proposalId')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.issuesInfo', response.getReturnValue());
                console.log(
                    'ProposalEdit getIssuesInfo: v.issuesInfo = ' +
                        cmp.get('v.issuesInfo')
                );
                // Next, fetch the populations classification info.
                this.getPopulationsInfo(cmp);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'ProposalEdit getIssuesInfo Error message: ' +
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
            propId: cmp.get('v.proposalId')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.populationsInfo', response.getReturnValue());
                console.log(
                    'ProposalEdit getPopulationsInfo: v.populationsInfo = ' +
                        cmp.get('v.populationsInfo')
                );
                // Next, fetch the strategies classification info.
                this.getStrategiesInfo(cmp);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'ProposalEdit getPopulationsInfo Error message: ' +
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
            propId: cmp.get('v.proposalId')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.strategiesInfo', response.getReturnValue());
                console.log(
                    'ProposalEdit getStrategiesInfo: v.strategiesInfo = ' +
                        JSON.stringify(cmp.get('v.strategiesInfo'))
                );
                // Now get the GM Data info.
                this.getGMDataInfo(cmp);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'ProposalEdit getStrategiesInfo Error message: ' +
                        JSON.stringify(response.getError())
                );
            }
        });
        $A.enqueueAction(action);
    },
    getReviewComponentsCore: function(cmp) {
        return cmp.get('v.proposalInfo.reviewComponents');
    },
    getPicklistCore: function(cmp, fieldName) {
        var picklists = cmp.get('v.proposalInfo.picklists');
        return picklists[fieldName.toLowerCase()];
    },
    getValueCore: function(cmp, fieldName) {
        return cmp.get('v.proposal.' + fieldName);
    },
    setSelectLookupAttrsCore: function(cmp, attrs, fieldName) {
        if (fieldName.indexOf('Decline_reason') > -1) {
            attrs['selected'] = cmp.get(
                'v.proposalInfo.selectedDeclineReasonName'
            );
            attrs['idNameMap'] = cmp.get('v.proposalInfo.declineReasonNameMap');
            attrs['picklist'] = cmp.get('v.proposalInfo.declineReasonNames');
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
            attrs['objName'] = 'proposalInfo';
            attrs['fieldName'] = 'selectedPortfolioIdsPacked';
            attrs['value'] = cmp.get(
                'v.proposalInfo.selectedPortfolioIdsPacked'
            );
            attrs['selecteds'] = cmp.get(
                'v.proposalInfo.selectedPortfolioNames'
            );
            attrs['unselecteds'] = cmp.get(
                'v.proposalInfo.unselectedPortfolioNames'
            );
            attrs['idNameMap'] = cmp.get('v.proposalInfo.portfolioNameMap');
        }
    },
    // Save latest changes to the database
    updateDatabase: function(cmp) {
        console.log(
            'ProposalEdit updateDatabase; v.proposalInfo.selectedPortfolioIdsPacked = ' +
                cmp.get('v.proposalInfo.selectedPortfolioIdsPacked') +
                '; v.issuesInfo.selectedIdsPacked = ' +
                cmp.get('v.issuesInfo.selectedIdsPacked') +
                '; v.strategiesInfo.selectedIdsPacked = ' +
                cmp.get('v.strategiesInfo.selectedIdsPacked')
        );
        var action = cmp.get('c.saveProposalInfo1');
        action.setParams({
            p: cmp.get('v.proposal'),
            d: cmp.get('v.gmData'),
            populationIdsPacked: cmp.get('v.populationsInfo.selectedIdsPacked'),
            strategyIdsPacked: cmp.get('v.strategiesInfo.selectedIdsPacked'),
            issueIdsPacked: cmp.get('v.issuesInfo.selectedIdsPacked'),
            portfolioIdsPacked: cmp.get(
                'v.proposalInfo.selectedPortfolioIdsPacked'
            )
        });
        action.setCallback(this, function(response) {
            console.log(
                'ProposalEditHelper updateDatabase response.getError() = ' +
                    JSON.stringify(response.getError())
            );
            var state = response.getState();
            var errResponse = JSON.stringify(response.getError());
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.proposal', response.getReturnValue());
                console.log(
                    'ProposalEdit updateDatabase SUCCESS: status = ' +
                        cmp.get('v.proposal.Status__c')
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
            // Update GM Data record.
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
        // Currently, no props are allowed to override.
        return false;
    },
    // Called when submitting review in super-component.  Set date reviewed field here where the field's record is visible.
    setDateReviewedCore: function(cmp) {
        // Don't overwrite an existing date.
        if (!cmp.get('v.proposal.Date_review_completed__c'))
            cmp.set('v.proposal.Date_review_completed__c', this.todayDate(cmp));
    }
});