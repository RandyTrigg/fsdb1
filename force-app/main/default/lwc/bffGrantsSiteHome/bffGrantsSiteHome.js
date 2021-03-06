import { LightningElement } from 'lwc';
import getProfileSummary from '@salesforce/apex/SiteController.getProfileSummary';
import formInstIdOfNewProposal from '@salesforce/apex/SiteController.formInstIdOfNewProposal';
import logoResource from '@salesforce/resourceUrl/BFFLogoGrantsSite';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin } from 'lightning/navigation';
import { handleError, showUIError, langTag } from 'c/lwcUtilities';
// import { showUIError } from 'c/lwcUtilities';
import Id from '@salesforce/user/Id';
import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';

export default class BffGrantsSiteHome extends NavigationMixin(LightningElement) {
    userId = Id;

    // Logos and text on page that needs to get loaded first 
    debug;
    bffLogo = logoResource;
    bffLogoWhiteText = logoResourceWhiteText;
    logout; // When logout & support translated in markup, page throws a null error on 'options.' Maybe because they are being passed as attributes?
    support;
    languageSelector;
    loading;
    bffLogoAltText;
    newAppSustainFund;
    newAppSolidarityFund;
    showMenu = false;
    errMsg;
    expandGrants = "Grants";
    showReadMore = false;
    readMoreTag;
    accordLabel;
    showSpinner = true;
    propInProcess = false;

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
    sustainDeadlineDate = new Date('2022-08-02T00:00:00-07:00'); // End of day 8/1/22 in Pacific timezone
    recentSolidarityCriteria = 182; // days equivalent to 6 months
    recentSustainCriteria = 730; // days equivalent to 2 years - setting this to be conservative
    hasRecentSubmittedSolidarity = false;
    hasRecentSubmittedSustain = false;
    isRecentGroup = false;
    grantType;
    appFormInstanceId;
    appNames = ['bff_SustainApplication', 'bff_SolidarityApplication'];
    prpFormInst;
    formInstIdSubmitted;
    formInstList;
    currentDate = new Date();
    dateEstablished = new Date();

    
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
            this.dateEstablished = this.profileSummary.prf.Date_org_founded__c;
            if (this.hasSubmittedPrf && (!this.dateEstablished)) {
                return this.reloadData();
            }
            console.log('dateEstablished', this.dateEstablished);
            if (this.hasSubmittedPrf) this.expandGrants = '';
            this.translatePage();
            this.dataLoaded = true;
            this.showSpinner = false;
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
        let newApp = this.transByName.get('NewApplication');
        this.newAppSustainFund = newApp + ': ' + this.transByName.get('bff_SustainFund');
        this.newAppSolidarityFund = newApp + ': ' + this.transByName.get('bff_SolidarityFund');
        this.showReadMore = this.expandGrants == 'Grants' ? false : true;
        this.readMoreTag = this.showReadMore ? ' (' + this.transByNameObj.ReadMore + ')' : '';
        this.accordLabel = this.transByNameObj.bff_GrantsSiteLandingTitle + this.readMoreTag;
        this.prFormInstanceId = this.profileSummary.prFormInstanceId;
        this.prfId = this.profileSummary.prId;
        this.prpList = this.profileSummary.prpList;
        this.formInstList = this.profileSummary.formInstList;
        this.hasProposals = this.profileSummary.hasProposals;
        this.processFormInstList(this.formInstList);
        this.prpItemsData = this.processPrpList(this.prpList);
        this.langTag = langTag(this.language);
        console.log('langTag', this.langTag);
    }

    addDays(date, days) {
        var result = new Date(date);
        result.setDate(result.getDate() + days);
        return result;
    }

    reloadData() {
        this.loadData();
    }

    handleLanguagePicker(event){
        console.log('handleLanguagePicker in Home');
        this.language = event.detail;
        console.log(this.language);
        this.translatePage();
    }

    get disableButton(){
        return (!this.hasSubmittedPrf || this.propInProcess);
    }

    handleSectionToggle(event) {
        const openSection = event.detail.openSections;
        this.showReadMore = openSection.length === 0 ? true : false;
        this.readMoreTag = this.showReadMore ? ' (' + this.transByNameObj.ReadMore + ')' : '';
        this.accordLabel = this.transByNameObj.bff_GrantsSiteLandingTitle + this.readMoreTag;
    }
    
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
        console.log('dateestablished comparison', this.dateEstablished && (this.addDays(this.dateEstablished, 365) > this.currentDate));
        if (this.hasPendingSustain) {
            this.errMsg = this.transByNameObj.SustainAppInProgress; // 'You have a Sustain Fund grant application in progress';
            this.debug = 'Pending sustain';
            this.displayAppError();
        } else if (this.hasRecentSubmittedSustain) {
            this.errMsg = this.transByNameObj.SustainSubmitted; // 'You have already submitted a Sustain Fund grant application';
            this.displayAppError();
        } else if (this.dateEstablished && (this.addDays(this.dateEstablished, 365) > this.currentDate)) {
            console.log('dateestablished comparison', this.dateEstablished && (this.dateEstablished > this.currentDate - 365));
            this.errMsg = this.transByNameObj.SustainIneligible; // 'Your group is not eligible for a Sustain grant';
            this.displayAppError();
        } else if (this.currentDate > this.sustainDeadlineDate) {
            this.errMsg = this.transByNameObj.SustainMissedDeadline; // 'The deadline for applying for a Sustain Fund grant has passed';
            this.displayAppError();
        } else {
            // Create Proposal with grant type and Form Instance linked to Proposal
            // Prep error message in case of issue.
            this.propInProcess = true;
            this.errMsg = this.transByNameObj.SystemErrorMsg + ' (Id: ' + event.target.dataset.name + ')';
            this.grantType = 'BFF-Sustain';
            this.createProposalWithFormInstanceAndNavigate(this.grantType);
        }
    }

    handleNewAppSolidarity(event) {
        if (this.hasPendingSolidarity) {
            // Toast message: pending message
            this.errMsg = this.transByNameObj.SolidarityAppInProgress; //'You have a Solidarity Fund grant application in progress';
            this.displayAppError();
        } else if (this.hasRecentSubmittedSolidarity) {
            // Toast message: submitted message
            this.errMsg = this.transByNameObj.SolidaritySubmitted; // You have already submitted a Solidarity grant application.
            this.displayAppError();
        } else {
            // Create Proposal with grant type and Form Instance linked to Proposal
            // Prep error message in case of issue.
            this.propInProcess = true;
            this.errMsg = this.transByNameObj.SystemErrorMsg + ' (Id: ' + event.target.dataset.name + ')';;
            this.grantType = 'BFF-Solidarity';
            this.createProposalWithFormInstanceAndNavigate(this.grantType);
        }
    }

    displayAppError() {
        let appError = {
            title: this.transByNameObj.InvalidAction,
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
                lang: this.language
            }
        });
    }

    navigateToProposalLanding(propId) {
        // Navigate to proposal landing page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Proposal__c'
            },
            state: {
                recordId: propId,
                lang: this.language
            }
        });
    }


    /***** Process FormInstances and Proposals for Proposal Table *****/
    processFormInstList(itemsList) {
        let mapIds = new Map();
        let mapSubmitted = new Map();
        let isSubmitted = false;
        for (let itm of itemsList) {
            if (itm.Proposal__c!=null && this.appNames.includes(itm.Form_name__c)) {
                // Build map of PropId to FormInstanceId;
                mapIds.set(itm.Proposal__c, itm.Id);
                // Build map of FormInstanceId to boolean IsSubmitted
                isSubmitted = (itm.Date_submitted__c) ? isSubmitted = true : false;
                mapSubmitted.set(itm.Id, isSubmitted);
                console.log('PropId ', itm.Proposal__c);
            }
        }
        this.prpFormInst = mapIds;
        this.formInstIdSubmitted = mapSubmitted;
    }

    processPrpList(itemsList) {
        let returnList = [];
        let isSubmitted = false;
        let dateSubmitted = new Date();
        console.log('processPrpList');
        console.log('current date', this.currentDate);
        for (let itm of itemsList) {
            if (itm.Grant_type__c=='BFF-Solidarity') {
                itm.grantType = this.transByName.get('bff_SolidarityFund');
            } else if (itm.Grant_type__c=='BFF-Sustain') {
                itm.grantType = this.transByName.get('bff_SustainFund');
            }
            itm.proposalName = itm.Name;
            console.log('proposalName',itm.proposalName);
            itm.dateReceived = itm.Date_received__c;
            itm.dateCreated = itm.CreatedDate;
            // Let form instance dictate whether a proposal has been submitted.
            let formInstId = this.prpFormInst.get(itm.Id);
            isSubmitted = this.formInstIdSubmitted.get(formInstId);
            itm.disableButton = isSubmitted ? true : false;
            console.log('disableButton', itm.disableButton);
            itm.rowIcon = isSubmitted ? '' : "utility:edit"; // "utility:preview"
            itm.rowAction = isSubmitted ? '' : this.transByNameObj.Edit; // this.transByNameObj.View
            if (!isSubmitted) {
                itm.statusSortBy = 0;
                itm.status = this.transByNameObj.Pending;
            }
            switch (itm.Status_external__c) {
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
            if (!itm.status) {
                // Set empty status to Submitted
                // (in case Prop status is pending but form instance has been submitted)
                itm.statusSortBy = 1;
                itm.status = this.transByNameObj.Submitted;
            }
            returnList.push(itm);

            // Relies on form instance submission for toast messages
            if (isSubmitted) {
                // Submitted date is Prop date rec'd
                dateSubmitted = itm.Date_received__c;
                console.log('dateSubmitted', dateSubmitted);
                if (itm.Grant_type__c=='BFF-Solidarity') {
                    console.log('addedDays', this.addDays(dateSubmitted, this.recentSolidarityCriteria));
                    console.log('comparison', this.addDays(dateSubmitted, this.recentSolidarityCriteria) > this.currentDate);
                    if (this.addDays(dateSubmitted, this.recentSolidarityCriteria) > this.currentDate) {
                        this.hasRecentSubmittedSolidarity = true;
                    }
                } else if (itm.Grant_type__c=='BFF-Sustain') {
                    this.hasRecentSubmittedSustain = true;
                }
            } else if (itm.Grant_type__c=='BFF-Solidarity') {
                this.hasPendingSolidarity = true;
            } else if (itm.Grant_type__c=='BFF-Sustain') {
                this.hasPendingSustain = true;
            }
        
            /**** Following test resulted in blank column ****/
            let editButton = {type: 'button-icon', initialWidth: 40, 
                typeAttributes: {  
                    iconName: "utility:edit", 
                    name: this.transByNameObj.Edit,  
                    variant: 'bare',
                    alternativeText: this.transByNameObj.Edit,       
                    disabled: false
                }
            };

            let noButton = { 
                label: '', 
                initialWidth: 40,
                fieldName: '',
                hideDefaultActions: true,
                sortable: false,
            };

            itm.buttonRow = isSubmitted ? noButton : editButton;

            /**** Above resulted in blank column ****/

        }
        
        this.columns = [
            // { fieldName: 'buttonRow' },
            { label: '', type: 'button-icon', initialWidth: 40, typeAttributes: 
                {iconName: { fieldName: 'rowIcon' }, disabled: { fieldName: 'disableButton'}, title: { fieldName: 'rowAction' }, variant: 'bare', alternativeText: { fieldName: 'rowAction' } } },
            { label: this.transByNameObj.Number, type: 'button', initialWidth: 125, fieldName: 'proposalName', hideDefaultActions: true, sortable: false, typeAttributes:
                { label: { fieldName: 'proposalName' }, name: "gotoProposal", variant: "base" } },
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
        const actionName = event.detail.action.name;
        console.log('actionName', actionName);
        if (actionName == 'gotoProposal') {
            this.navigateToProposalLanding(row.Id);
        } else {
            this.appFormInstanceId = this.prpFormInst.get(row.Id);
            this.navigateToFormInstance(this.appFormInstanceId);
        }

      
    }






}