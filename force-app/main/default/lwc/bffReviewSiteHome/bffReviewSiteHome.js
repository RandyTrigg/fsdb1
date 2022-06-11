import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';
import { showUIError } from 'c/lwcUtilities';
import Id from '@salesforce/user/Id';
import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';
import loadAdvisorSummary from '@salesforce/apex/SiteController.loadAdvisorSummary';
import loadAdvisorRecords from '@salesforce/apex/SiteController.loadAdvisorRecords';

export default class BffReviewSiteHome extends NavigationMixin(LightningElement) {
    userId = Id;

    // Logos and text on page that needs to get loaded first 
    debug;
    logout; // When logout & support translated in markup, page throws a null error on 'options.' Maybe because they are being passed as attributes?
    support;
    languageSelector;
    loading = "Loading";
    bffLogoAltText;
    showMenu = false;
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
    transData;

    // Advisor and assessment info
    advisorSummary;
    advisorFormInstanceId;

    // For table
    currentPageReference;
    pendingLabel = 'Pending Evaluations';
    submittedLabel = 'Submitted Evaluations';
    pageLabel =  'Evaluations';
    pageName = 'Ratings__c'; // UPDATE PAGE NAME  
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
                loadAdvisorSummary(),
                loadAdvisorRecords(),
                getTranslations()
            ]);
            console.log('data and translations fetched');
            this.advisorSummary = JSON.parse(advsummary);
            this.language = this.advisorSummary.preferredLanguage;
            this.advisorFormInstanceId = this.advisorSummary.advInfoFormInstanceId;
            console.log(this.advisorFormInstanceId);
            this.transInfo = JSON.parse(translations);
            

            // Added transData to try to successfully pass to header -- but not working.
            // this.transData = translations;
            // this.transInfo = JSON.parse(translations);
            
            // this.template.querySelector('c-bff-review-site-header').transData = this.transData;
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

            // this.setLangPickerDefault();
            this.dataLoaded = true;
            this.showHeader = true;
            this.showSpinner = false;
            console.log('dataloaded');
            
        } catch (error) {
            handleError(error);
        }
    }

    translatePage(){
        this.transByName = buildTransByName(this.transInfo, this.language);
        this.transByNameObj = Object.fromEntries(this.transByName);
        this.logout = this.transByName.get('Logout');
        this.support = this.transByName.get('Support');
        this.loading = this.transByName.get('Loading');
        this.bffLogoAltText = this.transByName.get('BFFLogo');
        this.languageSelector = this.transByName.get('LanguageSelector');
        console.log(this.transByName.get('Logout'));


        /*
        this.prFormInstanceId = this.profileSummary.prFormInstanceId;
        this.prfId = this.profileSummary.prId;
        this.prpList = this.profileSummary.prpList;
        this.formInstList = this.profileSummary.formInstList;
        this.hasProposals = this.profileSummary.hasProposals;
        this.processFormInstList(this.formInstList);
        this.prpItemsData = this.processPrpList(this.prpList);
        */
    }

    setLangPickerDefault(){
        const langPicker = this.template.querySelector('[name="langPicker"]');
        langPicker.selectedIndex = [...langPicker.options].findIndex(option => option.value === this.language);
        const lMap = new Map();
        lMap.set('English', 'en');
        lMap.set('Spanish', 'es');
        lMap.set('French', 'fr');
        lMap.set('Portuguese', 'pt');
        this.langMap = lMap;
        this.langTag = this.langMap.get(this.language);
    }

    handleLanguagePicker(event){
        // this.language = event.target.value;
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
        let returnLists = {};
        returnLists.pending = [];
        returnLists.submitted = [];
        for (let itm of itemsList) {
            itm.orgName = itm.Proposal__r.Account__r.Name;
            itm.country = itm.Proposal__r.Country__r.Name;
            itm.proposalName = itm.Proposal__r.Name;
            itm.grantType = itm.Proposal__r.Grant_type__c;
            itm.notificationDeadline = itm.Proposal__r.Award_notification_deadline__c;
            itm.dateRecieved = itm.Proposal__r.Date_received__c;
            itm.status = itm.Status_external__c;
            itm.language = itm.Proposal__r.Template_language__c;
            if (itm.status==='Pending') {
                returnLists.pending.push(itm);
            } else if (itm.status==='Submitted') {
                returnLists.submitted.push(itm);
            }
        }
        return returnLists;
    }

    handleRowAction(event) {
        const row = event.detail.row;
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Rating__c' // UPDATE PAGE NAME
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