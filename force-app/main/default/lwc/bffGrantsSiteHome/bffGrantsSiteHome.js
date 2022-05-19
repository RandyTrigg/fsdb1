import { LightningElement } from 'lwc';
import getProfileSummary from '@salesforce/apex/SiteController.getProfileSummary';
import formInstIdOfNewProposal from '@salesforce/apex/SiteController.formInstIdOfNewProposal';
import logoResource from '@salesforce/resourceUrl/BFFLogoGrantsSite';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';
import { showUIError } from 'c/lwcUtilities';
import Id from '@salesforce/user/Id';
import getTranslations from '@salesforce/apex/FormPhraseController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';

export default class BffGrantsSiteHome extends NavigationMixin(LightningElement) {
    userId = Id;

    // Logos and text on page
    debug;
    bffLogo = logoResource;
    bffLogoWhiteText = logoResourceWhiteText;
    logout; // When logout & support translated in markup, page throws a null error on 'options.' Maybe because they are being passed as attributes?
    support;
    newAppSustainFund;
    newAppSolidarityFund;
    showMenu = false;
    errMsg;
    expandGrants = "Grants";

    showReadMore = false;
    accordLabel;

    // Translations
    transInfo;
    langMap;
    langTag;
    language;
    transByName;
    transByNameObj;

    // Profile data
    profileSummary;
    prfId;
    hasSubmittedPrf = true;
    prFormInstanceId;
    dataLoaded = false;

    // Proposals list
    hasProposals;
    prpList;
    prpItemsData;
    columns;
    viewColumns;
    editColumns;
    hasPendingSolidarity = false;
    hasPendingSustain = false;
    recentSolidarityCriteria = 182; // days equivalent to 6 months
    recentSustainCriteria = 730; // days equivalent to 2 years - setting this to be conservative
    hasRecentSubmittedSolidarity = false;
    hasRecentSubmittedSustain = false;
    grantType;
    appFormInstanceId;
    appNames = ['bff_SustainApplication', 'bff_SolidarityApplication'];
    prpFormInst;
    formInstList;

    
    connectedCallback() {
        if (this.userId) {
            this.loadData();
        }
    }

    async loadData() {
        try {
            console.log('loadData');
            // Retrieve/create Profile and Form Instance, along with translations
            let [data, translations ] = await Promise.all ([
                getProfileSummary(),
                getTranslations()
            ]);
            this.profileSummary = JSON.parse(data);
            this.language = this.profileSummary.language;
            this.transInfo = JSON.parse(translations);
            // Proposals table
            this.hasSubmittedPrf = this.profileSummary.hasSubmittedPrf;
            if (this.hasSubmittedPrf) this.expandGrants = '';
            this.showReadMore = this.expandGrants == 'Grants' ? false : true;
            this.setLangPickerDefault();
            this.translatePage();
            this.dataLoaded = true;
        } catch (error) {
            handleError(error);
        }
    }

    translatePage(){
        this.transByName = buildTransByName(this.transInfo, this.language);
        this.transByNameObj = Object.fromEntries(this.transByName);
        this.logout = this.transByName.get('Logout');
        this.support = this.transByName.get('Support');
        let newApp = this.transByName.get('NewApplication');
        this.newAppSustainFund = newApp + ': ' + this.transByName.get('bff_SustainFund');
        this.newAppSolidarityFund = newApp + ': ' + this.transByName.get('bff_SolidarityFund');
        let readMoreTag = this.showReadMore ? ' (' + this.transByNameObj.ReadMore + ')' : '';
        this.accordLabel = this.transByNameObj.bff_GrantsSiteLandingTitle + readMoreTag;
    
        this.prFormInstanceId = this.profileSummary.prFormInstanceId;
        this.prfId = this.profileSummary.prId;
        this.prpList = this.profileSummary.prpList;
        this.formInstList = this.profileSummary.formInstList;
        this.hasProposals = this.profileSummary.hasProposals;
        this.prpItemsData = this.processPrpList(this.prpList);
        this.processFormInstList(this.formInstList);
    
    
    }
    
    setLangPickerDefault(){
        const langPicker = this.template.querySelector('[name="langPicker"]');
        langPicker.selectedIndex = [...langPicker.options].findIndex(option => option.value === this.language);
        const lMap = new Map();
        lMap.set('English', 'en');
        lMap.set('Spanish', 'sp');
        lMap.set('French', 'fr');
        this.langMap = lMap;
        this.langTag = this.langMap.get(this.language);
    }

