import { LightningElement, api, wire } from 'lwc';
import { handleError } from 'c/lwcUtilities';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getHeaderName from '@salesforce/apex/SiteController.getHeaderName';

export default class BffReviewSiteHeader extends NavigationMixin(LightningElement) {
    currentPageReference;
    bffLogoWhiteText = logoResourceWhiteText;
    dataLoaded = false;
    name;
    @api language;
    @api showProfile = false;
    @api showSearch = false;
    @api showLanguagePicker = false;
    @api advProfileFormInstanceId;
    @api transByNameObj;
    langTag;
    langMap;
    page;
    pageName;
    onHome = true;
    profileURL;
    profilePageRef;
    
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        console.log('wire currentPageReference', currentPageReference);
        if (currentPageReference && this.language) {
            this.page = currentPageReference.attributes.name;
            console.log(this.page);
            if (this.page==='Assessment__c') this.pageName = this.transByNameObj.ProposalReview;
            if (this.page==='FormInstance__c') this.pageName = this.transByNameObj.Form; // Form
            this.onHome = this.page==='Home';
            console.log(this.onHome);
        }
    }

    connectedCallback(){
        this.loadData();
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
            // this.generateProfileURL(this.advProfileFormInstanceId);
            this.dataLoaded = true;




        
            console.log('beforepageref set');
            this.profilePageRef = {
                type: 'comm__namedPage',
                attributes: {
                    name: 'FormInstance__c'
                },
                state: {
                    recordId: this.advProfileFormInstanceId,
                    language: this.language
                }
            };
            this[NavigationMixin.GenerateUrl](this.profilePageRef)
                .then(url => this.profileUrl = url);
            
            console.log('profileURL',this.profileUrl);



        }
    }

    async loadData() {
        try {
            console.log('loadData');
            // Retrieve Advisor and Form Instance, along with translations
            // let [translations ] = await Promise.all ([
            this.name = await getHeaderName();
        } catch (error) {
            handleError(error);
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
        // this.navigateToFormInstance(this.advProfileFormInstanceId);
        this.navigateToProfile(this.advProfileFormInstanceId);
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

    navigateToProfile(formInstId) {
        console.log('navigateToProfile');
        this[NavigationMixin.GenerateURL]({
            type: 'comm_namedPage',
            attributes: {
                name: 'FormInstance__c'
            },
            state: {
                recordId: formInstId,
                language: this.language
            }
        }).then(url => {
            window.open(url);
        });
    }

    handleProfileSelect(evt) {
        console.log('handleProfileSelect');
        evt.preventDefault();
        evt.stopPropagation();
        this[NavigationMixin.Navigate](this.profilePageRef);
        // this[NavigationMixin.Navigate](this.profilePageRef({c__language: this.language}));
    }

    /*
    generateProfileURL(formInstId) {
        console.log('navigateToProfile');
        this[NavigationMixin.GenerateURL]({
            type: 'comm_namedPage',
            attributes: {
                name: 'FormInstance__c'
            },
            state: {
                recordId: formInstId,
                language: this.language
            }
        }).then(url => {
            this.profileURL = url;
        });
    }*/

    handleLogout(){
        this[NavigationMixin.Navigate]({
            type: 'comm__loginPage',
            attributes: {
              actionName: 'logout'
            }
          });
    }
}