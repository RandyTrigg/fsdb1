// Has either a Proposal Id, Profile Id, or Grantee Report Id and fetches the form instance IDs that should be displayed for review
import { LightningElement, api } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';

// APEX Imports
import getFormInstances from '@salesforce/apex/SiteController.getFormInstances';

export default class EmbeddedFormViewer extends NavigationMixin(LightningElement) {
    @api recordId;
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
        for (let frm of this.formInstances) {
            // console.log('frm');
            // console.log(frm);
            frm.title = frm.Form__r.Form_Phrase_Title__r.Phrase_in_English__c + " (Submitted: " + frm.Date_submitted__c + ")";
        }
        this.dataLoaded = true;
    }
}