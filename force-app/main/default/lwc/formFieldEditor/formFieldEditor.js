import { LightningElement, api, wire} from 'lwc';
import { handleError, buildError, showUIError } from 'c/lwcUtilities';
import updateFormData from '@salesforce/apex/SiteController.updateFormData';

export default class FormFieldEditor extends LightningElement {
    @api cmp;
    localCmp = {}; //need a copy of the passed in proxy to keep values updated in-memory
    @api formInstanceId;
    @api isRequired;
    @api parentHidden = false;
    @api isReadOnly;
    @api transByNameObj;
    subscription = null;
    initialRenderDone = false;
    numChars; // Running # of characters in text/textarea field
    numWords; // Running # of words in text/textarea field
   

    async connectedCallback() {
        if (this.cmp) {
            this.localCmp = JSON.parse(JSON.stringify(this.cmp));
            //console.log('formFieldEditor connectedCallback: this.localCmp', this.localCmp);
            //console.log('formFieldEditor connectedCallback: this.parentHidden', this.parentHidden);
            if (this.localCmp.isText && this.localCmp.data.Data_text__c) {
                this.numChars = this.localCmp.data.Data_text__c.length;
                this.numWords = this.countWords(this.localCmp.data.Data_text__c);
            } else if (this.localCmp.isTextArea && this.localCmp.data.Data_textarea__c) {
                this.numChars = this.localCmp.data.Data_textarea__c.length;
                this.numWords = this.countWords(this.localCmp.data.Data_textarea__c);
            }
        }
    }
 
    // Count words in a text string. From http://jsfiddle.net/deepumohanp/jZeKu/
    countWords(txt) {
        return txt ? txt.trim().replace(/\s+/gi, ' ').split(' ').length : 0;
    }

    // Count number of errors - aggregated with parents/ancestors for total number of errors
    @api countErrors() {
        // Look for custom errors before checking validity
        this.handleCustomErrors();
        return this.isValid() ? 0 : 1;
    }

    // Used by countErrors to check if this field is valid (if required, has a value)
    @api isValid() {
        //if this is hidden, it is automatically valid.
        if (this.hidden || this.parentHidden) {
            return true;
        } else {
            const allLightningInputsValid = [...this.template.querySelectorAll('lightning-input')]
                .reduce((validSoFar, inputCmp) => {
                    return validSoFar && inputCmp.checkValidity();
                }, true);
            const allTextAreasValid = [...this.template.querySelectorAll('lightning-textarea')]
                .reduce((validSoFar, inputCmp) => {
                    return validSoFar && inputCmp.checkValidity();
                }, true);
            //console.log('formFieldEditor isValid: allTextAreasValid', allTextAreasValid);
            const allRadioGroupsValid = [...this.template.querySelectorAll('lightning-radio-group')]
                .reduce((validSoFar, inputCmp) => {
                    return validSoFar && inputCmp.checkValidity();
                }, true);
            const allCheckboxGroupsValid = [...this.template.querySelectorAll('lightning-checkbox-group ')]
                .reduce((validSoFar, inputCmp) => {
                    return validSoFar && inputCmp.checkValidity();
                }, true);
            const allComboxesValid = [...this.template.querySelectorAll('lightning-combobox ')]
                .reduce((validSoFar, inputCmp) => {
                    return validSoFar && inputCmp.checkValidity();
                }, true);
            if (allLightningInputsValid && allTextAreasValid && allRadioGroupsValid && allCheckboxGroupsValid && allComboxesValid) {
                return true;
            } else {
                return false;
            }
        }
    }

    @api highlightErrors() {
        if (this.hidden || this.parentHidden) {
            return;
        } else {
            [...this.template.querySelectorAll('lightning-input')]
                .forEach((inputCmp) => {inputCmp.reportValidity();});
            [...this.template.querySelectorAll('lightning-textarea')]
                .forEach((inputCmp) => {inputCmp.reportValidity();});
            [...this.template.querySelectorAll('lightning-radio-group')]
                .forEach((inputCmp) => {inputCmp.reportValidity();});
            [...this.template.querySelectorAll('lightning-checkbox-group')]
                .forEach((inputCmp) => {inputCmp.reportValidity();});
            [...this.template.querySelectorAll('lightning-combobox')]
                .forEach((inputCmp) => {inputCmp.reportValidity();});
        }
    }

    renderedCallback() {
        if (!this.initialRenderDone) {
            this.initialRenderDone = true;
            this.notifyDataReady();
        }
    }

