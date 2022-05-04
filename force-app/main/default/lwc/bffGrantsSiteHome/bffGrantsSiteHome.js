import { LightningElement } from 'lwc';

import getProfileSummary from '@salesforce/apex/ProfileController.getProfileSummary';
import logoResource from '@salesforce/resourceUrl/BFFLogoGrantsSite';
import { NavigationMixin } from 'lightning/navigation';
// import getTranslations from '@salesforce/apex/FormPhraseController.getTranslations';
// import { buildTransByName } from 'c/formsUtilities';

export default class BffGrantsSiteHome extends LightningElement {
    pageHeader;
    pageSubheader;
    prfButtonLabel;
    grantHeading;
    grantSubHeading;
    grantDescription;
    bffLogo = logoResource;

    propTitle;
    formsTitle;

    profileSummary;
    langMap;
    langTag;
    language;
    dataLoaded = false;
    
    async connectedCallback() {
        try {
            this.profileSummary = JSON.parse(await getProfileSummary());

            this.pageHeader = 'bff_GrantsSiteLandingWelcome';
            this.pageSubheader = 'Page subheader';
            this.prfButtonLabel = 'bff_GrantsSiteLandingProfileButton';
            this.grantHeading = 'bff_GrantsSiteLandingTitle';
            this.grantSubHeading = 'bff_GrantsSiteLandingSubtitle';
            this.grantDescription = 'bff_GrantsSiteLandingSustainFund'; // Bundle this into one phrase w/ formatting?
            this.language = this.profileSummary.language;

            this.langMap.set('English', 'en');
            this.langMap.set('Spanish', 'sp');
            this.langMap.set('French', 'fr');

            this.dataLoaded = true;
        } catch (error) {
            // handleError(error);
        }

    handleLanguage(){
            this.langTag = langMap.get(this.language);
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












}