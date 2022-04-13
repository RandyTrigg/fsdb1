import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

// Apex methods
import updateBoolean from '@salesforce/apex/ReviewFormController.updateBoolean';
import updateTextPickOrLookup from '@salesforce/apex/ReviewFormController.updateTextPickOrLookup';
import updateNumber from '@salesforce/apex/ReviewFormController.updateNumber';
import addClassificationJoin from '@salesforce/apex/ReviewFormController.addClassificationJoin';
import removeClassificationJoin from '@salesforce/apex/ReviewFormController.removeClassificationJoin';
import addIndicatorAssign from '@salesforce/apex/ReviewFormController.addIndicatorAssign';
import updateIndicatorComment from '@salesforce/apex/ReviewFormController.updateIndicatorComment';
import updateIndicatorQuantity from '@salesforce/apex/ReviewFormController.updateIndicatorQuantity';
import removeIndicatorAssign from '@salesforce/apex/ReviewFormController.removeIndicatorAssign';
import addPortfolioAssign from '@salesforce/apex/ReviewFormController.addPortfolioAssign';
import removePortfolioAssign from '@salesforce/apex/ReviewFormController.removePortfolioAssign';
import submitInternalReview from '@salesforce/apex/ReviewFormController.submitInternalReview';
import submitAssessorReview from '@salesforce/apex/AssessorSiteController.submitReview';

import { handleError } from 'c/lwcUtilities';
export default class ReviewForm extends NavigationMixin(LightningElement) {
    @api fullViewport = false; //The viewport is not full-sized unless this is set to true (optimized for LE View)
    @api review;
    @api isInternalReview;
    @track formComponentsArray = [];

    afterRenderComplete = false;

    formComponentMap = new Map();
    dataLoaded = false;
    readOnly = false;
    submitDisabled = true;

    // Lookup vars
    maxSelectionSize = 1;
    initialSelection;
    errors = [];
    recentlyViewed = [];

    //For profile forms with ranking
    profileImpactRankingOptions;

    connectedCallback() {
        if (this.review) {
            console.log('reviewForm.connectedCallback: this.review.formComponents');
            console.dir(this.review.formComponents);
            this.loadData();
        }
    }

    renderedCallback() {
        this.checkCompleteness();
        if(!this.afterRenderComplete) {
            //update styling after the initial render if needed
            this.afterRenderComplete = true;
            if (this.fullViewport) {
                console.log('full viewport is true');
                const scrollContainer = this.template.querySelector('[data-id="scrollcontainer"]');
                scrollContainer.classList.remove('partialViewport');
                scrollContainer.classList.add('fullViewport');
            }
        }
        
    }

