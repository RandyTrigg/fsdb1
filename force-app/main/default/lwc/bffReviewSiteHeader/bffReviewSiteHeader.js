import { LightningElement, api } from 'lwc';
import logoResource from '@salesforce/resourceUrl/BFFLogoGrantsSite';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin } from 'lightning/navigation';

export default class BffReviewSiteHeader extends NavigationMixin(LightningElement) {
    bffLogo = logoResource;
    bffLogoWhiteText = logoResourceWhiteText;
    logout;
    support;
    profile;
    @api disableProfile;
    @api hideSearch;
    @api hideLanguagePicker;

    handleMenuSelect () {
        this.showMenu = !this.showMenu;
    }
    
    handleProfile () {
        // this.showMenu = !this.showMenu;
        // NavigationMixin -> form instance for advisor
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