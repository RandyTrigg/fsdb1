// Has either a Proposal Id, Profile Id, or Grantee Report Id and fetches the form instance IDs that should be displayed for review
import { LightningElement, api } from 'lwc';

// APEX Imports
import getFormInstances from '@salesforce/apex/SiteController.getFormInstances';

export default class formViewer extends LightningElement {
    @api recordId;
    @api isNonEditable;
    formInstances = [];
    dataLoaded = false;

    connectedCallback() {
        if (this.recordId) {
            this.loadData();
        }
    }

    async loadData() {
        console.log('loadData');
        let formInstances = await getFormInstances({id:this.recordId});
        this.formInstances = JSON.parse(formInstances);
        // console.log('this.formInstances');
        // console.log(this.formInstances);
        for (let fi of this.formInstances) {
            // console.log('frm');
            // console.log(frm);
            fi.title = fi.Form__r.Form_Phrase_Title__r.Phrase_in_English__c + " (Submitted: " + fi.Date_submitted__c + ")";
        }
        this.dataLoaded = true;
    }
}