    async loadData() {
        try {
            // Need to deep clone since there are internals with child objects 
            this.review = JSON.parse(JSON.stringify(this.review));

            //If there is a date submitted, it's a read-only Assessment; if isComplete is true the proposal or milestone has a completed date
            if ((this.review.dateSubmitted || this.review.isComplete) && !this.isInternalReview) {
                this.readOnly = true;
            }
            
            // Update components for markup
            for (let cmp of this.review.formComponents) {
                //Add "Cumulative" to the lable of any input whose object is GM Data
                if (cmp.objectName==="GM_Data__c" && cmp.label) {
                    cmp.label = cmp.label + " (Cumulative)";
                }
                switch(cmp.dataType) {
                    case 'HeadingSmall':
                        cmp.headingSmall = true;
                        break;
                    case 'HeadingMedium':
                        cmp.headingMedium = true;
                        break;
                    case 'InputText':
                        cmp.inputText = true;
                        break;
                    case 'InputSelectLookup':
                        if (cmp.fieldName=="Decline_reason__c" || cmp.fieldName=="Decline_reason__c") {// Decline Reason is a lookup, but we present it as a picklist, since it's not clear to all users what they would search for
                            cmp.inputSelect = true;
                            cmp.picklistValOptions = JSON.parse(cmp.jsonSelectOptions);
                            cmp.picklistValOptions.unshift({label: "-- None (Not Declined) --", value:null});
                        }
                        break;
                    case 'InputTextarea':
                        if (cmp.label.startsWith('Qualitative')) { //Qualitative fields get slightly different styling 
                            cmp.qualitativeInputText = true;
                        } else {
                            cmp.inputTextarea = true;
                        }
                        break;
                    case 'InputSelect':
                        // Picklist
                        cmp.inputSelect = true;
                        cmp.picklistValOptions = JSON.parse(cmp.jsonSelectOptions);
                        //for ranking fields on Profile, add an unselected option since they can't reuse values amongst the three fields
                        if (cmp.fieldName=='Priority_impact_area_1__c' || cmp.fieldName=='Priority_impact_area_2__c' || cmp.fieldName== 'Priority_impact_area_3__c') {
                            cmp.picklistValOptions.unshift({label: "-- Select --", value:null});
                        }
                        break;
                    case 'InputCheckbox':
                        cmp.inputCheckbox = true;
                        break;
                    case 'InputNumber':
                        cmp.inputNumber = true;
                        break;
                    case 'InputCheckbox':
                        cmp.inputCheckbox = true;
                        break;
                    case 'Label':
                        cmp.isLabel = true;
                        break;
                    case 'InputSelectMulti1':
                        if (cmp.joinObjectName=='Classification_Assign__c' || cmp.joinObjectName=='Classification_Profile_Assign__c'){
                            // get the set of classifications that match the type
                            let classificationAssigns = this.review.classificationAssignMap[cmp.joinObjectType];
                            let multiSelectOptions = [];
                            let multiSelectSelected = [];
                            for (let cls of classificationAssigns) {
                                multiSelectOptions.push({label:cls.classificationName, value:cls.classificationId});
                                if (cls.id) {
                                    multiSelectSelected.push(cls.classificationId);
                                }
                            }
                            cmp.isMultiSelect = true;
                            cmp.multiSelectOptions = multiSelectOptions;
                            cmp.multiSelectSelected = multiSelectSelected;
                        } else if (cmp.joinObjectName=='Portfolio_Assignment__c' || cmp.joinObjectName=='Portfolio_Profile_Assign__c') {
                            
                            let multiSelectOptions = [];
                            let multiSelectSelected = [];
                            let portfolioAssigns;

                            portfolioAssigns = this.review.portfolioAssignments;
                            
                            for (let pa of portfolioAssigns) {
                                multiSelectOptions.push({label:pa.portfolioName, value:pa.portfolioId});
                                if (pa.isAssigned) {
                                    multiSelectSelected.push(pa.portfolioId);
                                }
                            }
                            cmp.isMultiSelect = true;
                            cmp.multiSelectOptions = multiSelectOptions;
                            cmp.multiSelectSelected = multiSelectSelected;
                        }
                        break;
                    case 'IndicatorGroup':
                        cmp.indicatorGroup = true;
                        //Collection of Indicators: Query against Indicator_Assigns__c where 
                        //Indicator_outcome_type__c tells me the grouping.  Query for all Indicator_Assigns__c WHER Type == Indicator_outcome_type__c
                        //Upserting/deleting based on the data entered
                        // get the group of indicators for the specified outcome type,
                        let currentIndicators = this.review.indicatorAssignMap[cmp.indicatorOutcomeType]; //map: outcome id to 
                        let indicatorArray = [];
                        for (let ind in currentIndicators) {
                            let value = currentIndicators[ind];
                            if (value.id) {
                                value.selected = true;
                            } else {
                                value.selected = false;
                            }
                            indicatorArray.push(value);
                        }
                        cmp.indicators = indicatorArray;
                        break;
                }

                //Add to tracked array -- indicator components need to track internals
                this.formComponentMap.set(cmp.id, cmp);
                // Add to map for referencing as data is updated
                this.formComponentsArray = this.review.formComponents;

            }
;
            this.dataLoaded = true;
            
        } catch (error) {
            handleError(error);
        }
    }

    get submitHelptext() {
        if (this.review.dateSubmitted || this.review.isComplete) {
            if (this.isInternalReview) {
                return "Review has been submitted, you may update fields as needed.  This form will auto-save as you complete."
            } else {
                return "Review has been submitted and is Read-Only"
            }
            
        } else {
            return "Submit is disabled if required fields have not been completed. This form will auto-save as you complete."
        }
        
    }

