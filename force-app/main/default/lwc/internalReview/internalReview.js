import { LightningElement, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
// Apex methods
import getInternalReview from '@salesforce/apex/ReviewFormController.getInternalReview';
import { handleError } from 'c/lwcUtilities';
export default class InternalReview  extends NavigationMixin(LightningElement) {
    dataLoaded = false;
    internalReview ={};
    recordId;
    currentPageReference;
    proposalRecordURL;
    milestoneURL;
    profileURL;
    accountURL;
    applicantURL;
    milestoneReceived;

    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        if (this.recordId) {
            this.dataLoaded = false; //if we already had an id, hide the form which may be showing the incorrect form data (cached id)
            this.currentPageReference = currentPageReference;
            this.recordId = this.currentPageReference.state.c__id;
        } else {
            this.currentPageReference = currentPageReference;
            this.recordId = this.currentPageReference.state.c__id;
        }
        console.log('setCurrentPageReference: this.recordId = ' +this.recordId);
    }

    connectedCallback() {
        if (this.recordId) {
            this.loadData(); 
        }
    }

    async loadData() {
        try {
            this.internalReview = {}; //set as empty object, a caching issue is causing this page to occasionally load with cached data
            let review = JSON.parse(await getInternalReview({recordId: this.recordId}));
            Object.assign(this.internalReview, review);
            if (this.internalReview.type=='Milestone') {
                this.internalReview.isMilestone = true;
                if (this.internalReview.dateReceived) {
                    this.milestoneReceived = true;
                } else {
                    this.milestoneReceived = false;
                }
                this.generateMilestoneLink();
                this.generateProposalLink();
            } else if (this.internalReview.type=='Proposal') {
                this.internalReview.isProposal = true;
                this.generateProposalLink();
            } else if ( this.internalReview.type=='Profile') {
                this.internalReview.isProfile = true;
                this.generateProfileLink();
            }
            this.generateAccountLink();
            this.dataLoaded = true;            

        } catch (error) {
            handleError(error);
        }
    }

    generateProposalLink() {
        let recId;
        if (this.internalReview.type=='Milestone') {
            recId = this.internalReview.linkedMilestone.Proposal__r.Id;
        } else if (this.internalReview.type=='Proposal') {
            recId = this.internalReview.linkedProposal.Id;
        }
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recId,
                actionName: 'view',
            },
        }).then(url => {
            this.proposalRecordURL = url;
        });
    }

    generateProfileLink() {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.internalReview.linkedProfile.Id,
                actionName: 'view',
            },
        }).then(url => {
            this.profileURL = url;
        });
    }

    generateMilestoneLink() {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.internalReview.linkedMilestone.Id,
                actionName: 'view',
            },
        }).then(url => {
            this.milestoneURL = url;
        });
    }

    generateAccountLink() {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.internalReview.accountId,
                actionName: 'view',
            },
        }).then(url => {
            this.accountURL = url;
        });
    }
}