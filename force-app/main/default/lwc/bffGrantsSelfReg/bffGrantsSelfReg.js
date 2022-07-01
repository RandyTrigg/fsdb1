import { LightningElement, wire } from 'lwc';
import { handleError } from 'c/lwcUtilities';
import { NavigationMixin } from 'lightning/navigation';
import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';

import handleRegistration from '@salesforce/apex/SiteController.handleRegistration';

export default class BffGrantsSelfReg extends NavigationMixin ( LightningElement ) {

    email;
    groupName;
    showForm = true;
    registerDisabled = true;
    errMsg;
    showSpinner = false;
    showSuccess = false;
    showFailure = false;
    language = "English";
    langTag;
    transInfo;
    dataLoaded = false;
    loginPageRef;
    loginUrl;
    cardTitle;
    dupeUsername = false;

    connectedCallback(){
        this.loadData();
    }

    async loadData() {
        let translations = await getTranslations();
        this.transInfo = JSON.parse(translations);
        this.setLangTag();
        this.translatePage();
        // Commented code results in StartURL that loops back to Register page on login:
        // https://globalfundforwomen-fs.force.com/GrantsAtBlackFeministFund/s/login/?startURL=%2FGrantsAtBlackFeministFund%2Fs%2Flogin%2FSelfRegister
        /* this.loginPageRef = {
            type: 'comm__loginPage',
            attributes: {
                actionName: 'login'
            }
        };
        this[NavigationMixin.GenerateUrl](this.loginPageRef)
            .then(url => { 
                this.loginUrl = url;
                console.log(this.loginUrl); 
            }); */
        /* this[NavigationMixin.GenerateUrl]({
            type: 'comm__loginPage',
            attributes: {
                actionName: 'login'
            },
        }).then((url) => {
            this.loginUrl = url;
            console.log(this.loginUrl);
        }); */
        this.loginUrl = '/GrantsAtBlackFeministFund/s/login/';
        this.dataLoaded = true;
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

    translatePage(){
        this.transByName = buildTransByName(this.transInfo, this.language);
        this.transByNameObj = Object.fromEntries(this.transByName);
        this.languageSelector = this.transByName.get('LanguageSelector');
        this.cardTitle = this.transByNameObj.RegisterYourOrganization;
    }

    handleLanguagePicker(event){
        this.language = event.target.value;
        this.translatePage();
    }

    handleEmail(event) {
        this.email = event.target.value;
        this.checkSubmittable();
    }

    handleGroupName(event) {
        this.groupName = event.target.value;
        this.checkSubmittable();
    }

    async handleRegister() {
        try {
            console.log('handle registration');
            this.showSpinner = true;
            let registrant = {
                "email":this.email,
                "groupName":this.groupName,
                "language":this.language
            };
            
            let errString = await handleRegistration({registrantJSON: JSON.stringify(registrant)});
            console.log(errString);
            if (!errString) {
                console.log('not errString');
                this.showForm = false;
                this.showSuccess =true;
                this.showSpinner = false;
                this.cardTitle = this.transByNameObj.Success + '!';
            } else {
                console.log('else errString', errString);
                this.showSpinner = false;
                this.showForm = false;
                this.showFailure = true;
                this.cardTitle = this.transByNameObj.Error + '!';
                this.dupeUsername = (errString == 'DuplicateUsername');
            }
        } catch (error) {
            // Catches apex errors and displays generic message (see console log for actual error)
            this.showSpinner = false;
            this.showForm = false;
            this.showFailure = true;
            this.cardTitle = this.transByNameObj.Error;
            console.log('error',error);
        }

    }

    checkSubmittable() {
        console.log('update submit entered');

        let email = this.template.querySelector('.email-input');

        if (this.groupName && this.email && (email.validity.valid === true)) {
            console.log('baseline fields valid');           
            this.registerDisabled = false;
        } else {
            this.registerDisabled = true;
        }
    }

    // Currently unused.
    // Same issue as noted above.
    handleGoToLogin(){
        console.log('GoToLogin');
        // Following prevents link from working
        // evt.preventDefault();
        // evt.stopPropogation();
        console.log(this.loginUrl);
        this[NavigationMixin.Navigate](this.loginPageRef, true);
    }


}