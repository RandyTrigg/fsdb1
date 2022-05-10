import { LightningElement, api } from 'lwc';

export default class FormComponent extends LightningElement {

    @api cmp;
    @api formInstanceId;
    @api isEditable;
    @api language;
    isVisible = false; // Will need to be dynamically computed once new connector framework is in place
    parentHidden = false; // Will need to be dynamically computed once new connector framework is in place

    connectedCallback() {
        /*
        setTimeout(() => {
            alert(this.cmp.title);
            alert('isRequired = ' +this.cmp.isRequired);
            alert('isCheckbox = ' +this.cmp.isCheckbox);
            alert('Ic = ' +this.cmp.Id);
            alert('intro = ' +this.cmp.intro);
            alert('childCmps = ' +this.cmp.childCmps);
        }, 5);
        */
        this.isVisible = true;
        console.log('connectedCallback: this.cmp', this.cmp);
        console.log('connectedCallback: this.formInstanceId', this.formInstanceId);
        console.log('connectedCallback: this.isEditable', this.isEditable);
        console.log('connectedCallback: this.language', this.language);
    }

    //allows parent to check if this component is valid (all child components have a value if required)
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