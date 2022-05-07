import { LightningElement } from 'lwc';
import getProfileSummary from '@salesforce/apex/ProfileController.getProfileSummary';
import logoResource from '@salesforce/resourceUrl/BFFLogoGrantsSite';
import { NavigationMixin } from 'lightning/navigation';
import { handleError } from 'c/lwcUtilities';
import Id from '@salesforce/user/Id';
// import getTranslations from '@salesforce/apex/FormPhraseController.getTranslations';
// import { buildTransByName } from 'c/formsUtilities';

export default class BffGrantsSiteHome extends LightningElement {
    userId = Id;
    pageHeader;
    pageSubheader;
    prfButtonLabel;
    grantHeading;
    grantSubHeading;
    grantDescription;
    bffLogo = logoResource;
    showMenu = false;
    hasSubmittedPrf;
    prFormInstanceId;

    propTitle;
    formsTitle;

    profileSummary;
    langMap;
    langTag;
    language;
    dataLoaded = false;
    message = "Please create a Profile";
    hoverMessage;
    // options = ['English', 'Español', 'Français'];
    
    connectedCallback() {
        if (this.userId) {
            this.loadData();
        }
    }

    async loadData() {
        try {
            this.profileSummary = JSON.parse(await getProfileSummary());
            // Create Form Instance after creating Profile. Linked to Profile and bffProfile form.
            // Otherwise, look for FormInstance related to this Profile and bffProfile Form.
            // In either case, return with getProfileSummary.

            this.pageHeader = 'bff_GrantsSiteLandingWelcome';
            this.pageSubheader = 'Page subheader';
            this.prfButtonLabel = 'bff_GrantsSiteLandingProfileButton';
            this.grantHeading = 'bff_GrantsSiteLandingTitle';
            this.grantSubHeading = 'bff_GrantsSiteLandingSubtitle';
            this.grantDescription = 'bff_GrantsSiteLandingSustainFund'; // Bundle this into one phrase w/ formatting?
            this.language = this.profileSummary.language;
            this.hasSubmittedPrf = this.profileSummary.hasSubmittedPrf;
            this.prFormInstanceId = this.profileSummary.prFormInstanceId;
            
            /* This seems problematic - dataloaded is false.
            this.langMap.set('English', 'en');
            this.langMap.set('Español', 'sp');
            this.langMap.set('Français', 'fr');
            this.langTag = this.langMap.get(this.language);*/
            this.setLangPickerDefault();

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
    }

    handleLanguagePicker(event){
        this.language = event.target.value;
        // this.langTag = this.langMap.get(this.language);
    }

    get options() {
        return [
                 { label: 'English', value: 'English' },
                 { label: 'Español', value: 'Spanish' },
                 { label: 'Français', value: 'French' },
                 { label: 'Português', value: 'Portuguese' }
               ];
    }
     
    editProfile() {
        // Navigate to page with FormInstanceId for Profile
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

    navigateToNewPage() {
        // Navigate to form instance detail page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'TestFormInstance__c'
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