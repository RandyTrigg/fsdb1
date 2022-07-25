import { LightningElement, api } from 'lwc';

export default class FormComponent extends LightningElement {

    @api cmp;
    @api formInstanceId;
    @api language;
    @api isNonEditable = false; // External flag set once by caller or in app config
    @api isReadOnly; // Internal flag set and unset during processing at community
    @api transByNameObj;
    @api parentHidden = false;
    isVisible = false;
    hideChild = false; // Set to true if this component or its parent is hidden
    showIfVals = [];

    connectedCallback() {
        this.isVisible = true;
        //console.log('formComponent connectedCallback: this.cmp', this.cmp);
        // console.log('connectedCallback: this.formInstanceId', this.formInstanceId);
        // console.log('connectedCallback: this.isEditable', this.isEditable);
        // console.log('connectedCallback: this.language', this.language);
        if (this.cmp) {
            //console.log('formComponent connectedCallback: this.isNonEditable = ' +this.isNonEditable);
            // Compute the values of the controlling component (if any) that unhide this component
            const showIf = this.cmp.Show_if__c;
            if (showIf) this.showIfVals = showIf.split(',').map(s => s.trim()); 
            // Set visibility based on controlling component's initial value
            if (this.cmp.Controlling_component__c) this.visibility(this.cmp.controllingCmpInitialVal);
            //console.log('formComponent connectedCallback: this.cmp.Type__c = ' +this.cmp.Type__c+ '; this.cmp.isTextAnyFormat = ' +this.cmp.isTextAnyFormat);
        }
    }

    @api countErrors() {
        // If this component or its parent is hidden (that is, hideChild = true), then errors are ignored
        if (this.hideChild) return 0;
        const countChildCmpsErrs = [...this.template.querySelectorAll('c-form-component')]
            .reduce((countSoFar, formCmp) => {
                return countSoFar + formCmp.countErrors();
            }, 0);
        const countFormFieldErrs = [...this.template.querySelectorAll('c-form-field-editor')]
            .reduce((countSoFar, formField) => {
                return countSoFar + formField.countErrors();
            }, 0);
        return (countChildCmpsErrs + countFormFieldErrs);
    }

    @api highlightErrors() {
        [...this.template.querySelectorAll('c-form-component')]
            .forEach((formCmp) => {
                formCmp.highlightErrors();
            });
        [...this.template.querySelectorAll('c-form-field-editor')]
            .forEach((formField) => {
                formField.highlightErrors();
            });
    }

    // Allows parent to check if this component is valid (all child components and child form field are valid)
    // NO LONGER IN USE (7/21/2022)
    @api isValid() {
        const childCmpsValid = [...this.template.querySelectorAll('c-form-component')]
            .reduce((validSoFar, formCmp) => {
                return validSoFar && formCmp.isValid();
            }, true);
        const formFieldValid = [...this.template.querySelectorAll('c-form-field-editor')]
            .reduce((validSoFar, formField) => {
                return validSoFar && formField.isValid();
            }, true);
        return (childCmpsValid && formFieldValid);
    }

    // If applicable, use recent data change to set this component's visibility, then pass along to child components
    @api reassessVisibility(cmpId, newData) {
        console.log('formComponent.reassessVisibility: cmpId/newData', cmpId, newData);
        console.log('formComponent.reassessVisibility: Id/Controlling_component__c', this.cmp.Id, this.cmp.Controlling_component__c);
        if (cmpId == this.cmp.Controlling_component__c) this.visibility(newData);
        [...this.template.querySelectorAll('c-form-component')]
            .forEach((formCmp) => {
                formCmp.reassessVisibility(cmpId, newData);
            });
    }

    // Check given connector value against the "showIf" values in this component to compute visibility for this component and for children
    visibility(connectorVal) {
        console.log('formComponent.visibility: connectorVal/showIfVals = ', connectorVal, this.showIfVals[0], this.showIfVals);
        this.isVisible = this.showIfVals.length == 0 || this.showIfVals.includes(connectorVal);
        this.hideChild = this.parentHidden || !this.isVisible;
        console.log('formComponent.visibility: isVisible/hideChild = ', this.isVisible, this.hideChild);
    }
}