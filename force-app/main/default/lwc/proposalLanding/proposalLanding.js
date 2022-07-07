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
    prpName;

    // For forms table
    currentPageReference;
    pendingLabel = 'Pending Forms';
    submittedLabel = 'Submitted Forms';
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
            this.prpName = this.prpSummary.prpName;
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

    translatePage() {
        this.transByName = buildTransByName(this.transInfo, this.language);
        this.transByNameObj = Object.fromEntries(this.transByName);
        this.loading = this.transByNameObj.Loading;
        this.pendingLabel = this.transByNameObj.Pending;
        this.submittedLabel = this.transByNameObj.Submitted;
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
            { label: this.transByNameObj.Type, fieldName: 'formTitle', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.StatusOfForm, fieldName: 'formStatus', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.DateDue, fieldName: 'dateDue', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.DateCreated, fieldName: 'dateCreated', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.DateModified, fieldName: 'dateModified', type: 'date', hideDefaultActions: true, sortable: true,},
        ];

        //Differentiate view and edit lists
        this.viewColumns = columns.slice(0);
        this.editColumns = columns.slice(0);
        this.viewColumns.unshift(viewButton);
        this.editColumns.unshift(editButton);
    }

    updateListInternals(formsList) {
        console.log('updateListInternals');
        let returnLists = {};
        returnLists.pending = [];
        returnLists.submitted = [];
        for (let itm of formsList) {
            console.log('id',itm.Id);
            itm.formTitle = this.transByName.get(itm.Form__r.Form_Phrase_Title__c);
            console.log('formTitle',itm.formTitle);
            itm.formStatus = this.transByName.get(itm.Status__c);
            console.log('status',itm.formStatus);
            itm.dateDue = itm.Date_due__c;
            console.log('dateDue',itm.dateDue);
            itm.dateCreated = itm.Date_created__c;
            console.log('dateCreated',itm.dateCreated);
            itm.dateModified = itm.Last_modified_datetime__c;
            console.log('dateMod',itm.dateModified);
            if (itm.Status__c==='Pending') {
                returnLists.pending.push(itm);
            } else if (itm.Status__c==='Submitted') {
                returnLists.submitted.push(itm);
            }
        }
        console.log('updateListInternalsReturnLists');
        return returnLists;
    }


}