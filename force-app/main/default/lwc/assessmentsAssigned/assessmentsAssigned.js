import { LightningElement} from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import getAssignedAssessments from '@salesforce/apex/AssessorSiteController.getAssignedAssessments';

const columns = [
    {type: 'button-icon', initialWidth: 80, 
        typeAttributes: {  
            iconName: {fieldName: 'iconName'},
            label: {fieldName: 'iconHelp'},  
            name: {fieldName: 'iconHelp'},  
            variant: 'bare',
            alternativeText: {fieldName: 'iconHelp'},       
            disabled: false
        }
    },
    { label: 'Name', fieldName: 'Name'},
    { label: 'Org Name', fieldName: 'accountName'},
    { label: 'Status', fieldName: 'Status_external__c'},
    { label: 'Type', fieldName: 'type'},
    { label: 'Report Name', fieldName: 'reportName'},
    { label: 'Report Date Received', fieldName: 'dateReceived', type:'date'},
    { label: 'Report Priority', fieldName: 'priority'},
    { label: 'Country', fieldName: 'country'},
    
];

export default class AssessmentsAssigned extends NavigationMixin ( LightningElement ) {
    subscription = null;
    reviewerName; 
    columns = columns;
    mutableRecords;

    connectedCallback() {
        console.log('connectedCallback');
        this.loadData();
    }

    async loadData() {
        console.log('loadData');
        let assessments = await getAssignedAssessments();
        console.log('assessments');
        if (assessments) {
            console.log('assessments');
            console.log(assessments);
            // Object.assign(this.mutableRecords, assessments);
            this.mutableRecords = JSON.parse(JSON.stringify(assessments));
            console.log('this.mutableRecords');
            console.log(this.mutableRecords);
            for (let rec of this.mutableRecords) {
                this.reviewerName = rec.Advisor__r.Name;
                if (rec.Grantee_Report__c) {
                    rec.type = 'Grantee Report Review';
                    rec.accountName = rec.Grantee_Report__r.Account_name__c;
                    rec.reportName = rec.Grantee_Report__r.Name;
                    rec.dateReceived = rec.Grantee_Report__r.Date_received__c;
                    rec.priority = rec.Grantee_Report__r.Review_priority__c;
                    rec.country = rec.Grantee_Report__r.Country_name__c;
                    if (rec.Date_submitted__c || rec.Grantee_Report__r.Date_review_completed__c) {
                        rec.isReadOnly = true;
                    }
                } else if (rec.Profile__c) {
                    rec.type = 'Profile Review';
                    if (!rec.Profile__r.Account__c) {
                        rec.accountName = rec.Profile__r.Applicant_name__c;
                    } else {
                        rec.accountName = rec.Profile__r.Account__r.Name;
                    }
                    if (rec.Date_submitted__c || rec.Profile__r.Date_review_completed__c) {
                        rec.isReadOnly = true;
                    }
                } else {
                    rec.type = 'Proposal Review';
                    rec.accountName = rec.Proposal__r.Account__r.Name;
                    if (rec.Date_submitted__c || rec.Proposal__r.Date_review_completed__c) {
                        rec.isReadOnly = true;
                    }
                }
                console.log('rec.isReadOnly');
                console.log(rec.isReadOnly);
                rec.AssessmentURL = '/'+rec.Id;
                if (rec.isReadOnly) {
                    rec.iconName = 'action:preview';
                    rec.iconHelp = 'View';
                } else {
                    rec.iconName = 'action:edit'
                    rec.iconHelp = 'Edit';
                }
                console.log('rec');
                console.log(rec);
            }
        } else if (error) {
            console.log('error');
            console.log(error);
            // this.error = error;
            // this.record = undefined;
        }
    }


    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        let goToAssessment = true; //need logic for when to skipt to the Form Instance page/component

        if (goToAssessment) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.Id,
                    objectApiName: 'Assessment__c',
                    actionName: 'view'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'FormInstance__c'
                },
                state: {
                    formInstanceId: "a2W2i000000O385EAC",
                }
            });
        }

    }
   
}