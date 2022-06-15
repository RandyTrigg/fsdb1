import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';
import { showUIError } from 'c/lwcUtilities';
import Id from '@salesforce/user/Id';
import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';
import getAdvisorSummary from '@salesforce/apex/SiteController.getAdvisorSummary';
import loadAdvisorRecords from '@salesforce/apex/SiteController.loadAdvisorRecords';

export default class BffReviewSiteHome extends NavigationMixin(LightningElement) {
    userId = Id;
    debug;
    loading = "Loading";
    errMsg;
    showSpinner = true;
    dataLoaded = false;

    // Translations
    transInfo;
    langMap;
    langTag;
    language;
    transByName;
    transByNameObj;

    // Advisor and assessment info
    advisorSummary;
    advProfileFormInstanceId;

    // For table
    currentPageReference;
    pendingLabel = 'Pending Evaluations';
    submittedLabel = 'Submitted Evaluations';
    pageLabel =  'Evaluations'; 
    objectName = 'Rating';
    activeSections = ['Pending'];
    viewColumns;
    editColumns;
    pendingItemsData;
    submittedItemsData;
    pendingSortedBy;
    pendingSortedDirection;
    submittedSortedBy;
    submittedSortedDirection;
    formData =[];
    isViewForms = false;

    
    connectedCallback() {
        if (this.userId) {
            this.loadData();
        } 
    }

    async loadData() {
        try {
            console.log('loadData');
            // Retrieve Advisor and Form Instance, along with translations
            // let [translations ] = await Promise.all ([
            let [advsummary, list, translations ] = await Promise.all ([
                getAdvisorSummary(),
                loadAdvisorRecords({objectType:this.objectName}),
                getTranslations()
            ]);
            console.log('data and translations fetched');
            this.advisorSummary = JSON.parse(advsummary);
            this.language = this.advisorSummary.preferredLanguage;
            this.advProfileFormInstanceId = this.advisorSummary.advProfileFormInstanceId;
            console.log(this.advProfileFormInstanceId);
            
            // Load translations
            this.transInfo = JSON.parse(translations);
            this.translatePage();

            // For table
            let parsedList = JSON.parse(list);

            //Lightning datatables can't automtically pull out nested values
            let parsedLists = this.updateListInternals(parsedList);
            
            this.pendingItemsData = parsedLists.pending;
            this.submittedItemsData = parsedLists.submitted;
            this.pendingLabel = this.pendingLabel + ' ('+ this.pendingItemsData.length +')';
            this.submittedLabel = this.submittedLabel + ' ('+ this.submittedItemsData.length +')';
    
            let viewButton = {type: 'button-icon', initialWidth: 80, 
                                typeAttributes: {  
                                    iconName: "utility:preview", 
                                    name: "Go To Item",  
                                    variant: 'bare',
                                    alternativeText: "Go To Item",       
                                    disabled: false
                                }
                            };
            let editButton = {type: 'button-icon', initialWidth: 80, 
                typeAttributes: {  
                    iconName: "utility:edit", 
                    name: "Go To Item",  
                    variant: 'bare',
                    alternativeText: "Go To Item",       
                    disabled: false
                }
            };
    
            let columns = [
                { label: 'Org Name', fieldName: 'orgName', hideDefaultActions: true, sortable: true,},
                { label: 'Country', fieldName: 'country', hideDefaultActions: true, sortable: true,},
                { label: 'Proposal Name', fieldName: 'proposalName', hideDefaultActions: true, sortable: true,},
                { label: 'Grant Type', fieldName: 'grantType', hideDefaultActions: true, sortable: true,},
                { label: 'Award Notification Deadline', fieldName: 'notificationDeadline', type: 'date', hideDefaultActions: true, sortable: true,},
                { label: 'Proposal Date Received', fieldName: 'dateRecieved', type: 'date', hideDefaultActions: true, sortable: true,},
                { label: 'Review Status', fieldName: 'status', hideDefaultActions: true, sortable: true,},
                { label: 'Template Language', fieldName: 'language', hideDefaultActions: true, sortable: true,},
            ];

            //Differentiate view and edit lists
            this.viewColumns = columns.slice(0);
            this.editColumns = columns.slice(0);
            this.viewColumns.unshift(viewButton);
            this.editColumns.unshift(editButton);

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
        this.loading = this.transByName.get('Loading');
    }

    handleLanguagePicker(event){
        console.log('handleLanguagePicker in Home');
        this.language = event.detail;
        console.log(this.language);
        this.translatePage();
    }

    updatePendingColumnSorting(event) {
        var fieldName = event.detail.fieldName;
        var sortDirection = event.detail.sortDirection;
        // assign the latest attribute with the sorted column fieldName and sorted direction
        this.pendingSortedBy = fieldName;
        this.pendingSortedDirection = sortDirection;
        this.pendingItemsData = this.sortData(fieldName, sortDirection, this.pendingItemsData);
    }

    updateSubmittedColumnSorting(event) {
        var fieldName = event.detail.fieldName;
        var sortDirection = event.detail.sortDirection;
        // assign the latest attribute with the sorted column fieldName and sorted direction
        this.submittedSortedBy = fieldName;
        this.submittedSortedDirection = sortDirection;
        this.submittedItemsData = this.sortData(fieldName, sortDirection, this.submittedItemsData);
    }

    updateListInternals(itemsList) {
        console.log('updateListInternals');
        let returnLists = {};
        returnLists.pending = [];
        returnLists.submitted = [];
        for (let itm of itemsList) {
            itm.orgName = itm.Proposal__r.Account__r.Name;
            console.log('orgname',itm.orgName);
            itm.country = itm.Proposal__r.Country__r.Name;
            console.log('country',itm.country);
            itm.proposalName = itm.Proposal__r.Name;
            console.log('propName',itm.proposalName);
            itm.grantType = itm.Proposal__r.Grant_type__c;
            console.log('granttype',itm.grantType);
            itm.notificationDeadline = itm.Proposal__r.Award_notification_deadline__c;
            itm.dateRecieved = itm.Proposal__r.Date_received__c;
            itm.status = itm.Status_external__c;
            console.log('status',itm.status);
            itm.language = itm.Proposal__r.Template_language__c;
            if (itm.status==='Pending') {
                returnLists.pending.push(itm);
            } else if (itm.status==='Submitted') {
                returnLists.submitted.push(itm);
            }
        }
        console.log('updateListInternalsReturnLists');
        return returnLists;
    }

    handleRowAction(event) {
        const row = event.detail.row;
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Assessment__c' // UPDATE PAGE NAME
            },
            state: {
                assessmentId: row.Id,
            }
        });
    }

    sortData(fieldname, direction, sortData) {
        // serialize the data before calling sort function
        let parseData = JSON.parse(JSON.stringify(sortData));

        // Return the value stored in the field
        let keyValue = (a) => {
            return a[fieldname];
        };

        // cheking reverse direction 
        let isReverse = direction === 'asc' ? 1: -1;

        // sorting data 
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : ''; // handling null values
            y = keyValue(y) ? keyValue(y) : '';

            // sorting values based on direction
            return isReverse * ((x > y) - (y > x));
        });

        // set the sorted data to data table data
        return parseData;
    }

}