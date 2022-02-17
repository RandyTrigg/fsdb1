({
    init: function(cmp) {
        this.setColumns(cmp);
        this.getRecords(cmp);
    },

    // Configure the columns for each of the three datatables.
    setColumns: function(cmp) {
        var actions = this.getRowActions.bind(this, cmp);
        cmp.set('v.chargesColumns', [
            {
                label: 'Proposal',
                fieldName: 'ProposalURL',
                sortable: 'true',
                type: 'url',
                typeAttributes: {
                    label: { fieldName: 'Proposal__r.Name' },
                    target: '_blank'
                }
            },
            {
                label: 'Account',
                fieldName: 'ProposalAccountURL',
                sortable: 'true',
                type: 'url',
                typeAttributes: {
                    label: { fieldName: 'Proposal__r.Account__r.Name' },
                    target: '_blank'
                }
            },
            {
                label: 'Date awarded',
                fieldName: 'Proposal__r.Date_awarded__c',
                type: 'date-local',
                sortable: 'true'
            },
            {
                label: 'Amount charged',
                fieldName: 'Amount_charged__c',
                type: 'currency',
                sortable: 'true'
            },
            {
                label: 'Date released',
                fieldName: 'Date_released__c',
                type: 'date-local',
                sortable: 'true'
            },
            {
                label: 'Projection',
                fieldName: 'Projection__r.Name',
                type: 'text',
                sortable: 'true'
            },
            {
                label: 'Distribution',
                fieldName: 'Distribution__r.Name',
                type: 'text',
                sortable: 'true'
            },
            { type: 'action', typeAttributes: { rowActions: actions } }
        ]);
        cmp.set('v.projectionsColumns', [
            {
                label: 'Name',
                fieldName: 'Name',
                type: 'text',
                sortable: 'true'
            },
            {
                label: 'C of A',
                fieldName: 'ChartofAccountsURL',
                sortable: 'true',
                type: 'url',
                typeAttributes: {
                    label: { fieldName: 'ChartofAccounts__r.Name' },
                    target: '_blank'
                }
            },
            {
                label: 'Source',
                fieldName: 'OpportunityURL',
                sortable: 'true',
                type: 'url',
                typeAttributes: {
                    label: { fieldName: 'Opportunity__r.Name' },
                    target: '_blank'
                }
            },
            {
                label: 'Description',
                fieldName: 'Description__c',
                type: 'text',
                sortable: 'true'
            },
            {
                label: 'Amt for GM',
                fieldName: 'Total_grantmaking__c',
                type: 'currency',
                sortable: 'true'
            },
            {
                label: 'To be released',
                fieldName: 'To_be_released__c',
                type: 'currency',
                sortable: 'true'
            }
        ]);
        cmp.set('v.distributionsColumns', [
            {
                label: 'Name',
                fieldName: 'Name',
                type: 'text',
                sortable: 'true'
            },
            {
                label: 'C of A',
                fieldName: 'ChartofAccountsURL',
                sortable: 'true',
                type: 'url',
                typeAttributes: {
                    label: { fieldName: 'ChartofAccounts__r.Name' },
                    target: '_blank'
                }
            },
            {
                label: 'Source',
                fieldName: 'Source_fundURL',
                sortable: 'true',
                type: 'url',
                typeAttributes: {
                    label: { fieldName: 'Source_fund__r.Name' },
                    target: '_blank'
                }
            },
            {
                label: 'Description',
                fieldName: 'Description__c',
                type: 'text',
                sortable: 'true'
            },
            {
                label: 'Amt for GM',
                fieldName: 'Amount__c',
                type: 'currency',
                sortable: 'true'
            },
            {
                label: 'To be released',
                fieldName: 'To_be_released__c',
                type: 'currency',
                sortable: 'true'
            }
        ]);
    },

    // Build dynamic row actions for charges table.
    getRowActions: function(cmp, row, doneCallback) {
        console.log('getRowActions: row = ' + JSON.stringify(row));
        var releaseDate = cmp.get('v.releaseDate'),
            proj = cmp.get('v.selProjection'),
            dist = cmp.get('v.selDistribution'),
            actions = [];
        console.log('getRowActions: row = ' + JSON.stringify(row));
        console.log(
            'getRowActions: releaseDate = ' +
                releaseDate +
                '; proj = ' +
                JSON.stringify(proj)
        );
        if (cmp.get('v.hasPermission') && cmp.get('v.simpleRecord.Active__c')) {
            // Only have row actions if user has edit permission and the fund is active.
            if (
                row.Date_released__c ||
                row.Projection__c ||
                row.Distribution__c
            ) {
                // Only option is to unrelease the (already released) charge.
                actions.push({
                    label: 'Unrelease',
                    name: 'unrelease'
                });
            } else {
                if (releaseDate && proj && proj.To_be_released__c > 0) {
                    // Release or partially release charge against projection.
                    var labelPrefix =
                        row.Amount_charged__c <= proj.To_be_released__c
                            ? 'Release'
                            : 'Partial release';
                    actions.push({
                        label: labelPrefix + ' against ' + proj.Name,
                        name: 'releaseAgainstProjection'
                    });
                }
                if (releaseDate && dist && dist.To_be_released__c > 0) {
                    // Release or partially release charge against distribution.
                    var labelPrefix =
                        row.Amount_charged__c <= dist.To_be_released__c
                            ? 'Release'
                            : 'Partial release';
                    actions.push({
                        label: labelPrefix + ' against ' + dist.Name,
                        name: 'releaseAgainstDistribution'
                    });
                }
            }
        }
        console.log('getRowActions: actions = ' + JSON.stringify(actions));
        // Took this from the documentation.  I'm not clear on its function, but the actions don't show up without it.
        setTimeout(
            $A.getCallback(function() {
                doneCallback(actions);
            }),
            200
        );
    },

    // Reset descriptions used as hover text in the buttons controlling the interface.
    // Also set disabled flags for the three buttons based on whether errors are found.
    resetDescriptions: function(cmp) {
        console.log('resetDescriptions...');
        var numCharges = cmp.get('v.selRowsCount'),
            numRelCharges = cmp.get('v.selRelRowsCount'),
            numUnrelCharges = numCharges - numRelCharges,
            hasDate = !!cmp.get('v.releaseDate'),
            chargesTotal = cmp.get('v.selChargesTotal'),
            chargesRelTotal = cmp.get('v.selRelChargesTotal'),
            chargesUnrelTotal = chargesTotal - chargesRelTotal,
            chargesRelStr =
                numRelCharges > 0
                    ? numRelCharges +
                      ' released charge' +
                      (numRelCharges == 1 ? '' : 's') +
                      ' for $' +
                      chargesRelTotal.toLocaleString()
                    : null,
            chargesUnrelStr =
                numUnrelCharges > 0
                    ? numUnrelCharges +
                      ' unreleased charge' +
                      (numUnrelCharges == 1 ? '' : 's') +
                      ' for $' +
                      chargesUnrelTotal.toLocaleString()
                    : null,
            proj = cmp.get('v.selProjection'),
            dist = cmp.get('v.selDistribution'),
            projAmt = proj ? proj.To_be_released__c : 0,
            distAmt = dist ? dist.To_be_released__c : 0,
            projStr =
                ' against ' +
                cmp.get('v.selProjection.Name') +
                ' ($' +
                projAmt.toLocaleString() +
                ')',
            distStr =
                ' against ' +
                cmp.get('v.selDistribution.Name') +
                ' ($' +
                distAmt.toLocaleString() +
                ')',
            missingDateStr = 'Please provide a release date.',
            noRelChargesStr = 'Please select one or more released charges.',
            noUnrelChargesStr = 'Please select one or more unreleased charges.',
            noProjStr =
                'Please select a projection with unreleased funds to charge against.',
            noDistStr =
                'Please select a distribution with unreleased funds to charge against.',
            projFundsTooLowStr =
                'The total selected unreleased charges ($' +
                chargesUnrelTotal.toLocaleString() +
                ") is greater than projection's remaining funds ($" +
                projAmt.toLocaleString() +
                ').',
            distFundsTooLowStr =
                'The total selected unreleased charges ($' +
                chargesUnrelTotal.toLocaleString() +
                ") is greater than distribution's remaining funds ($" +
                distAmt.toLocaleString() +
                ').',
            fundsTooLowAdviceStr =
                'Try releasing fewer charges and/or partially release an individual charge using the actions menu in its row.',
            noPermissionStr =
                'You don\'t have "Releasing" permission so this interface is read-only.',
            inactiveFundStr =
                'The fund is currently inactive.  Use checkbox above to activate.',
            globalErrorStr = !cmp.get('v.hasPermission')
                ? noPermissionStr
                : !cmp.get('v.simpleRecord.Active__c')
                ? inactiveFundStr
                : null,
            unreleaseErrs = [],
            projErrs = [],
            distErrs = [];
        // Gather errors
        if (!hasDate) {
            projErrs.push(missingDateStr);
            distErrs.push(missingDateStr);
        }
        if (numRelCharges == 0) {
            unreleaseErrs.push(noRelChargesStr);
        }
        if (numUnrelCharges == 0) {
            projErrs.push(noUnrelChargesStr);
            distErrs.push(noUnrelChargesStr);
        }
        if (!proj || projAmt <= 0) projErrs.push(noProjStr);
        else if (projAmt < chargesUnrelTotal) {
            projErrs.push(projFundsTooLowStr);
            projErrs.push(fundsTooLowAdviceStr);
        }
        if (!dist || distAmt <= 0) distErrs.push(noDistStr);
        else if (distAmt < chargesUnrelTotal) {
            distErrs.push(distFundsTooLowStr);
            distErrs.push(fundsTooLowAdviceStr);
        }
        // Override the other errors if there's a "global" error (lack of permission or inactive fund).
        if (globalErrorStr) {
            unreleaseErrs = [globalErrorStr];
            projErrs = [globalErrorStr];
            distErrs = [globalErrorStr];
        }
        // Set disabled flags for the three buttons.
        cmp.set('v.unreleaseDisabled', unreleaseErrs.length > 0);
        cmp.set('v.projReleaseDisabled', projErrs.length > 0);
        cmp.set('v.distReleaseDisabled', distErrs.length > 0);
        // Set descriptions
        cmp.set(
            'v.unreleaseDesc',
            unreleaseErrs.length
                ? unreleaseErrs.join('\n')
                : 'Unrelease ' + chargesRelStr
        );
        cmp.set(
            'v.projReleaseDesc',
            projErrs.length
                ? projErrs.join('\n')
                : 'Release ' + chargesUnrelStr + projStr
        );
        cmp.set(
            'v.distReleaseDesc',
            distErrs.length
                ? distErrs.join('\n')
                : 'Release ' + chargesUnrelStr + distStr
        );
        cmp.set(
            'v.chargesTableDesc',
            numCharges == 0
                ? 'No selected charges'
                : [chargesRelStr, chargesUnrelStr]
                      .filter(function(e) {
                          return e;
                      })
                      .join('; ')
        );
    },

    // Fetch the charges, projections, and distributions belonging to this fund.
    // The apex method also updates the amount released fields in the projections and distributions.
    getRecords: function(cmp) {
        console.log('getRecords...');
        cmp.set('v.waiting', true);
        var action = cmp.get('c.getRecordsForReleasing');
        action.setParams({
            fundIdStr: cmp.get('v.fundId')
        });
        action.setCallback(
            this,
            $A.getCallback(function(response) {
                var state = response.getState();
                if (state === 'SUCCESS') {
                    var returnVal = JSON.parse(response.getReturnValue());
                    cmp.set(
                        'v.chargesData',
                        this.processRelatedFields(returnVal.results.charges)
                    );
                    cmp.set(
                        'v.projectionsData',
                        this.processRelatedFields(returnVal.results.projections)
                    );
                    cmp.set(
                        'v.distributionsData',
                        this.processRelatedFields(
                            returnVal.results.distributions
                        )
                    );
                    cmp.set(
                        'v.hasPermission',
                        returnVal.results.permissionSets.indexOf(
                            cmp.get('v.permissionSetName')
                        ) > -1
                    );
                    console.log(
                        'getRecords: v.chargesData = ' +
                            JSON.stringify(cmp.get('v.chargesData'))
                    );
                    console.log(
                        'getRecords: v.hasPermission = ' +
                            cmp.get('v.hasPermission')
                    );
                    cmp.set('v.selectedRows', []); // Clear selected rows from charges table.
                    this.resetChargesStats(cmp);
                    this.resetDescriptions(cmp);
                    cmp.find('recordData').reloadRecord(true); // Update the data in the fund card.
                    cmp.set('v.waiting', false);
                } else if (state === 'ERROR') {
                    var errors = response.getError();
                    console.error(errors);
                }
            })
        );
        $A.enqueueAction(action);
    },

    // Walk through a list of records massaging the related fields.
    processRelatedFields: function(recsList) {
        var results = [];
        if (recsList) {
            for (var i = 0; i < recsList.length; i++) {
                var rec = recsList[i];
                var obj = {};
                this.setRelatedFields(obj, rec, '');
                results.push(obj);
            }
        }
        return results;
    },

    // Recursive function ensures that every related field identified in obj appears as a
    // key-value pair with dot notation (e.g. Proposal__r.Name).
    setRelatedFields: function(obj, subObj, prefix) {
        //console.log('setRelatedFields: prefix = ' +prefix+ '; subObj = ' +JSON.stringify(subObj));
        for (var key in subObj) {
            if (subObj.hasOwnProperty(key)) {
                //console.log('setRelatedFields: key = ' +key);
                var val = subObj[key];
                if (this.isObject(val))
                    this.setRelatedFields(obj, val, prefix + key + '.');
                else {
                    obj[prefix + key] = val;
                    // Build a URL field for Name fields of related records.  Note that prefix ends with '.'
                    if (key == 'Name')
                        obj[this.urlFieldName(prefix)] =
                            '/' + obj[prefix.slice(0, -2) + 'c'];
                }
            }
        }
    },

    isObject: function(obj) {
        return obj === Object(obj);
    },

    // Transform a field name prefix like "Proposal__r.Account__r." into "ProposalAccountURL".
    urlFieldName: function(str) {
        return str.replace(/__r\./g, '') + 'URL';
    },

    resetChargesStats: function(cmp) {
        var rows = cmp.find('chargesTable').getSelectedRows(),
            numRowsReleased = 0,
            totalCharged = 0,
            totalRelCharged = 0;
        // Compute counts and totals for selected charges rows.
        for (var i = 0; i < rows.length; i++) {
            totalCharged += rows[i].Amount_charged__c;
            if (rows[i].Date_released__c) {
                totalRelCharged += rows[i].Amount_charged__c;
                numRowsReleased++;
            }
        }
        console.log('chargesRowSelected: totalCharged = ' + totalCharged);
        cmp.set('v.selRowsCount', rows.length);
        cmp.set('v.selRelRowsCount', numRowsReleased);
        cmp.set('v.selChargesTotal', totalCharged);
        cmp.set('v.selRelChargesTotal', totalRelCharged);
    },

    // Invoke server-side controller to release given charges against given proj/dist.
    releaseCharges: function(cmp, charges, projectionId, distributionId) {
        console.log('releaseCharges...');
        cmp.set('v.waiting', true);
        var action = cmp.get('c.releaseCharges');
        action.setParams({
            jsonString: JSON.stringify({
                chargeIds: this.idsFromObjs(charges),
                projectionId: projectionId,
                distributionId: distributionId,
                dateReleased: cmp.get('v.releaseDate')
            })
        });
        action.setCallback(
            this,
            $A.getCallback(function(response) {
                var state = response.getState();
                if (state === 'SUCCESS') {
                    var returnVal = JSON.parse(response.getReturnValue());
                    console.log('releaseCharges: returnVal = ' + returnVal);
                    this.getRecords(cmp); // Refetch records to ensure everything is up to date.
                } else if (state === 'ERROR') {
                    var errors = response.getError();
                    console.error(errors);
                }
            })
        );
        $A.enqueueAction(action);
    },

    // Invoke server-side controller to unrelease given charges.
    unreleaseCharges: function(cmp, charges) {
        console.log('unreleaseCharges...');
        cmp.set('v.waiting', true);
        var action = cmp.get('c.unreleaseCharges');
        action.setParams({
            jsonString: JSON.stringify({
                chargeIds: this.idsFromObjs(charges)
            })
        });
        action.setCallback(
            this,
            $A.getCallback(function(response) {
                var state = response.getState();
                if (state === 'SUCCESS') {
                    var returnVal = JSON.parse(response.getReturnValue());
                    console.log('unreleaseCharges: returnVal = ' + returnVal);
                    this.getRecords(cmp); // Refetch records to ensure everything is up to date.
                } else if (state === 'ERROR') {
                    var errors = response.getError();
                    console.error(errors);
                }
            })
        );
        $A.enqueueAction(action);
    },

    // Return list of ids extracted from given objects.
    idsFromObjs: function(objList) {
        var idList = [];
        for (var i = 0; i < objList.length; i++) idList.push(objList[i].Id);
        console.log('idsFromObjs: idList = ' + JSON.stringify(idList));
        return idList;
    },

    // Sort given table by given column.
    sortData: function(cmp, dataName, fieldName, sortDirection) {
        var data = cmp.get('v.' + dataName + 'Data');
        var reverse = sortDirection !== 'asc';
        //sorts the rows based on the column header that's clicked
        data.sort(this.sortBy(fieldName, reverse));
        cmp.set('v.' + dataName + 'Data', data);
    },
    sortBy: function(field, reverse, primer) {
        var key = primer
            ? function(x) {
                  return primer(x[field]);
              }
            : function(x) {
                  return x[field];
              };
        //checks if the two rows should switch places
        reverse = !reverse ? 1 : -1;
        return function(a, b) {
            return (a = key(a)), (b = key(b)), reverse * ((a > b) - (b > a));
        };
    }
});