import { LightningElement, api, wire, track } from 'lwc';
import { handleError } from 'c/lwcUtilities';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getHeaderName from '@salesforce/apex/SiteController.getHeaderName';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import PROP_ID from '@salesforce/schema/Form_Instance__c.ProposalId__c';
import FI_ID from '@salesforce/schema/Form_Instance__c.Id';

const fields = [PROP_ID, FI_ID];
export default class BffReviewSiteHeader extends NavigationMixin(LightningElement) {
    currentPageReference;
    bffLogoWhiteText = logoResourceWhiteText;
    dataLoaded = false;
    name;
    @api recordId; // Should be forminstance id
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
    onPropFormInst = false;
    propId;
    @track formInstdata;

    // Breadcrumbs: Proposal landing.
    // RecordId passed to header in forminstance. Retrieve prop Id for prop landing.
    @wire(getRecord, { recordId: '$recordId', fields })
        formInst({error,data}) {
            if (data) {
                this.formInstdata = data;
                console.log('forminstdata', JSON.stringify(data));
                this.propId = getFieldValue(this.formInstdata, PROP_ID);
                console.log('propid',this.propId);
                if (this.propId) {
                    this.onPropFormInst = true;
                    console.log('onPropFormInst', this.onPropFormInst);
                }
            } else if (error) {
                console.log('forminst error', JSON.stringify(error));
            }
        }
    
    // Breadcrumbs: Current page
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        console.log('wire currentPageReference', currentPageReference);
        if (currentPageReference && this.language) {
            this.page = currentPageReference.attributes.name;
            console.log(this.page);
            this.onHome = this.page==='Home';
            console.log('onhome', this.onHome);
            if (this.page==='Assessment__c') this.pageName = this.transByNameObj.ProposalReview;
            if (this.page==='FormInstance__c') this.pageName = this.transByNameObj.Form;
            if (this.page==='Proposal__c') this.pageName = 'Proposal'; // this.transByNameObj.Proposal;
            console.log('thispage', this.page);
            console.log('thispagename', this.pageName);
        }
    }

    connectedCallback(){
        this.loadData();
        if (this.language) {
            console.log('connectedCallbackHeader');
            console.log(this.language);
            console.log(this.advisorFormInstanceId);
            console.log('hidelangpicker',this.hideLanguagePicker);
            console.log('showSearch',this.showSearch);
            console.log('disableProfile',this.disableProfile);
            console.log('recordId', this.recordId);
            this.setLangTag();
            console.log(this.baseURL);
            this.dataLoaded = true;
        }
    }

    async loadData() {
        try {
            console.log('loadData');
            this.name = await getHeaderName();
            this.name = this.name.length > 35 ? this.name.substring(0,35) + '...' : this.name;
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

    selfClick() {
        // Do nothing - stay on this page
    }
    
    handleHome(){
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Home'
            }
        });
    }

    handlePropLanding(){
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Proposal__c'
            },
            state: {
                recordId: this.propId,
                lang: this.language
            }
        });
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