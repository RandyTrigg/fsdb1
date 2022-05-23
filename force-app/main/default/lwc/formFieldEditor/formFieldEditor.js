import { LightningElement, api, wire} from 'lwc';
import { handleError } from 'c/lwcUtilities';
import updateFormData from '@salesforce/apex/SiteController.updateFormData';

export default class FormFieldEditor extends LightningElement {
    @api cmp;
    localCmp = {}; //need a copy of the passed in proxy to keep values updated in-memory
    @api formInstanceId;
    @api isRequired;
    @api parentHidden = false;
    @api isReadOnly;
    subscription = null;
    isVisible = true;
    initialRenderDone = false;
    currentLength;
   

    async connectedCallback() {
        if (this.cmp) {
            this.localCmp = JSON.parse(JSON.stringify(this.cmp));
            console.log('formFieldEditor connectedCallback: this.localCmp', this.localCmp);
            //console.log('formFieldEditor connectedCallback: this.parentHidden', this.parentHidden);
            //console.log('formFieldEditor connectedCallback: this.isVisible', this.isVisible);
            if (this.localCmp.isText && this.localCmp.data.Data_text__c) {
                this.currentLength = this.localCmp.data.Data_text__c.length;
            } else if (this.localCmp.isTextArea && this.localCmp.data.Data_textarea__c) {
                this.currentLength = this.localCmp.data.Data_textarea__c.length;
            }
        }
    }

    //allows parent to check if this field is valid (if required, has a value)
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

            const allRadioGroupsValid = [...this.template.querySelectorAll('lightning-radio-group')]
                .reduce((validSoFar, inputCmp) => {
                    return validSoFar && inputCmp.checkValidity();
                }, true);

            const allCheckboxGroupsValid = [...this.template.querySelectorAll('lightning-checkbox-group ')]
                .reduce((validSoFar, inputCmp) => {
                    return validSoFar && inputCmp.checkValidity();
                }, true);

            if (allLightningInputsValid && allTextAreasValid && allRadioGroupsValid && allCheckboxGroupsValid) {
                return true;
            } else {
                return false;
                
            }
        }

        
    }

    checkForVisibility(value) {
        let tempVisiblity = false; //assume hidden, unless the data in the source component matches.  Use a temp variable so we don't hide the item while we're reassessing on a data change.

        if (this.localCmp.isTargetConnectors && this.localCmp.isTargetConnectors.length>0) {
            for (let connector of this.localCmp.isTargetConnectors) {
                if (connector.Form_Phrase__r.Name == value) {
                    if (connector.Operation__c=='Enable') {
                        tempVisiblity = true;
                    }
                    
                }
            }
            this.isVisible = tempVisiblity;
        } else {
            this.isVisible = true;
        }

    }

    @api setParentVisibility(visibility) {
        this.parentHidden = visibility;
    }


    @api handleSourceTargetChange(message) {

        // If the updated component is a source for this item, make any adjustments needed
        if (this.localCmp.isTargetConnectors) {
            for (let connector of this.localCmp.isTargetConnectors) {
                if (message.cmpId == connector.Source_component__c) {
                    this.checkForVisibility(message.dataText);
                }
            }
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
        console.log('handleInputChange: this.localCmp', this.localCmp);
        console.log('handleInputChange: val', val);
        // Massage value in certain cases including checkbox group (separators between selections) and single checkbox (true/false versus blank).
        if (this.localCmp.isCheckboxGroup) {
            if (val.length > 0) val = val.join('|');
            else val = null;
        }
        if (this.localCmp.isCheckbox) val = event.target.checked;
        let dataText = val;
        if (this.localCmp.isTextArea) this.localCmp.data.Data_textarea__c = dataText;
        else this.localCmp.data.Data_text__c = dataText;
        if (this.localCmp.isText || this.localCmp.isTextArea) this.currentLength = dataText.length;
        try {
            this.sendUpdatedValue(dataText);

            //Notify parent that data has changed
            console.log('formFieldEditor handleInputChange dispatch cmpChange event', this.localCmp.Id, dataText);
            const cmpUpdated = new CustomEvent('cmpchange', { bubbles: true, composed: true, detail:{cmpId: this.localCmp.Id, dataText: dataText} });
            this.dispatchEvent(cmpUpdated);

        } catch(error) {
            handleError(error);
        }
    }

    // Upsert the form data record via apex
    async sendUpdatedValue(textData) {
        await updateFormData({frmInstanceId:this.localCmp.data.Form_Instance__c, componentId:this.localCmp.data.Form_Component__c, value:textData, isTextarea:this.localCmp.isTextArea});
    }


    

}