import { LightningElement, api } from 'lwc';
import logoResource from '@salesforce/resourceUrl/BFFLogoGrantsSite';
import logoResourceWhiteText from '@salesforce/resourceUrl/BFFLogoGrantsSite_WhiteText';
import { NavigationMixin } from 'lightning/navigation';

export default class BffGrantsSiteHeader extends NavigationMixin(LightningElement) {
    bffLogo = logoResource;
    bffLogoWhiteText = logoResourceWhiteText;
    @api logout;
    @api support;

    handleMenuSelect () {
        this.showMenu = !this.showMenu;
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