    get submitLabel() {
        //If there is a date submitted, it's a read-only Assessment
        if (this.review.dateSubmitted || this.review.isComplete) {
            return "Submitted";
        } else  {
            return "Submit Review";
        }
    }

    async handleTextInputchange(event) {
        let cmpID = event.target.id.substring(0, 18);
        let cmp = this.formComponentMap.get(cmpID);
        this.checkCompleteness(); 
        try {
            await updateTextPickOrLookup({objectType:cmp.objectName, objectId:cmp.recordId, fieldName:cmp.fieldName, value:event.target.value});
        } catch(error) {
            handleError(error);
        }

    }

    async handleNumberInputchange(event) {
        let cmpID = event.target.id.substring(0, 18);
        let cmp = this.formComponentMap.get(cmpID);
        this.checkCompleteness(); 
        try {
            await updateNumber({objectType:cmp.objectName, objectId:cmp.recordId, fieldName:cmp.fieldName, value:event.target.value});
        } catch(error) {
            handleError(error);
        }

    }
    
   async handleInputSelectChange(event) {
        let cmpID = event.target.id.substring(0, 18);
        let cmp = this.formComponentMap.get(cmpID);
        this.checkCompleteness();
        try {
            await updateTextPickOrLookup({objectType:cmp.objectName, objectId:cmp.recordId, fieldName:cmp.fieldName, value:event.detail.value});
        } catch(error) {
            //Special handling for ranking errors (picklist values can only be used once between the three fields on Profile)
            try {
                let errorObj = JSON.parse(error.body.message);
                if (errorObj.exceptionMessage.includes('An impact area may appear in at most one of the three impact area rank fields')) {
                    dispatchEvent(
                        new ShowToastEvent({
                            title: 'Impact Area Rankings Must Be Unique',
                            message: 'Each impact area value can only be ranked once. (Top, Second, Third)',
                            variant: 'warning',
                            mode: 'sticky'
                        })
                    );
                    const selectInput = this.template.querySelector('[data-id='+cmpID+']');
                    selectInput.value = null;
                } else {
                    handleError(error);
                }
            } catch (parseError) {
                handleError(error);
            }
        }
    }

    handleMultiSelectChange(event) {
        let objName = event.target.name;
        if (objName=='Classification_Assign__c' || objName=='Classification_Profile_Assign__c') {
            this.handleClassifications(event);
        } else if (objName=='Portfolio_Assignment__c' || objName=='Portfolio_Profile_Assign__c') {
            this.handlePortfolioAssigns(event);
        }
    }

    async handleClassifications(event) {
        let selectedIds = event.detail.value;

        // get the source form component from the map
        let cmpID = event.target.id.substring(0, 18);
        let cmp = this.formComponentMap.get(cmpID);

        let classificationsAddedSet = new Set([]);
        let classificationsRemovedSet = new Set([]);

        if (selectedIds.length>cmp.multiSelectSelected.length) { //A classification was added
            for (let id of selectedIds) {
                if (!cmp.multiSelectSelected.includes(id)) {
                    classificationsAddedSet.add(id);
                }
            }
        } else if (cmp.multiSelectSelected.length>selectedIds.length)  { //A classification was removed
            for (let id of cmp.multiSelectSelected) {
                if (!selectedIds.includes(id)) {
                    classificationsRemovedSet.add(id);
                }
            }
        }
        // Update the internal list
        let uniqueSelectedIDs = new Set(selectedIds);
        cmp.multiSelectSelected = Array.from(uniqueSelectedIDs);
        // update the component in the map
        this.formComponentMap.set(cmpID, cmp);

        //Send updates to Apex
        try {
            let id;
            if (this.review.type=='Proposal') {
                id = this.review.linkedProposal.Id;
            } else if (this.review.type=='Profile') {
                id = this.review.linkedProfile.Id;
            }
            if (classificationsAddedSet.size>0) {
                // switch set back to array
                let classificationsAddedArray = Array.from(classificationsAddedSet);
                await addClassificationJoin({objectName:this.review.type, recordId:id, classificationIds:classificationsAddedArray});
            } else if (classificationsRemovedSet.size>0) {
                let classificationsRemovedArray = Array.from(classificationsRemovedSet);
                await removeClassificationJoin({objectName:this.review.type, recordId:id, classificationIds:classificationsRemovedArray});
            }
        } catch (error) {
            console.log('error');
            console.log(error);
            handleError(error);
        }
    }

