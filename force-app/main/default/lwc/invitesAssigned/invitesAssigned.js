import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';

import getAssignedInvites from '@salesforce/apex/AssessorSiteController.getAssignedInvites';

const columns = [
    {type: 'button-icon', initialWidth: 80, 
    typeAttributes: {  
        iconName: {fieldName: 'iconName'},
        label: {fieldName: 'iconHelp'},  
        name: {fieldName: 'iconHelp'},  
        variant: 'bare',
        alternativeText: {fieldName: 'iconHelp'},       
        disabled: false
    }},
    { label: 'Group Name', fieldName: 'AccountName', initialWidth: 250},
    { label: 'Status', fieldName: 'Status__c', initialWidth: 150},
    { label: 'Invite Date', fieldName: 'CreatedDate', type: 'date', initialWidth: 125},
    { label: 'Comments', fieldName: 'Comments__c'},
    { label: 'Has Proposal', fieldName: 'hasProposal', type : 'boolean', initialWidth: 100},
    { label: 'Has Profile', fieldName: 'hasProfile', type : 'boolean', initialWidth: 100},
    
];


export default class InvitesAssigned extends NavigationMixin ( LightningElement ) {
    columns = columns;
    inviteList;

    async connectedCallback() {
        try {
            let invites = await getAssignedInvites();

            if (invites) {
                this.inviteList = JSON.parse(invites);
                
    
                for (let invite of this.inviteList) {
                    invite.AccountName = invite.Account__r.Name;
                    if (invite.Proposal__c) {
                        invite.hasProposal = true;
                    } else {
                        invite.hasProposal = false;
                    }
                    if (invite.Profile__c) {
                        invite.hasProfile = true;
                    } else {
                        invite.hasProfile = false;
                    }
    
                    invite.iconName = 'action:preview';
                    invite.iconHelp = 'View';
                }
    
                console.log('this.inviteList');
                console.log(this.inviteList);
    
    
            }
        } catch (error) {
            handleError(error);
        }
        
    }

    handleRowAction(event) {
        const row = event.detail.row;

        console.log('row.Id');
        console.log(row.Id);

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: row.Id,
                objectApiName: 'Invite__c',
                actionName: 'view'
            }
        });
    }

}