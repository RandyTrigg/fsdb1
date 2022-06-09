import { LightningElement } from 'lwc';
import logoResource from '@salesforce/resourceUrl/BFFLogoGrantsSite';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';
import { showUIError } from 'c/lwcUtilities';
import Id from '@salesforce/user/Id';
import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';

export default class BffReviewSiteHome extends NavigationMixin(LightningElement) {
    userId = Id;

    // Logos and text on page that needs to get loaded first 
    debug;
    bffLogo = logoResource;
    bffLogoWhiteText = logoResourceWhiteText;
    logout; // When logout & support translated in markup, page throws a null error on 'options.' Maybe because they are being passed as attributes?
    support;
    languageSelector;
    loading = "Loading";
    bffLogoAltText;
    showMenu = false;
    errMsg;
    showSpinner = true;

    // Translations
    transInfo;
    langMap;
    langTag;
    language;
    transByName;
    transByNameObj;

    connectedCallback() {
        if (this.userId) {
            this.loadData();
        }
    }

    async loadData() {
        try {
            console.log('loadData');
            // Retrieve Advisor and Form Instance, along with translations
            let [translations ] = await Promise.all ([
            // let [data, translations ] = await Promise.all ([
                // getProfileSummary(),
                getTranslations()
            ]);
            /*
            this.profileSummary = JSON.parse(data);
            this.language = this.profileSummary.language;
            this.transInfo = JSON.parse(translations);
            */
            console.log('translations fetched');
            this.language = "English";
            this.transInfo = JSON.parse(translations);
            this.translatePage();
            // this.setLangPickerDefault();
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
        this.language = event.target.value;
        this.translatePage();
    }

    /* get options() {
        return [
                 { label: 'English', value: 'English' },
                 { label: 'Español', value: 'Spanish' },
                 { label: 'Français', value: 'French' },
                 { label: 'Português', value: 'Portuguese' }
               ];
    } */

}