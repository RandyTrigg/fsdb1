import { LightningElement, api } from 'lwc';

export default class FormComponent extends LightningElement {

    @api cmpData;
    @api formInstanceId;
    @api isEditable;
    @api language;

    //allows parent to check if this section is valid (all child components have a value if required)
    @api isValid() {
        let allValid = true;
        this.template.querySelectorAll('c-form-component').forEach(element => {
            if (element.isValid()!=true) allValid = false;
        });
        return allValid;
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