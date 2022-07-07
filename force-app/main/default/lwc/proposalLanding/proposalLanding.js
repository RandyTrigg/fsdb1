


import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';
import { showUIError } from 'c/lwcUtilities';
import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';
import getProposalSummary from '@salesforce/apex/SiteController.getProposalSummary';

export default class ProposalLanding extends NavigationMixin(LightningElement) {
    // Translations
    transInfo;
    langMap;
    langTag;
    language;
    transByName;
    transByNameObj;
    transData;

    // Proposal info and related letters and forms
    prpSummary;
    letters;
    forms;

    // For forms table
    currentPageReference;
    pendingLabel = 'Pending Reviews';
    submittedLabel = 'Submitted Reviews';
    hidePendingTable = false;
    activeSections = ['Pending'];
    viewColumns;
    editColumns;
    pendingFormsData;
    submittedFormsData;
    pendingSortedBy;
    pendingSortedDirection;
    submittedSortedBy;
    submittedSortedDirection;

    connectedCallback() {
        if (this.language) {
            this.loadData();
        } 
    }

    async loadData() {
        try {
            console.log('loadData');
            // Retrieve Advisor and Form Instance, along with translations
            let [prpsummary, translations ] = await Promise.all ([
                getProposalSummary(),
                getTranslations()
            ]);
            console.log('data and translations fetched');
            this.prpSummary = JSON.parse(prpsummary);
            // TO DO: Check language handling
            console.log(this.prpSummary);
            
            // Load translations
            this.transInfo = JSON.parse(translations);
            this.translatePage();

            // For table
            this.buildFormTables();

            // Tie up ends for data loading
            this.dataLoaded = true;
            this.showHeader = true;
            this.showSpinner = false;
            console.log('dataloaded');
            
        } catch (error) {
            handleError(error);
        }
    }

    buildFormTables() {
        let parsedList = JSON.parse(this.prpSummary.FormInstanceList);
        //Lightning datatables can't automtically pull out nested values
        let parsedLists = this.updateListInternals(parsedList);
        this.pendingFormsData = parsedLists.pending;
        this.submittedFormsData = parsedLists.submitted;
        this.hidePendingTable = this.pendingFormsData.length === 0 ? true : false;
        this.pendingLabel = this.pendingLabel + ' ('+ this.pendingFormsData.length +')';
        this.submittedLabel = this.submittedLabel + ' ('+ this.submittedFormsData.length +')';

        let viewButton = {type: 'button-icon', initialWidth: 80, 
                            typeAttributes: {  
                                iconName: "utility:preview", 
                                name: this.transByNameObj.View,  
                                variant: 'bare',
                                alternativeText: this.transByNameObj.View,       
                                disabled: false
                            }
                        };
        let editButton = {type: 'button-icon', initialWidth: 80, 
            typeAttributes: {  
                iconName: "utility:edit", 
                name: this.transByNameObj.Edit,  
                variant: 'bare',
                alternativeText: this.transByNameObj.Edit,       
                disabled: false
            }
        };

        let columns = [
            { label: this.transByNameObj.OrganizationName, fieldName: 'orgName', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.Country, fieldName: 'country', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.ProposalNumber, fieldName: 'proposalName', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.GrantType, fieldName: 'grantType', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.AwardNotificationDeadline, fieldName: 'notificationDeadline', type: 'date', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.ProposalDateReceived, fieldName: 'dateRecieved', type: 'date', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.ReviewStatus, fieldName: 'status', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.TemplateLanguage, fieldName: 'language', hideDefaultActions: true, sortable: true,},
        ];

        //Differentiate view and edit lists
        this.viewColumns = columns.slice(0);
        this.editColumns = columns.slice(0);
        this.viewColumns.unshift(viewButton);
        this.editColumns.unshift(editButton);
    }


}