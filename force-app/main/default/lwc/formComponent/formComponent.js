import { LightningElement, api } from 'lwc';

export default class FormComponent extends LightningElement {

    @api cmp;
    @api formInstanceId;
    @api language;
    @api isReadOnly;
    @api transByNameObj;
    isVisible = false; // Will need to be dynamically computed once new connector framework is in place
    parentHidden = false; // Will need to be dynamically computed once new connector framework is in place

    connectedCallback() {
        this.isVisible = true;
        //console.log('formComponent connectedCallback: this.cmp', this.cmp);
        // console.log('connectedCallback: this.formInstanceId', this.formInstanceId);
        // console.log('connectedCallback: this.isEditable', this.isEditable);
        // console.log('connectedCallback: this.language', this.language);
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