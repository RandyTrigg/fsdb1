({
    getCoreInfo: function(cmp) {
        // The sub component overrides this Get function (for profile or proposal).  Its callback should call getGMDataInfo.
        getGMDataInfo(cmp);
    },
    getGMDataInfo: function(cmp) {
        // Fetch the gm Data information from the database.
        this.disableEdits(cmp);
        cmp.set('v.fetching', true);
        var action = cmp.get('c.getGMDataInfo');
        action.setParams({
            gmDataId: cmp.get('v.gmDataId')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                cmp.set('v.gmDataInfo', response.getReturnValue());
                if (cmp.get('v.gmDataInfo'))
                    cmp.set('v.gmData', cmp.get('v.gmDataInfo').gmData);
                console.log(
                    'getGMDataInfo: v.gmDataId = ' +
                        cmp.get('v.gmDataId') +
                        '; v.gmDataInfo = ' +
                        JSON.stringify(cmp.get('v.gmDataInfo'))
                );
                // We're done fetching from the database controller.
                // NOTE: Putting the endFetching call in insertReviewComponents's callback causes an error.
                this.endFetching(cmp);
                // Put out review components unless they're already there.
                if (cmp.get('v.reviewComponents').length == 0)
                    this.insertReviewComponents(cmp);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'getGMDataInfo Error message: ' +
                        JSON.stringify(response.getError())
                );
            }
        });
        $A.enqueueAction(action);
    },
    insertReviewComponents: function(cmp) {
        var _this = this;
        console.log('insertReviewComponents: ...');
        var comps = this.buildAllReviewComponents(cmp);
        console.log('insertReviewComponents: comps = ' + JSON.stringify(comps));
        if (comps.length > 0) {
            $A.createComponents(comps, function(components, status) {
                if (status == 'SUCCESS') {
                    console.log(
                        'insertReviewComponents: status = ' +
                            status +
                            '; components.length = ' +
                            components.length
                    );
                    cmp.set('v.reviewComponents', components);
                } else {
                    console.log(
                        'insertReviewComponents: status = ' +
                            status +
                            '; components.length = ' +
                            components.length
                    );
                }
            });
        }
    },
    // Build lightning components for the review form components of all gm data infos.
    buildAllReviewComponents: function(cmp) {
        var components = [];
        var gmDataInfo = cmp.get('v.gmDataInfo');
        console.log(
            'buildAllReviewComponents: gmDataInfo = ' +
                JSON.stringify(gmDataInfo)
        );
        // First build lightning components for the core review form.
        var reviewCompsCore = this.getReviewComponentsCore(cmp);
        Array.prototype.push.apply(
            components,
            this.buildReviewComponents(cmp, reviewCompsCore, 0, gmDataInfo)
        );
        return components;
    },
    getReviewComponentsCore: function(cmp) {
        // Override this function in sub-component (profile or proposal).
        return [];
    },
    // Build review form components for a single gmDataInfo instance
    buildReviewComponents: function(cmp, reviewComps, index, gmDataInfo) {
        var notReceived = cmp.get('v.notReceived');
        var components = [];
        var objMap = cmp.get('v.objectMap');
        for (var i = 0; i < reviewComps.length; i += 1) {
            var rc = reviewComps[i];
            var disable = notReceived && !rc.Enable_before_form_submitted__c; // Disable if key form hasn't been received (with exceptions).
            console.log(
                'buildReviewComponents loop: rc = ' + JSON.stringify(rc)
            );
            var objName = objMap[rc.Object_name__c];
            var cName = rc.Lightning_component_name__c;
            if (cName == 'IndicatorGroup') {
                // Build indicator group component, passing in the raw components for the group's indicators.
                components.push([
                    'c:IndicatorGroup',
                    {
                        label: rc.Label__c,
                        indicatorType: rc.Join_object_type__c,
                        rawComponents: this.buildIndicatorComponents(
                            cmp,
                            index,
                            objName,
                            rc.Join_object_type__c,
                            gmDataInfo,
                            i,
                            disable
                        )
                    }
                ]);
            } else {
                var fName = rc.Field_name__c;
                var childType = rc.Join_object_type__c;
                var c = [
                    'c:' + cName,
                    { label: rc.Label__c, helpText: rc.Help_text__c }
                ];
                var m = c[1];
                // If it's not a heading, then must be an input component so fill in rest of attributes.
                if (
                    cName != 'HeadingMedium' &&
                    cName != 'HeadingSmall' &&
                    cName != 'Label'
                ) {
                    m['aura:id'] = 'inputCmp';
                    m['id'] = index + '-' + i;
                    m['recordIndex'] = index;
                    m['objName'] = objName;
                    m['fieldName'] = fName;
                    m['placeholder'] = rc.Placeholder__c;
                    m['required'] = rc.Required__c;
                    m['disabled'] = disable;
                    if (cName == 'InputSelect') {
                        // Grab picklist for this select field, and add a "none" value at the front.
                        // Note that picklists are stored with lower case field names.
                        var pList =
                            objName == 'gmDataInfo'
                                ? gmDataInfo.picklists[fName.toLowerCase()]
                                : this.getPicklistCore(cmp, fName);
                        console.log(
                            'buildReviewComponents: fName = ' +
                                fName +
                                '; pList = ' +
                                JSON.stringify(pList)
                        );
                        if (pList) m['picklist'] = [''].concat(pList);
                    }
                    // Fill in value as well as attributes for the Select components.
                    console.log('buildReviewComponents loop: fName = ' + fName);
                    if (cName == 'InputSelectLookup')
                        this.setSelectLookupAttrsCore(cmp, m, fName);
                    if (cName.indexOf('InputSelectMulti') > -1) {
                        if (objName != 'gmDataInfo') {
                            this.setSelectMultiAttrsCore(
                                cmp,
                                m,
                                rc.Join_object_name__c,
                                childType
                            );
                        } else if (childType) {
                            // Multi select fields for gmDataInfo must have non-blank child type.
                            m['value'] =
                                gmDataInfo.selectedIdsPacked[childType];
                            m['type'] = 'idList';
                            m['fieldName'] =
                                'selectedIdsPacked[' + childType + ']';
                            m['selecteds'] =
                                gmDataInfo.selectedNames[childType];
                            m['unselecteds'] =
                                gmDataInfo.unselectedNames[childType];
                            m['idNameMap'] = gmDataInfo.nameMap;
                        }
                    } else
                        m['value'] =
                            objName == 'gmDataInfo'
                                ? gmDataInfo.gmData[fName]
                                : this.getValueCore(cmp, fName);
                }
                console.log(
                    'buildReviewComponents loop: c = ' + JSON.stringify(c)
                );
                components.push(c);
            }
        }
        return components;
    },
    // Build review form components for a single indicator group
    buildIndicatorComponents: function(
        cmp,
        index,
        objName,
        indicatorType,
        gmDataInfo,
        reviewCompCount,
        disable
    ) {
        var components = [];
        var inds = gmDataInfo.indicatorMap[indicatorType];
        console.log(
            'buildIndicatorComponents: gmDataInfo.indicatorMap = ' +
                JSON.stringify(gmDataInfo.indicatorMap)
        );
        console.log('buildIndicatorComponents: inds = ' + JSON.stringify(inds));
        for (var j = 0; j < inds.length; j += 1) {
            var ind = inds[j];
            var indJoin = gmDataInfo.indicatorAssignMap[ind.Id];
            var c = [
                'c:InputIndicator',
                {
                    label:
                        (ind.Code__c ? ind.Code__c + ' ' : '') +
                        ind.Description__c,
                    'aura:id': 'inputCmp',
                    id: index + '-' + reviewCompCount + '-' + j,
                    recordIndex: index,
                    objName: objName,
                    fieldName: 'indicatorAssignInfo[' + ind.Id + ']',
                    indicatorType: indicatorType,
                    requiresQuantity: ind.Requires_number__c,
                    requiresComment: ind.Requires_comment__c,
                    valueChecked: indJoin ? true : false,
                    valueQuantity: indJoin ? indJoin.Quantity__c : null,
                    valueComment: indJoin ? indJoin.Comment__c : null,
                    disabled: disable
                }
            ];
            console.log('buildIndicatorComponents: c = ' + JSON.stringify(c));
            components.push(c);
        }
        return components;
    },
    getPicklistCore: function(cmp, fieldName) {
        // Override this function in sub-component (profile or proposal).
    },
    getValueCore: function(cmp, fieldName) {
        // Override this function in sub-component (profile or proposal).
    },
    setSelectLookupAttrsCore: function(cmp, attrs, fieldName) {
        // Override this function in sub-component (profile or proposal).
    },
    setSelectMultiAttrsCore: function(cmp, attrs, joinObjName, childType) {
        // Override this function in sub-component (profile or proposal).
    },
    // Wrap up actions for when we've fetched everything successfully.
    endFetching: function(cmp) {
        cmp.set('v.fetching', false);
        cmp.set('v.submitting', false);
        cmp.set('v.saving', false);
        this.enableEdits(cmp);
    },
    // User-induced save
    save: function(cmp) {
        var _this = this;
        console.log('GMDataEditSuper save...');
        // Disable edits
        this.disableEdits(cmp);
        cmp.set('v.saving', true);
        // Set fields using current values in input components.
        this.setFieldsFromInputCmps(cmp);
        // Save field updates to the database.
        // Remainder of Save functionality happens in the callback of the server action.
        this.updateDatabase(cmp);
    },
    disableEdits: function(cmp) {
        var cmpTarget = cmp.find('TopLevelEdit');
        $A.util.addClass(cmpTarget, 'disabledDiv');
        console.log('disableEdits');
    },
    enableEdits: function(cmp) {
        var cmpTarget = cmp.find('TopLevelEdit');
        $A.util.removeClass(cmpTarget, 'disabledDiv');
        console.log('enableEdits');
    },
    setFieldsFromInputCmps: function(cmp) {
        console.log('GMDataEditSuper setFieldsFromInputCmps');
        // Get the components.
        var cmps = this.getReviewComponents(cmp);
        for (var i = 0; i < cmps.length; i++) {
            var readonly = cmps[i].get('v.readonly');
            console.log(
                'GMDataEditSuper setFieldsFromInputCmps: readonly = ' + readonly
            );
            if (!readonly) {
                var objName = cmps[i].get('v.objName');
                var fieldName = cmps[i].get('v.fieldName');
                var fieldValue = cmps[i].get('v.value');
                var fieldType = cmps[i].get('v.type');
                console.log(
                    'GMDataEditSuper setFieldsFromInputCmps: objName = ' +
                        objName +
                        '; fieldName = ' +
                        fieldName +
                        '; fieldValue = ' +
                        fieldValue +
                        '; fieldType = ' +
                        fieldType
                );
                // Trim text fields to 255 chars before saving.
                if (fieldType == 'text' && fieldValue && fieldValue.length > 0)
                    fieldValue = fieldValue.substring(0, 255);
                if (
                    objName.indexOf('gmDataInfo') > -1 &&
                    fieldName.indexOf('selectedIdsPacked') == -1 &&
                    fieldName.indexOf('indicatorAssignInfo') == -1
                )
                    objName += '.gmData'; // A field in gmData, as opposed to a join record
                console.log(
                    'GMDataEditSuper setFieldsFromInputCmps testing fieldType: fieldType = ' +
                        fieldType
                );
                this.setField(cmp, objName, fieldName, fieldValue);
            }
        }
    },
    // Return array of review components, including indicators.
    // Build mapping from indicator indices to indicator group components, for use during validation.
    getReviewComponents: function(cmp) {
        var components = [];
        var index = 0;
        var mapping = {};
        // Get the components, "flattening" the list by pulling up the ones inside indicator groups.
        var cmps = cmp.get('v.reviewComponents');
        for (var i = 0; i < cmps.length; i++) {
            if (cmps[i].get('v.type') == 'indicatorGroup') {
                var iCmps = cmps[i].get('v.indicatorComponents');
                for (var j = 0; j < iCmps.length; j++) {
                    components.push(iCmps[j]);
                    mapping[index] = cmps[i]; // Map current index to indicator group component.
                    index++;
                }
            } else {
                components.push(cmps[i]);
                index++;
            }
        }
        cmp.set('v.indicatorGroupMap', mapping); // Stash the indicator group mapping.
        return components;
    },
    setField: function(cmp, objName, fieldName, fieldValue) {
        console.log(
            'GMDataEditSuper setField: setting v.' +
                objName +
                '.' +
                fieldName +
                ' to ' +
                fieldValue
        );
        if (objName == 'gmDataInfo')
            cmp.set('v.' + objName + '.' + fieldName, fieldValue);
        else this.setFieldCore(cmp, objName, fieldName, fieldValue);
    },
    setFieldCore: function(cmp, objName, fieldName, fieldValue) {
        // Override this function in sub-component.
    },
    // Save latest changes to the database, first for the core record and then for any GM Data records.
    // updateDatabase method is overwritten by sub-component (for profile vs proposal).
    updateDatabase: function(cmp) {
        // The sub-component's "updateDatabase" method should call this next method in the chain.
        this.updateDatabaseGMData(cmp);
    },
    updateDatabaseGMData: function(cmp) {
        var _this = this;
        console.log('GMDataEditSuper updateDatabaseGMData...');
        // JSON serialize the GMDataInfo record - to avoid errors on the server.
        var gmDataInfo = cmp.get('v.gmDataInfo');
        var gmDataInfoSerialized = JSON.stringify(gmDataInfo);
        var action = cmp.get('c.saveGMDataInfo');
        action.setParams({
            gmDataInfoSerialized: gmDataInfoSerialized
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            var errResponse = JSON.stringify(response.getError());
            if (cmp.isValid() && state === 'SUCCESS') {
                console.log('GMDataEditSuper updateDatabaseGMData SUCCESS');
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log('state=ERROR: errResponse: ' + errResponse);
            } else if (cmp.isValid() && state === 'INCOMPLETE') {
                console.log('state=INCOMPLETE: errResponse: ' + errResponse);
                return;
            }
            cmp.set(
                'v.errResponseGMData',
                errResponse == '[]' ? null : errResponse
            );
            console.log(
                'GMDataEditSuper updateDatabaseGMData: before validate: v.numErrors = ' +
                    cmp.get('v.numErrors')
            );
            this.validate(cmp);
            console.log(
                'GMDataEditSuper updateDatabaseGMData: after validate: v.numErrors = ' +
                    cmp.get('v.numErrors')
            );
            // Re-fetch data to get the updated status and in case anyone changed the records from outside this interface.
            // Also causes GMDataInfo to be fetched.  Enables edits when it's done.
            this.getCoreInfo(cmp);
        });
        $A.enqueueAction(action);
    },
    validate: function(cmp) {
        console.log('GMDataEditSuper validate');
        var numErrors = 0;
        // Combine error responses from db.
        var eCore = cmp.get('v.errResponseCore');
        var eGMData = cmp.get('v.errResponseGMData');
        console.log('validate: eCore = ' + eCore + '; eGMData = ' + eGMData);
        var pageErrors =
            eCore || eGMData
                ? ((eCore || '') + ' ' + (eGMData || '')).trim()
                : null;
        console.log('validate: pageErrors = ' + pageErrors);
        // Get the mapping from indicator indices to indicator group components.
        var iGroupMapping = cmp.get('v.indicatorGroupMap');
        console.log(
            'GMDataEditSuper validate: iGroupMapping = ' +
                JSON.stringify(iGroupMapping)
        );
        // Validate the input components one at a time.
        var cmps = this.getReviewComponents(cmp);
        // Decide whether we should not check required fields.
        var noCheckRequired = this.overrideRequiredFieldsTest(cmp, cmps);
        for (var i = 0; i < cmps.length; i++) {
            var readonly = cmps[i].get('v.readonly');
            if (!readonly) {
                var fName = cmps[i].get('v.fieldName');
                var val = cmps[i].get('v.value');
                var type = cmps[i].get('v.type');
                var required = cmps[i].get('v.required');
                var errMessage = null;
                console.log(
                    'GMDataEditSuper validate: fName = ' +
                        fName +
                        '; val = ' +
                        val +
                        '; required = ' +
                        required
                );
                // Can't seem to get an error message back from server that is specific to a field.
                // 2/24/17: Alternatively, we could try to compare prior and current value and alert when they're not equal?
                if (type == 'indicator' && val) {
                    var comment = cmps[i].get('v.valueComment');
                    var quantityMissing =
                        cmps[i].get('v.requiresQuantity') &&
                        cmps[i].get('v.valueQuantity') == null;
                    var commentMissing =
                        cmps[i].get('v.requiresComment') && comment == null;
                    if (quantityMissing || commentMissing) {
                        errMessage =
                            quantityMissing && commentMissing
                                ? 'The quantity and comment parts of the indicator are required.'
                                : quantityMissing
                                ? 'The quantity part of the indicator is required.'
                                : 'The comment part of the indicator is required.';
                        // Ensure that enclosing indicator group is expanded, so error message is visible.
                        var iGroupCmp = iGroupMapping[i];
                        console.log(
                            'GMDataEditSuper validate loop: i = ' +
                                i +
                                '; iGroupCmp = ' +
                                JSON.stringify(iGroupCmp)
                        );
                        iGroupCmp.set('v.expanded', true);
                    } else if (comment.length > 255) {
                        // Comment is stashed in a text field in SF so capped at 255 chars.
                        errMessage =
                            'Indicator comment too long (' +
                            comment.length +
                            ' characters).' +
                            ' Please trim to at most 255 characters.';
                    }
                } else if (!noCheckRequired && required && !val) {
                    // Missing "required" field.
                    errMessage = 'This field is required.';
                } else if (type == 'text' && val && val.length > 255) {
                    // Text field too long.
                    errMessage =
                        'Text is too long (' +
                        val.length +
                        ' characters).' +
                        ' Please trim to at most 255 characters.';
                }
                // Display error message.
                cmps[i].set('v.errorMessage', errMessage);
                if (errMessage) numErrors = numErrors + 1;
            }
        }
        // Set error count, and error messages belonging to the entire page.
        $A.util.addClass(cmp.find('saveForErrorCountSpan'), 'slds-hide');
        cmp.set('v.numErrors', numErrors);
        $A.util.removeClass(cmp.find('numErrorsSpan'), 'slds-hide');
        cmp.set('v.pageErrors', pageErrors);
        if (pageErrors)
            $A.util.removeClass(cmp.find('pageErrorsSpan'), 'slds-hide');
        else $A.util.addClass(cmp.find('pageErrorsSpan'), 'slds-hide');
    },
    // Determine whether required fields tests are necessary for submit.  Override in sub-component.
    overrideRequiredFieldsTest: function(cmp, reviewCmps) {
        return false;
    },
    // Allow re-submit of review, but don't overwrite an existing date review completed.
    submitReview: function(cmp) {
        console.log('GMDataEditSuperHelper submitReview...');
        if (cmp.get('v.numErrors') == 0) {
            cmp.set('v.submitting', true);
            this.setDateReviewedCore(cmp);
            this.save(cmp);
        }
    },
    setDateReviewedCore: function(cmp) {
        // Override this function in sub-component (profile or proposal).
    },
    todayDate: function(cmp) {
        var today = new Date();
        var dd = today.getDate();
        var mm = today.getMonth() + 1; //January is 0!
        var yyyy = today.getFullYear();
        if (dd < 10) dd = '0' + dd;
        if (mm < 10) mm = '0' + mm;
        return yyyy + '-' + mm + '-' + dd;
    }
});