    handleLanguagePicker(event){
        this.language = event.target.value;
        this.translatePage();
    }

    get options() {
        return [
                 { label: 'English', value: 'English' },
                 { label: 'Español', value: 'Spanish' },
                 { label: 'Français', value: 'French' },
                 { label: 'Português', value: 'Portuguese' }
               ];
    }

    get disableButton(){
        return!(this.hasSubmittedPrf);
    }

    handleSectionToggle(event) {
        console.log('showReadMore before', this.showReadMore);
        this.expandGrants = this.expandGrants == 'Grants' ? '' : 'Grants';
        this.showReadMore = this.expandGrants == 'Grants' ? false : true;
        let readMoreTag = this.showReadMore ? ' (' + this.transByNameObj.ReadMore + ')' : '';
        this.accordLabel = this.transByNameObj.bff_GrantsSiteLandingTitle + readMoreTag;
        console.log('showReadMore after: ', this.showReadMore);
    }

    /*
    handleReadMore(event) {
        this.expandGrants = 'Grants';
        // this.showReadMore = false;
    } */
    
    /***** Navigation and button handling *****/ 
    
    handleMenuSelect () {
        this.showMenu = !this.showMenu;
    }

    handleLogout(){
        this[NavigationMixin.Navigate]({
            type: 'comm__loginPage',
            attributes: {
              actionName: 'logout'
            }
          });
    }

    handleNewProfile() {
        this.navigateToFormInstance(this.prFormInstanceId);
    }

    handleNewAppSustain(event) {
        if (this.hasPendingSustain) {
            this.errMsg = 'You have a Sustain Fund grant application in progress';
            this.debug = 'Pending sustain';
            this.displayAppError();
        } else if (this.hasRecentSubmittedSolidarity) {
            this.errMsg = 'You have already submitted a Sustain Fund grant application';
            this.displayAppError();
        } else {
            // Create Proposal with grant type and Form Instance linked to Proposal
            // Prep error message in case of issue.
            this.errMsg = 'A system error occurred: ID' + event.target.dataset.name + '. Please contact support.';
            this.grantType = 'BFF-Sustain';
            this.createProposalWithFormInstanceAndNavigate(this.grantType);
        }
    }

    handleNewAppSolidarity(event) {
        if (this.hasPendingSolidarity) {
            // Toast message: pending message
            this.errMsg = 'You have a Solidarity Fund grant application in progress';
            this.displayAppError();
        } else if (this.hasRecentSubmittedSolidarity) {
            // Toast message: submitted message
            this.errMsg = 'You have already submitted a Solidarity Fund grant application';
            this.displayAppError();
        } else {
            // Create Proposal with grant type and Form Instance linked to Proposal
            // Prep error message in case of issue.
            this.errMsg = 'A system error occurred: ID' + event.target.dataset.name + '. Please contact support.';
            this.grantType = 'BFF-Solidarity';
            this.createProposalWithFormInstanceAndNavigate(this.grantType);
        }
    }

    displayAppError() {
        let appError = {
            title: 'Invalid action',
            variant: 'warning',
            mode: 'dismissible',
            userMessage: this.errMsg
        };
        showUIError(appError);
    }

    async createProposalWithFormInstanceAndNavigate(grantType) {
        try {
            this.appFormInstanceId = await formInstIdOfNewProposal( { prfId: this.prfId, grantType: this.grantType } );
            if (!this.appFormInstanceId) {
                // Put up error.
                this.displayAppError();
            } else {
                this.navigateToFormInstance(this.appFormInstanceId);
            }
        } catch (error) {
            handleError(error);
        }
    }

