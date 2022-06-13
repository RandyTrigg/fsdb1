import { LightningElement, api } from 'lwc';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin } from 'lightning/navigation';
import Id from '@salesforce/user/Id';
import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';
import loadAdvisorSummary from '@salesforce/apex/AssessorSiteController.loadAdvisorSummary';

export default class BffReviewSiteHeader extends NavigationMixin(LightningElement) {
    userId = Id;
    bffLogoWhiteText = logoResourceWhiteText;
    dataLoaded = false;
    logout;
    support;
    profile = 'Profile';
    @api language;
    @api disableProfile;
    @api hideSearch;
    @api hideLanguagePicker;
    @api transData;
    transInfo;
    transByName;
    transByNameObj;
    langTag;
    langMap;

    connectedCallback(){
        if (this.userId && this.language) {
            console.log('connectedCallbackHeader');
            this.dataLoaded = true;
            console.log(this.language);
            // NOTE: Cannot figure out how to successfully pass translation data
            // this.transInfo = JSON.parse(this.transData);
            // this.translatePage();
            // console.log(this.transByName.get('logout'));
            // this.setLangPickerDefault();
        }
    }


    translatePage() {
        console.log('translatePage in header');
        this.transByName = buildTransByName(this.transInfo, this.language);
        this.transByNameObj = Object.fromEntries(this.transByName);
        this.logout = this.transByName.get('Logout');
        this.support = this.transByName.get('Support');
        console.log(this.transByNameObj.bff_ReviewSiteLandingWelcome);
    }
    
    handleMenuSelect () {
        this.showMenu = !this.showMenu;
    }
    
    handleProfile () {
        // this.showMenu = !this.showMenu;
        // NavigationMixin -> form instance for advisor
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
        console.log(this.language);
        this.translatePage();


        // Create event to pass language
        const selLang = new CustomEvent("getselectedlanguage", {
            detail: this.language
        });

        //Dispatch
        this.dispatchEvent(selLang);
        console.log('dispatched event');
    }

    get options() {
        return [
                 { label: 'English', value: 'English' },
                 { label: 'Español', value: 'Spanish' },
                 { label: 'Français', value: 'French' },
                 { label: 'Português', value: 'Portuguese' }
               ];
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