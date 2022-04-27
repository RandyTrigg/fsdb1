import { LightningElement, api, wire} from 'lwc';
import { handleError } from 'c/lwcUtilities';
import updateTextData from '@salesforce/apex/FormViewerController.updateTextData';
import updateTextAreaData from '@salesforce/apex/FormViewerController.updateTextAreaData';

export default class FormFieldEditor extends LightningElement {
    @api cmp;
    localCmp = {}; //need a copy of the passed in proxy to keep values updated in-memory
    @api formInstanceId;
    @api isRequired;
    subscription = null;
    isVisible = false;
    initialRenderDone = false;
    @api parentHidden = false;
    currentLength;
   

    async connectedCallback() {
        if (this.cmp) {
            this.localCmp = JSON.parse(JSON.stringify(this.cmp));
            if (this.localCmp.isText && this.localCmp.data.Data_text__c) {
                this.currentLength = this.localCmp.data.Data_text__c.length;
            } else if (this.localCmp.isTextArea && this.localCmp.data.Data_textarea__c) {
                this.currentLength = this.localCmp.data.Data_textarea__c.length;
            }
            if (this.localCmp.isTargetConnectors && this.localCmp.isTargetConnectors.length>0 && this.localCmp.sourceConnectorData && this.localCmp.sourceConnectorData.Data_text__c) {
                // this.subscribeToMessageChannel(); //Only subscribe to the message channel if this item is a target for a connector
                this.checkForVisibility(this.localCmp.sourceConnectorData.Data_text__c);
            } else {
                this.checkForVisibility(null);
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
 
    handleTextInputchange(event) {
        let dataText = event.target.value;
        this.localCmp.data.Data_text__c = dataText;
        try {
            this.sendUpdatedTextValue(dataText);

            //Notify parent section that data hs changed
            const cmpUpdated = new CustomEvent('cmpchange', { bubbles: true, composed: true, detail:{cmpId: this.localCmp.Id, dataText: dataText} });
            this.dispatchEvent(cmpUpdated);

        } catch(error) {
            handleError(error);
        }
    }

    handleRadioChange(event) {
        try {
            let textValue = event.target.value;
            this.sendUpdatedTextValue(textValue);
            this.localCmp.data.Data_text__c = textValue;

            //Switching to a model where Sections manage child component's visibility
            const cmpUpdated = new CustomEvent('cmpchange', { bubbles: true, composed: true, detail:{cmpId: this.localCmp.Id, dataText: textValue} });
            this.dispatchEvent(cmpUpdated);

        } catch(error) {
            handleError(error);
        }
        
    }

    async sendUpdatedTextValue(textData) {
        await updateTextData({frmInstanceId:this.localCmp.data.Form_Instance__c, componentId:this.localCmp.data.Form_Component__c, value:textData});
    }

    updateTextArea(event) {
        let dataText = event.target.value;
        this.localCmp.data.Data_textarea__c = dataText;
        this.currentLength = event.target.value.length;
    }

    async handleTextAreachange(event) {

        try {
            await updateTextAreaData({frmInstanceId:this.localCmp.data.Form_Instance__c, componentId:this.localCmp.data.Form_Component__c, value: this.localCmp.data.Data_textarea__c});
            
            //Switching to a model where Sections manage child component's visibility
            const cmpUpdated = new CustomEvent('cmpchange', { bubbles: true, composed: true, detail:{cmpId: this.localCmp.Id, dataText: this.localCmp.data.Data_textarea__c} });
            this.dispatchEvent(cmpUpdated);

        } catch(error) {
            handleError(error);
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




    

}