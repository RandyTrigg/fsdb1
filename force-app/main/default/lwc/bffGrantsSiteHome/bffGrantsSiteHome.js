import { LightningElement } from 'lwc';

import getProfileSummary from '@salesforce/apex/ProfileController.getProfileSummary';
import getTranslations from '@salesforce/apex/FormPhraseController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';

export default class BffGrantsSiteHome extends LightningElement {
    // Copied from AdvisorLanding
    pageSubheader;
    grTitle;
    propTitle;
    profTitle;

    formsTitle;
    grSubtitle;
    propSubtitle;
    profileSubtitle;

    profileSummary;
    dataLoaded = false;
    
    
    async connectedCallback() {
        try {
            this.profileSummary = JSON.parse(await getProfileSummary());

            if (this.advisorSummary.proposalReviewsAssigned.length<1) {
                 this.advisorSummary.proposalReviewsAssigned = null;
            }

            this.grTitle = 'Review Grantee Reports (' + this.advisorSummary.pendingGranteeReportsCount + ')';
            this.propTitle = 'Review Proposals (' + this.advisorSummary.pendingProposalsCount + ')';
            this.profTitle = 'Review Profiles (' + this.advisorSummary.pendingProfilesCount + ')';
            this.endorseTitle = 'Make Endorsements (' + this.advisorSummary.pendingEndorsementsCount + ')';
            this.ratingTitle = 'Participatory Grantmaking Evaluations (' + this.advisorSummary.pendingRatingsCount + ')';
            this.formsTitle = 'View Submitted Forms (' + this.advisorSummary.formsCount +')';

            //has at least one priority item
            if (this.advisorSummary.priorityGRCount && this.advisorSummary.priorityGRCount>0) {
                let priorityItemPhrase;
                //>1 priority Item
                if (this.advisorSummary.priorityGRCount>1) {
                    priorityItemPhrase = 'You have '+this.advisorSummary.totalPriorityItems + ' priority item(s)';
                //1 priority item
                } else {
                    priorityItemPhrase = 'You have '+this.advisorSummary.totalPriorityItems + ' priority item';
                }
                //no pending items
                if (!this.advisorSummary.totalPendingItems || this.advisorSummary.totalPendingItems==0) {
                    this.pageSubheader = priorityItemPhrase;
                }
                //more than one pending
                else if (this.advisorSummary.totalPendingItems>1) {
                    this.pageSubheader = priorityItemPhrase + ' and ' + this.advisorSummary.totalPendingItems + ' total pending item(s)'
                //one pending
                } else {
                    this.pageSubheader = priorityItemPhrase + ' and ' + this.advisorSummary.totalPendingItems + ' pending item'
                }
            //No priority Items
            } else {
                //No pending Items
                if (!this.advisorSummary.totalPendingItems || this.advisorSummary.totalPendingItems==0) {
                    this.pageSubheader = 'You do not have any pending items';
                }
                //1 pending item
                else if (this.advisorSummary.totalPendingItems==1) {
                    this.pageSubheader = 'You have ' + this.advisorSummary.totalPendingItems + ' pending item';
                //More than one pending item
                } else if (this.advisorSummary.totalPendingItems>1) {
                    this.pageSubheader = 'You have ' + this.advisorSummary.totalPendingItems + ' total pending item(s)';
                }
            }
            this.dataLoaded = true;
        } catch (error) {
            handleError(error);
        }
        
    }












}