    notifyDataReady() {
        const fieldEditorReady = new CustomEvent('ready', {
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(fieldEditorReady);
    }
 
    // Single change handler for all types of input fields
    handleInputChange(event) {
        let val = event.target.value;
        //console.log('handleInputChange: this.localCmp', this.localCmp);
        //console.log('handleInputChange: val', val);
        // Massage value in certain cases including checkbox group (separators between selections) and single checkbox (true/false versus blank).
        if (this.localCmp.isCheckboxGroup) {
            if (val.length > 0) val = val.join('|');
            else val = null;
        }
        if (this.localCmp.isCheckbox) val = event.target.checked;
        let dataText = val;
        if (this.localCmp.isTextArea) this.localCmp.data.Data_textarea__c = dataText;
        else this.localCmp.data.Data_text__c = dataText;
        // Find and mark up custom errors 
        let element = this.handleCustomErrors();
        if (element) element.reportValidity();
        try {
            // Update form data record in db via apex call 
            let fieldUpdated = this.sendUpdatedValue(dataText);
            //Notify parent that data has changed
            //console.log('formFieldEditor handleInputChange dispatch cmpChange event', this.localCmp.Id, dataText);
            const cmpUpdated = new CustomEvent('cmpchange', { 
                bubbles: true, 
                composed: true, 
                detail:{cmpId: this.localCmp.Id, dataText: dataText, fieldUpdated: fieldUpdated}
            });
            this.dispatchEvent(cmpUpdated);
        } catch(error) {
            console.log('formFieldEditor handleInputChange: error: ' +error);
            handleError(error);
        }
    }

    // Check whether there are custom errors for this component; if so, set validity on the affected element.
    // Return the relevant element, if any.
    handleCustomErrors() {
        const c = this.localCmp;
        let message = '';
        let element;
        // Look for custom errors in specific elements
        if (c.isTextArea && c.Word_limit__c) {
            element = this.template.querySelector(`[data-id="textArea"]`);
            if (this.numWords > c.Word_limit__c) message = this.transByNameObj.TooManyWords;
        } else if (c.isCheckboxGroup && (c.Checkbox_limit__c || c.Checkbox_minimum__c)) {
            element = this.template.querySelector(`[data-id="checkboxGroup"]`);
            let val = element.value;
            // Note that checkbox group element's value is a vertical bar-separated string at load time, versus an array of selected options after first change. 
            let arr = Array.isArray(val) ? val 
                : (typeof val) == 'string' ? val.split('|') 
                : new Array();
            // console.log('handleCustomErrors: arr', arr);
            if (c.Checkbox_limit__c && (arr.length > c.Checkbox_limit__c)) message = this.transByNameObj.TooManyOptionsSel;
            else if (c.Checkbox_minimum__c && (arr.length < c.Checkbox_minimum__c)) message = this.transByNameObj.TooFewOptionsSel;
            // console.log('handleCustomErrors: c.Checkbox_limit__c = ' +c.Checkbox_limit__c+ '; c.Checkbox_minimum__c = ' +c.Checkbox_minimum__c+ '; message = ' +message);
        } else if (c.isEmail) {
            element = this.template.querySelector(`[data-id="email"]`);
            let val = element.value;
            const emailRegex=/^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
            if (val && !val.match(emailRegex)) message = this.transByNameObj.InvalidEmail;
        }
        //console.log('handleCustomErrors message = ', message);
        if (element) element.setCustomValidity(message);
        return element;
    } 

    // Upsert the form data record via apex. Return true if successful.
    async sendUpdatedValue(textData) { 
        try {
            let result = await updateFormData({
                frmInstanceId:this.localCmp.data.Form_Instance__c, 
                componentId:this.localCmp.data.Form_Component__c, 
                value:textData, 
                isTextarea:this.localCmp.isTextArea
            });
            if (!result) showUIError(buildError('Auto-save unsuccessful', 'Data in a field could not be saved - please contact your administrator'));
            return result;
        } catch (error) {
            console.log('sendUpdatedValue catch with recordId = ' +this.formInstanceId+ ' with error', error);
            showUIError(buildError('Auto-save unsuccessful', 'Data in a field could not be saved - please contact your administrator', 'error'));
            return false;
        }
    }

    // Handler for in progress changes (onKeyUp) in text fields
    updateTextArea(event) {
        let val = event.target.value;
        this.numChars = val.length;
        this.numWords = this.countWords(val);
    }

}