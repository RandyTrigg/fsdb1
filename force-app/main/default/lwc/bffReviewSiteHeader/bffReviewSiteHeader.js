import { LightningElement, api } from 'lwc';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin } from 'lightning/navigation';
import Id from '@salesforce/user/Id';
import loadAdvisorSummary from '@salesforce/apex/AssessorSiteController.loadAdvisorSummary';

export default class BffReviewSiteHeader extends NavigationMixin(LightningElement) {
    userId = Id;
    bffLogoWhiteText = logoResourceWhiteText;
    dataLoaded = false;

    profile = 'My Profile';
    @api language;
    @api disableProfile; // Removed this - disabling even when set to False.
    @api hideSearch;
    @api hideLanguagePicker;
    @api advisorFormInstanceId;
    @api transByNameObj;
    langTag;
    langMap;

    connectedCallback(){
        if (this.userId && this.language) {
            console.log('connectedCallbackHeader');
            console.log(this.language);
            console.log(this.advisorFormInstanceId);
            console.log(this.transByNameObj.bff_ReviewSiteLandingWelcome);
            // Following setLangPickerDefault throws error that options is null. 
            // this.setLangPickerDefault();
            this.dataLoaded = true;
        }
    }

    get options() {
        return [
                 { label: 'English', value: 'English' },
                 { label: 'Español', value: 'Spanish' },
                 { label: 'Français', value: 'French' },
                 { label: 'Português', value: 'Portuguese' }
               ];
    }

    setLangPickerDefault(){
        const langPicker = this.template.querySelector('[data-id="langPicker"]');
        console.log('setLangPickerDefault');
        console.log(langPicker);
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

        // Create event to pass language
        const selLang = new CustomEvent("getselectedlanguage", {
            detail: this.language
        });

        //Dispatch
        this.dispatchEvent(selLang);
        console.log('dispatched event');
    }

    handleMenuSelect () {
        this.showMenu = !this.showMenu;
    }
    
    handleHome(){
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Home'
            }
        });
    }
    
    handleProfile () {
        this.navigateToFormInstance(this.advisorFormInstanceId);
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

    handleLogout(){
        this[NavigationMixin.Navigate]({
            type: 'comm__loginPage',
            attributes: {
              actionName: 'logout'
            }
          });
    }
}