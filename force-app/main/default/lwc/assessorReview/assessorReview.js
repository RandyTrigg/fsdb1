import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

// Apex methods
import getAssessmentReview from '@salesforce/apex/AssessorSiteController.getAssessmentReview';
import { handleError } from 'c/lwcUtilities';

export default class AssessorReview extends NavigationMixin ( LightningElement ){
    @api recordId;
    assessmentReview = {};
    dataLoaded = false;
    title;
    formsOnly;
    currentUrlLabel;
    parentUrl;
    parentURLLabel;


    connectedCallback() {
        if (this.recordId) {
            this.loadData();
        } 
    }

    async loadData() {
        try {
            this.homeUrl = 'https://'+window.location.host;
            let assessmentReview = JSON.parse(await getAssessmentReview({assessmentId: this.recordId}));
            Object.assign(this.assessmentReview, assessmentReview);
            if (this.assessmentReview.type==='Grantee Report') {
                this.currentUrlLabel = this.assessmentReview.linkedGranteeReport.Name;
                this.parentURLLabel = 'Grantee Report Reviews';
                this.assessmentReview.isGranteeReport = true;
            } else if (this.assessmentReview.type==='Profile') {
                this.currentUrlLabel = this.assessmentReview.linkedProfile.Name;
                this.parentURLLabel = 'Profile Reviews';
                this.assessmentReview.isProfile = true;
            } else if (this.assessmentReview.type==='Proposal') {
                this.currentUrlLabel = this.assessmentReview.linkedProposal.Name;
                this.parentURLLabel = 'Proposal Reviews';
                this.assessmentReview.isProposal = true;
            }

            if (this.assessmentReview.reviewFormId) {
                this.formsOnly = false;
            } else {
                this.formsOnly = true;
            }
            this.dataLoaded = true;
        } catch (error) {
            handleError(error);
        }
        
    }

    navigateHome() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Home'
            }
        });
    }

    navigateToParent() {
        let pageName;
        if (this.assessmentReview.isGranteeReport) {
            pageName = 'GranteeReportReviews__c';
            objectName = 'Grantee_Report__c';
        } else if (this.assessmentReview.isProposal) {
            pageName = 'ProposalReviews__c';
            objectName = 'Proposal__c';
        } else if (this.assessmentReview.isProfile) {
            pageName = 'ProfileReviews__c';
            objectName = 'Profile__c';
        }

        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: pageName
            }
        });
    }

    selfClick() {
        //No nav needed
    }

}