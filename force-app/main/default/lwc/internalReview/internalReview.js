import { LightningElement, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
// Apex methods
import getInternalReview from '@salesforce/apex/ReviewFormController.getInternalReview';
import getInternalReviewVFPageName from '@salesforce/apex/ReviewFormController.getInternalReviewVFPageName';
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
    messageOrigin;
    pagePath;
    milestoneReceived;

    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        if (this.recordId) {
            this.dataLoaded = false; //if we already had an id, hide the form which may be showing the incorrect form data (cached id)
            this.currentPageReference = currentPageReference;
            this.recordId = this.currentPageReference.state.c__id;
            this.loadData(); 
        } else {
            this.currentPageReference = currentPageReference;
            this.recordId = this.currentPageReference.state.c__id;
            this.loadData();
        }

        
    }

    connectedCallback() {
        //Adds listener for messages from the embedded JS in the VF Form
        console.log('connectedCallback - adding listener');
        window.addEventListener("message", this.handleNotification.bind(this));
    }

    handleNotification(message) {
        console.log('handle notification');
        //The message.orgin URL coming in is still in the old format (https://globalfundforwomen--c.na161.visual.force.com), despite being well past this update: https://releasenotes.docs.salesforce.com/en-us/spring18/release-notes/rn_vf_instance_names_removed.htm
        //we'll only verify the base URL for that reson
        console.log('message.origin');
        console.log(message.origin);

        this.messageOrigin = String(message.origin);

        //Prod Origin https://globalfundforwomen--c.na161.visual.force.com
        //SB Origin https://globalfundforwomen--bulkemail--c.visualforce.com
        if (this.messageOrigin.startsWith("https://globalfundforwomen")) {
            console.log('origin match, send id');
            this.sendRecordId();   
        }
    }


    async loadData() {
        try {
            this.internalReview = {}; //set as empty object, a caching issue is causing this page to occasionally load with cached data
            let review = JSON.parse(await getInternalReview({recordId: this.recordId}));
            let pageName = await getInternalReviewVFPageName();
            this.pagePath = "/apex/"+pageName;
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

    sendRecordId() {
        //in rare cases, the queryselector is getting this error:  [this.template.querySelector(...).contentWindow is null
        //Adding a timer to retry once after a 1 second wait
        let iFrame = this.template.querySelector("iframe");
        if (iFrame.contentWindow) {
            iFrame.contentWindow.postMessage(this.recordId, this.messageOrigin); 
        }
    }
}