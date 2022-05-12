import { LightningElement } from 'lwc';
import getProfileSummary from '@salesforce/apex/ProfileController.getProfileSummary';
import createProposal from '@salesforce/apex/ProfileController.createProposal';
import logoResource from '@salesforce/resourceUrl/BFFLogoGrantsSite';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';
import Id from '@salesforce/user/Id';
import getTranslations from '@salesforce/apex/FormPhraseController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';

export default class BffGrantsSiteHome extends NavigationMixin(LightningElement) {
    userId = Id;

    // Logos and text on page
    bffLogo = logoResource;
    bffLogoWhiteText = logoResourceWhiteText;
    pageHeader;
    pageSubheader;
    logout;
    support;
    prfButtonLabel;
    grantHeading;
    grantSubHeading;
    grantDescription;
    sustainFundHeading;
    sustainFundDetails;
    solidarityFundHeading;
    solidarityFundDetails;
    grantEligibility;
    newAppSustainFund;
    newAppSolidarityFund;
    showMenu = false;
    bannerProfile;
    hoverMessage;

    // Translations
    transInfo;
    langMap;
    langTag;
    language;
    transByName;

    // Profile data
    profileSummary;
    hasSubmittedPrf = true;
    prFormInstanceId;
    dataLoaded = false;

    // Proposals list
    hasProposals;
    prpList;
    prpItemsData;
    // pendingItemsData;
    // submittedItemsData;
    columns;
    hasPendingSolidarity;
    hasPendingSustain;
    recentSolidarityCriteria = 182; // days equivalent to 6 months
    recentSustainCriteria = 730; // days equivalent to 2 years - setting this to be conservative
    hasRecentSubmittedSolidarity;
    hasRecentSubmittedSustain;
    grantType;
    appFormInstanceId;

    
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
            this.hasSubmittedPrf = this.profileSummary.hasSubmittedPrf;
            this.prFormInstanceId = this.profileSummary.prFormInstanceId;
            this.transInfo = JSON.parse(translations);
            this.transByName = buildTransByName(this.transInfo, this.language);
            this.setLangPickerDefault();
            this.translatePage();
            this.prpList = this.profileSummary.prpList;
            this.hasProposals = this.profileSummary.hasProposals;
            this.prpItemsData = this.updateList(this.prpList);
            // this.pendingItemsData = parsedList.pending;
            // this.submittedItemsData = parsedList.submitted;
            this.dataLoaded = true;
        } catch (error) {
            handleError(error);
        }
    }

    translatePage(){
        this.pageHeader = this.transByName.get('bff_GrantsSiteLandingWelcome');
        this.pageSubheader = this.transByName.get('bff_GrantsSiteLandingWelcomeSubheading');
        this.prfButtonLabel = this.transByName.get('bff_GrantsSiteLandingProfileButton');
        this.grantHeading = this.transByName.get('bff_GrantsSiteLandingTitle');
        this.grantSubHeading = this.transByName.get('bff_GrantsSiteLandingSubtitle');
        this.grantDescription = this.transByName.get('bff_GrantsSiteLandingFundDetails');
        this.sustainFundHeading = this.transByName.get('bff_GrantsSiteLandingSustainFund');
        this.sustainFundDetails = this.transByName.get('bff_GrantsSiteLandingSustainFundDetails');
        this.solidarityFundHeading = this.transByName.get('bff_GrantsSiteLandingSolidarityFund');
        this.solidarityFundDetails = this.transByName.get('bff_GrantsSiteLandingSolidarityFundDetails');
        this.grantEligibility = this.transByName.get('bff_GrantsSiteLandingEligibility');
        this.logout = this.transByName.get('Logout');
        this.support = this.transByName.get('Support');
        this.bannerProfile = this.transByName.get('BannerProfile');
        let newApp = this.transByName.get('NewApplication');
        this.newAppSustainFund = newApp + ': ' + this.transByName.get('bff_SustainFund');
        this.newAppSolidarityFund = newApp + ': ' + this.transByName.get('bff_SolidarityFund');
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
        this.transByName = buildTransByName(this.transInfo, this.language);
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

    navigateHome() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Home'
            }
        });
    }

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

    navigateToProfileForm() {
        // Navigate to form instance detail page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'FormInstance__c'
            },
            state: {
                recordId: this.prFormInstanceId,
                language: this.language
            }
        });
    }

    handleNewAppSolidarity(event) {
        if (hasPendingSolidarity) {
            // Toast message: pending message
        } else if (hasRecentSubmittedSolidarity) {
            // Toast message: submitted message
        } else {
            // Create Proposal with grant type and Form Instance linked to Proposal
            // await
            this.grantType = 'BFF-Solidarity';
        }
    }

    handleNewAppSustain(event) {
        if (hasPendingSolidarity) {
            // Toast message: pending message
        } else if (hasRecentSubmittedSolidarity) {
            // Toast message: submitted message
        }
    }

    async createProposalWithFormInstance(grantType) {
        try {
            this.appFormInstanceId = await createProposal( { prfId: this.profileSummary.prf.Id, grantType: this.grantType } );
        } catch (error) {
            handleError(error);
        }
    }

    handleRowAction() {

    }


    /***** Handle Proposals *****/
    updateList(itemsList) {
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
            itm.status = itm.Status_external__c; // this.TransByName.get(itm.Status_external__c);
            switch (itm.Status_external__c) {
                case 'Pending':
                    itm.statusSortBy = 0;
                    break;
                case 'Submitted':
                    itm.statusSortBy = 1;
                    break;
                case 'Awarded':
                    itm.statusSortBy = 2;
                    break;
                case 'Closed':
                    itm.statusSortBy = 3;
                    break;
                case 'Withdrawn':
                    itm.statusSortBy = 4;
                    break;
                case 'Declined':
                    itm.statusSortBy = 5;
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
            { label: 'Number', fieldName: 'proposalName', hideDefaultActions: true, sortable: false,},
            { label: 'Status', fieldName: 'status', hideDefaultActions: true, sortable: false,},
            { label: 'Type', fieldName: 'grantType', hideDefaultActions: true, sortable: false,},
            { label: 'Date Created', fieldName: 'dateCreated', type: 'date', hideDefaultActions: true, sortable: false,},
            { label: 'Date Submitted', fieldName: 'dateReceived', type: 'date', hideDefaultActions: true, sortable: false,},
        ];
        return returnList;
    }

}