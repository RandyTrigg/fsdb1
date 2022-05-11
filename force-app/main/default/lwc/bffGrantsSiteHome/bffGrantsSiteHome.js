import { LightningElement } from 'lwc';
import getProfileSummary from '@salesforce/apex/ProfileController.getProfileSummary';
import logoResource from '@salesforce/resourceUrl/BFFLogoGrantsSite';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';
import Id from '@salesforce/user/Id';
import getTranslations from '@salesforce/apex/FormPhraseController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';

export default class BffGrantsSiteHome extends NavigationMixin(LightningElement) {
    userId = Id;
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
    bffLogo = logoResource;
    bffLogoWhiteText = logoResourceWhiteText;
    showMenu = false;
    hasSubmittedPrf = true;
    prFormInstanceId;

    propTitle;
    formsTitle;

    profileSummary;
    transInfo;
    langMap;
    langTag;
    language;
    transByName;
    dataLoaded = false;
    bannerProfile;
    hoverMessage;
    disableButton;
    
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
            this.dataLoaded = true;
        } catch (error) {
            handleError(error);
        }
    }

    getdisableButton(){
        return!(this.hasSubmittedPrf);
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
    
    handleNewSolApp(event) {

    }


    handleMenuSelect () {
        this.showMenu = !this.showMenu;
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


    handleLogout(){
        this[NavigationMixin.Navigate]({
            type: 'comm__loginPage',
            attributes: {
              actionName: 'logout'
            }
          });
    }


}