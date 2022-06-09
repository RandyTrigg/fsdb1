import { LightningElement, api } from 'lwc';
import logoResource from '@salesforce/resourceUrl/BFFLogoGrantsSite';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin } from 'lightning/navigation';

export default class BffReviewSiteHeader extends NavigationMixin(LightningElement) {
    bffLogo = logoResource;
    bffLogoWhiteText = logoResourceWhiteText;
    logout = 'Logout';
    support = 'Support';
    profile = 'Profile';
    language;
    @api transByNameObj;
    @api disableProfile;
    @api hideSearch;
    @api hideLanguagePicker;

    translatePage() {
        console.log('translatePage in header');
        // console.log(this.transByNameObj.bff_ReviewSiteLandingWelcome);
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