    async handlePortfolioAssigns(event) {
        let selectedIds = event.detail.value;

        // get the source form component from the map
        let cmpID = event.target.id.substring(0, 18);
        let cmp = this.formComponentMap.get(cmpID);

        let portfoliosAdded = [];
        let portfoliosRemoved = [];

        if (selectedIds.length>cmp.multiSelectSelected.length) { //A portfolio was added
            for (let id of selectedIds) {
                if (!cmp.multiSelectSelected.includes(id)) {
                    portfoliosAdded.push(id);
                }
            }
        } else if (cmp.multiSelectSelected.length>selectedIds.length)  { //A portfolio was removed
            for (let id of cmp.multiSelectSelected) {
                if (!selectedIds.includes(id)) {
                    portfoliosRemoved.push(id);
                }
            }
        }
        try {
            let id;
            if (this.review.type=='Proposal') {
                id = this.review.linkedProposal.Id;
            } else if (this.review.type=='Profile') {
                id = this.review.linkedProfile.Id;
            }
            if (portfoliosAdded.length>0) {
                await addPortfolioAssign({objectName:this.review.type, recordId:id, portfolioIds:portfoliosAdded});
                cmp.multiSelectSelected = cmp.multiSelectSelected.concat(portfoliosAdded);
            } else if (portfoliosRemoved.length>0) {
                await removePortfolioAssign({objectName:this.review.type, recordId:id, portfolioIds:portfoliosRemoved});
                for (let id of portfoliosRemoved) {
                    cmp.multiSelectSelected = cmp.multiSelectSelected.filter(e => e !== id);
                }
            }
        } catch (error) {
            handleError(error);
        }
        

        // update the component in the map
        this.formComponentMap.set(cmpID, cmp);

    }

    async handleBooleanChange(event) {
        
        let cmpID = event.target.id.substring(0, 18);
        let cmp = this.formComponentMap.get(cmpID);

        try {
            await updateBoolean({objectType:cmp.objectName, objectId:cmp.recordId, fieldName:cmp.fieldName, value:event.target.checked});
        } catch(error) {
            handleError(error);
        }
    }

    async handleIndicatorChange(event) {

        let indID = event.target.id.substring(0, 18);
        let cmpId = event.target.name;

        // Have to iterate through the array that markup is using.  Would be nice to use the map, but can't iterate through map values on the front end
        try {
            for (let cmp of this.formComponentsArray) {
                if (cmp.id===cmpId) {
                    for (let ind of cmp.indicators) {
                        if (ind.indicatorId===indID) {
                            ind.selected = event.detail.checked;
                            if (event.detail.checked) {
                                // there may be cached values for quantity  and comments so we include the current values
                                await addIndicatorAssign({gmDataId:this.review.linkedGMData.Id, indicatorId:indID, quantity:ind.quantity, comments:ind.comment});
                            } else {
                                await removeIndicatorAssign({gmDataId:this.review.linkedGMData.Id, indicatorId:indID});
                            }
                        }
                    }
                }
            }
        } catch (error) {
            handleError(error);
        }
        
    }

    async handleIndicatorComments(event) {
        let indID = event.target.id.substring(0, 18);
        let cmpId = event.target.name;
        let comments = event.target.value;
        this.checkCompleteness();
        try {
            await updateIndicatorComment({gmDataId:this.review.linkedGMData.Id, indicatorId:indID, comment:event.target.value});
        } catch (error) {
            handleError(error);
        }
        

        // Have to iterate through the array that markup is using.  Would be nice to use the map, but can't iterate through map values on the front end
        for (let cmp of this.formComponentsArray) {
            if (cmp.id===cmpId) {
                for (let ind of cmp.indicators) {
                    if (ind.indicatorId===indID) {
                        ind.comment = comments;
                    }
                }
            }
        }
    }

