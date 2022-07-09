import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';
import { showUIError } from 'c/lwcUtilities';
import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';
import getProposalSummary from '@salesforce/apex/SiteController.getProposalSummary';

export default class ProposalLanding extends NavigationMixin(LightningElement) {
    
    // TO DO: Figure out whether to grab this in header js, grab again here, or ditch altogether from landing page.
    advProfileFormInstanceId;

    @api recordId;
    dataLoaded = true;
    showHeader = true;
    showSpinner = true;
    loading = 'loading';
    
    // Translations
    transInfo;
    langMap;
    langTag;
    @api language = 'English';
    transByName;
    @api transByNameObj;
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
    columns;
    pendingFormsData;
    submittedFormsData;

    connectedCallback() {
        this.loadData();
    }

    // Get parameters from current URL (e.g. language)
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            let urlStateParameters = currentPageReference.state;
            console.log('wire CurrentPageReference: urlStateParameters', urlStateParameters);
            this.language = urlStateParameters.lang || 'English';
            if(!this.recordId) this.recordId = urlStateParameters.recordId || null;
            console.log('wire CurrentPageReference: this.recordId', this.recordId);
        }
    }

    async loadData() {
        try {
            console.log('loadData');
            // Retrieve Proposal related records and translations
            let [prpsummary, translations ] = await Promise.all ([
                getProposalSummary({ propId: this.recordId }),
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
        let parsedList = JSON.parse(this.prpSummary.forms);
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

        this.columns = [
            { label: this.transByNameObj.Action, type: 'button-icon', initialWidth: 75, typeAttributes: 
                {iconName: { fieldName: 'rowIcon' }, title: { fieldName: 'rowAction' }, variant: 'bare', alternativeText: { fieldName: 'rowAction' } } },
            { label: this.transByNameObj.Type, fieldName: 'formTitle', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.StatusOfForm, fieldName: 'formStatus', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.DateDue, fieldName: 'dateDue', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.DateCreated, fieldName: 'dateCreated', hideDefaultActions: true, sortable: true,},
            { label: this.transByNameObj.DateModified, fieldName: 'dateModified', type: 'date', hideDefaultActions: true, sortable: true,},
        ];
    }

    updateListInternals(formsList) {
        console.log('updateListInternals');
        let returnLists = {};
        returnLists.pending = [];
        returnLists.submitted = [];
        for (let itm of formsList) {
            console.log('id',itm.Id);
            itm.rowIcon = itm.Status__c==='Submitted' ? "utility:preview" : "utility:edit";
            itm.rowAction = itm.Status__c==='Submitted' ? this.transByNameObj.View : this.transByNameObj.Edit;
            itm.formTitle = this.transByName.get(itm.Form__r.Form_Phrase_Title__r.Name);
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


    handleRowAction(event) {
        const row = event.detail.row;
        console.log('handlerowaction rowid', row.Id);
        this.navigateToFormInstance(row.Id);

    }

    navigateToFormInstance(formInstId) {
        // Navigate to form instance detail page
        console.log('forminstid ', formInstId);
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'FormInstance__c'
            },
            state: {
                recordId: formInstId,
                lang: this.language
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