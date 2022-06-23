import { LightningElement, wire } from 'lwc';
import { handleError } from 'c/lwcUtilities';
import { NavigationMixin } from 'lightning/navigation';
import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';

import handleRegistration from '@salesforce/apex/BFFGrantsRegistrationController.handleRegistration';

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

    connectedCallback(){
        this.loadData();
    }

    async loadData() {
        let translations = await getTranslations();
        this.transInfo = JSON.parse(translations);
        this.setLangTag();
        this.translatePage();
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
                "groupName":this.groupName
            };
            
            let errString = await handleRegistration({registrantJSON: JSON.stringify(registrant)});
            if (!errString) {
                this.showForm = false;
                this.showSuccess =true;
                this.showSpinner = false;
            } else {
                this.showSpinner = false;
                this.showForm = false;
                this.showFailure = true;
                this.errMsg=errString; 
            }
        } catch (error) {
            // Catches apex errors and displays generic message (see console log for actual error)
            this.showSpinner = false;
            this.showForm = false;
            console.log('error',error);
            this.showFailure=true;
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
}