    async handleIndicatorQuantity(event) {
        let indID = event.target.id.substring(0, 18);
        let cmpId = event.target.name;
        let quantity = event.target.value;

        // specifically cast empty as null
        if (!quantity) {
            quantity = null;
        }

        try {
            await updateIndicatorQuantity({gmDataId:this.review.linkedGMData.Id, indicatorId:indID, quantity:quantity});
        } catch (error) {
            handleError(error);
        }

        // Have to iterate through the array that markup is using to make change in-memory.  Would be nice to use the map, but can't iterate through map values on the front end
        for (let cmp of this.formComponentsArray) {
            if (cmp.id===cmpId) {
                for (let ind of cmp.indicators) {
                    if (ind.indicatorId===indID) {
                        ind.quantity = quantity;
                    }
                }
            }
        }
        this.checkCompleteness();
    }  

    checkCompleteness() {
        const allLightningInputsValid = [...this.template.querySelectorAll('lightning-input')]
            .reduce((validSoFar, inputCmp) => {
                return validSoFar && inputCmp.checkValidity();
            }, true);

        const allTextAreasValid = [...this.template.querySelectorAll('lightning-textarea')]
            .reduce((validSoFar, inputCmp) => {
                return validSoFar && inputCmp.checkValidity();
            }, true);

        const allComboBoxesValid = [...this.template.querySelectorAll('lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                return validSoFar && inputCmp.checkValidity();
            }, true);

        let allRequiredIndicatorsComplete = true;
        for (let cmp of this.formComponentsArray) {
            if (cmp.indicators) {
                for (let ind of cmp.indicators) {
                    if (ind.selected) {
                        if (ind.requiresComment && !ind.comment) {
                            allRequiredIndicatorsComplete = false;
                            break;
                        } else if (ind.requiresNumber && ind.quantity==null) {
                            allRequiredIndicatorsComplete = false;
                            break;
                        }
                    }
                }
            }
            
        }
        if (this.isInternalReview) {
            if (this.review.isComplete) {
                this.submitDisabled = true;
            } else if (allLightningInputsValid && allTextAreasValid && allComboBoxesValid && allRequiredIndicatorsComplete){
                this.submitDisabled = false;
            } else {
                this.submitDisabled = true;
            }
        } else {
            if (allLightningInputsValid && allTextAreasValid && allComboBoxesValid && allRequiredIndicatorsComplete && this.readOnly!=true) {
                this.submitDisabled = false;
            } else {
                this.submitDisabled = true;
            }
        }
    }

    highlightIncomplete() {
        //lightning-input check
        [...this.template.querySelectorAll('lightning-input')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
            }, true);

        //text area check
        [...this.template.querySelectorAll('lightning-textarea')]
        .reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
        }, true);

        //combobox check
        [...this.template.querySelectorAll('lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                        inputCmp.reportValidity();
            }, true);
    }

    async handleSubmit() {
        //construct toast
        const event = new ShowToastEvent({
            "title": "Success!",
            "message": "Review Submitted Successfully",
            "variant": "success"
        });
        
        if (this.isInternalReview) {
            try {
                let recId;
                if (this.review.type==="Milestone") {
                    recId = this.review.linkedMilestone.Id;
                } else if (this.review.type==="Profile") {
                    recId = this.review.linkedProfile.Id;
                } else if (this.review.type==="Proposal") {
                    recId = this.review.linkedProposal.Id;
                }
                await submitInternalReview({recordId:recId});
                this.dispatchEvent(event);
                eval("$A.get('e.force:refreshView').fire();");
            } catch (error) {
                handleError(error);
            }
        //In communities, navigate home after submit
        } else {
            try {
                await submitAssessorReview({assessmentId:this.review.Id});
                this.dispatchEvent(event);
            } catch (error) {
                handleError(error);
            }

            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: "Home"
                },
            });
            
        }
        
    }
}