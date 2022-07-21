// Has either a Proposal Id, Profile Id, or Grantee Report Id and fetches the form instance IDs that should be displayed for review
import { LightningElement, api } from 'lwc';

// APEX Imports
import getFormInstances from '@salesforce/apex/SiteController.getFormInstances';

export default class formViewer extends LightningElement {
    @api recordId;
    @api transByNameObj = null; // Passed from assessment, not from internal review
    isNonEditable = true;
    formInstances = [];
    dataLoaded = false;

    connectedCallback() {
        if (this.recordId) {
            this.loadData();
        }
    }

    async loadData() {
        console.log('formViewer loadData');
        let formInstances = await getFormInstances({id:this.recordId});
        this.formInstances = JSON.parse(formInstances);
        for (let fi of this.formInstances) {
            console.log('in loop: fi', fi);
            // Perform translations if we're on the community (e.g. left side of Assessment interface), otherwise use English
            let advName = (fi.Advisor__c != null) ? ' ' +fi.Advisor__r.Name : '';
            const formPhraseName = fi.Form__r.Form_Phrase_Title__r.Name;
            console.log('in loop: formPhraseName', formPhraseName);
            const formTitle = this.transByNameObj && formPhraseName ? this.transByNameObj[formPhraseName] : fi.Form__r.Form_Phrase_Title__r.Phrase_in_English__c;
            console.log('in loop: formTitle', formTitle);
            const submittedTrans = this.transByNameObj ? this.transByNameObj.Submitted : 'Submitted';
            console.log('in loop: submittedTrans', submittedTrans);
            fi.title = formTitle + ' (' +submittedTrans+ ': ' +fi.Date_submitted__c + advName+ ')';
            console.log('in loop: fi.title', fi.title);
        }
        this.dataLoaded = true;
    }
}