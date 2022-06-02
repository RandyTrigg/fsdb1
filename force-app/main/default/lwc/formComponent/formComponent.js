import { LightningElement, api } from 'lwc';

export default class FormComponent extends LightningElement {

    @api cmp;
    @api formInstanceId;
    @api language;
    @api isNonEditable = false; // External flag set once by caller or in app config
    @api isReadOnly; // Internal flag set and unset during processing at community
    @api transByNameObj;
    isVisible = false; // Will need to be dynamically computed once new connector framework is in place
    parentHidden = false; // Will need to be dynamically computed once new connector framework is in place

    connectedCallback() {
        this.isVisible = true;
        //console.log('formComponent connectedCallback: this.cmp', this.cmp);
        // console.log('connectedCallback: this.formInstanceId', this.formInstanceId);
        // console.log('connectedCallback: this.isEditable', this.isEditable);
        // console.log('connectedCallback: this.language', this.language);
        if (this.cmp) {
            console.log('formComponent connectedCallback: this.isNonEditable = ' +this.isNonEditable);
            //console.log('formComponent connectedCallback: this.cmp.Type__c = ' +this.cmp.Type__c+ '; this.cmp.isTextAnyFormat = ' +this.cmp.isTextAnyFormat);
        }
    }

    @api countErrors() {
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

    handleCmpChange(event) {
        //Tell children to assess visibility now that one of its siblings has changed
        let message = {cmpId: event.detail.cmpId, dataText: event.detail.dataText};

        this.template.querySelectorAll('c-form-component').forEach(element => {
            element.handleSourceTargetChange(message);
        });

        //Notify parent
        const cmpUpdated = new CustomEvent('changeddata', { bubbles: true, composed: true, detail:{cmpId: event.detail.cmpId, dataText: event.detail.dataText} });

        this.dispatchEvent(cmpUpdated);
    }
}