import { LightningElement } from 'lwc';

import getProfileSummary from '@salesforce/apex/ProfileController.getProfileSummary';
// import getTranslations from '@salesforce/apex/FormPhraseController.getTranslations';
// import { buildTransByName } from 'c/formsUtilities';

export default class BffGrantsSiteHome extends LightningElement {
    pageHeader;
    pageSubheader;
    prfButtonLabel;
    grantHeading;
    grantSubHeading;
    grantDescription;

    propTitle;
    formsTitle;

    profileSummary;
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


            this.dataLoaded = true;
        } catch (error) {
            // handleError(error);
        }
        
    }












}