    navigateToFormInstance(formInstId) {
        // Navigate to form instance detail page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'FormInstance__c'
            },
            state: {
                recordId: formInstId,
                language: this.language
            }
        });
    }


    /***** Process FormInstances and Proposals for Proposal Table *****/
    processFormInstList(itemsList) {
        let mapIds = new Map();
        for (let itm of itemsList) {
            if (itm.Proposal__c!=null && this.appNames.includes(itm.Form_name__c)) {
                mapIds.set(itm.Proposal__c, itm.Id);
                console.log('PropId ', itm.Proposal__c);
            }
        }
        this.prpFormInst = mapIds;
    }

    processPrpList(itemsList) {
        let returnList = [];
        for (let itm of itemsList) {
            if (itm.Grant_type__c=='BFF-Solidarity') {
                itm.grantType = this.transByName.get('bff_SolidarityFund');
            } else if (itm.Grant_type__c=='BFF-Sustain') {
                itm.grantType = this.transByName.get('bff_SustainFund');
            }
            itm.proposalName = itm.Name;
            itm.dateReceived = itm.Date_received__c;
            itm.dateCreated = itm.CreatedDate;
            // let statusForTrans = itm.Status_external__c;
            // itm.status = this.transByNameObj.statusForTrans; // itm.Status_external__c; // this.TransByName.get(itm.Status_external__c);
            itm.rowIcon = itm.Status_external__c == 'Pending' ? "utility:edit" : "utility:preview";
            switch (itm.Status_external__c) {
                case 'Pending':
                    itm.statusSortBy = 0;
                    itm.status = this.transByNameObj.Pending;
                    break;
                case 'Submitted':
                    itm.statusSortBy = 1;
                    itm.status = this.transByNameObj.Submitted;
                    break;
                case 'Awarded':
                    itm.statusSortBy = 2;
                    itm.status = this.transByNameObj.Awarded;
                    break;
                case 'Closed':
                    itm.statusSortBy = 3;
                    itm.status = this.transByNameObj.Closed;
                    break;
                case 'Withdrawn':
                    itm.statusSortBy = 4;
                    itm.status = this.transByNameObj.Withdrawn;
                    break;
                case 'Declined':
                    itm.statusSortBy = 5;
                    itm.status = this.transByNameObj.Declined;
                    break;
            }
            returnList.push(itm);
            if (itm.Status_external__c==='Pending') {
                if (itm.Grant_type__c=='BFF-Solidarity') {
                    this.hasPendingSolidarity = true;
                } else if (itm.Grant_type__c=='BFF-Sustain') {
                    this.hasPendingSustain = true;
                } 
            } else if (itm.Status_external__c==='Submitted') {
                if (itm.Grant_type__c=='BFF-Solidarity'
                /* figure out how to parse this: 
                && Sum(itm.dateReceived, this.recentSolidarityCriteria) > today() */) {
                    this.hasRecentSubmittedSolidarity = true;
                } else if (itm.Grant_type__c=='BFF-Sustain') {
                    this.hasRecentSubmittedSustain = true;
                } 
            }
        }
        this.columns = [
            { label: this.transByNameObj.Action, type: 'button-icon', initialWidth: 75, typeAttributes: 
                {iconName: { fieldName: 'rowIcon' }, title: 'Go to application', variant: 'bare', alternativeText: 'Go to application' } },
            { label: this.transByNameObj.Number, initialWidth: 125, fieldName: 'proposalName', hideDefaultActions: true, sortable: false,},
            { label: this.transByNameObj.Status, initialWidth: 125, fieldName: 'status', hideDefaultActions: true, sortable: false,},
            { label: this.transByNameObj.Type, fieldName: 'grantType', hideDefaultActions: true, sortable: false,},
            { label: this.transByNameObj.DateCreated, fieldName: 'dateCreated', type: 'date', hideDefaultActions: true, sortable: false,},
            { label: this.transByNameObj.DateSubmitted, fieldName: 'dateReceived', type: 'date', hideDefaultActions: true, sortable: false,},
        ];
        this.debug = 'Pending sustain?' + this.hasPendingSustain;
        return returnList;
    }

    handleRowAction(event) {
        // Look up app Form Instance Id for Proposal
        const row = event.detail.row;
        // this.errMsg = 'Error: ' + row.Id;
        this.appFormInstanceId = this.prpFormInst.get(row.Id);
        this.navigateToFormInstance(this.appFormInstanceId);
    }

/* Navigation home - not needed in home page itself
    navigateHome() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Home'
            }
        });
    }
*/

    /* Navigation to standard record page; not in use.
    navigateToForm() {
        // Navigate to form instance detail page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.prFormInstanceId,
                actionName: 'edit',
                objectApiName: 'Form_Instance__c'
            },
            state: {
                language: this.language
            }
        });
    } 
    */

}