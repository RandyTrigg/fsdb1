import { LightningElement, api, wire } from 'lwc';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

export default class BffReviewSiteHeader extends NavigationMixin(LightningElement) {
    currentPageReference;
    bffLogoWhiteText = logoResourceWhiteText;
    dataLoaded = false;
    @api name;
    @api language;
    @api disableProfile = false; // Removed this - disabling even when set to False.
    @api showSearch = false;
    @api hideLanguagePicker = false;
    @api advProfileFormInstanceId;
    @api transByNameObj;
    langTag;
    langMap;
    page;
    pageName;
    onHome = true;
    
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        console.log('wire currentPageReference', currentPageReference);
        if (currentPageReference && this.language) {
            this.page = currentPageReference.attributes.name;
            console.log(this.page);
            if (this.page==='Assessment__c') this.pageName = this.transByNameObj.ProposalReview;
            if (this.page==='FormInstance__c') this.pageName = this.transByNameObj.MyProfile;
            this.onHome = this.page==='Home';
            console.log(this.onHome);
        }
    }

    connectedCallback(){
        if (this.language) {
            console.log('connectedCallbackHeader');
            console.log(this.language);
            console.log(this.advisorFormInstanceId);
            console.log(this.transByNameObj.bff_ReviewSiteLandingWelcome);
            console.log('hidelangpicker',this.hideLanguagePicker);
            console.log('showSearch',this.showSearch);
            console.log('disableProfile',this.disableProfile);
            this.setLangTag();

            console.log(this.baseURL);
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

    setLangTag(){
        console.log('setLangPickerDefault');
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
        this.setLangTag();
        // Create event to pass language to parent
        const selLang = new CustomEvent("getselectedlanguage", {
            detail: this.language
        });
        //Dispatch
        this.dispatchEvent(selLang);
        console.log('dispatched event');
    }
    
    handleHome(){
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Home'
            }
        });
    }

    selfClick() {
        // Do nothing - stay on this page
    }
    
    handleProfile () {
        this.navigateToFormInstance(this.advProfileFormInstanceId);
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