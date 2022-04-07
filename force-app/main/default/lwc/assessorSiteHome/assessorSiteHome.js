import { LightningElement } from 'lwc';
import getInterfaceType from '@salesforce/apex/AssessorSiteController.getInterfaceType';

export default class AssessorSiteHome extends LightningElement {
    isAssessmentView = false;
    isInvitesView = false;

    async connectedCallback() {
        let type = await getInterfaceType();
        if (type==='assessments') {
            this.isAssessmentView = true;
        } else if (type==='invites') {
            this.isInvitesView = true;
        }
    }


}