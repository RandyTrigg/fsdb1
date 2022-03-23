import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getSearchableRecords from '@salesforce/apex/AssessorSiteController.getSearchableRecords';
//import logoResource from '@salesforce/resourceUrl/GFWAdvisorSiteLogo';

export default class AssessorSiteHeader extends NavigationMixin(LightningElement) {
    @api hideSearch;
    showMenu = false;
    sfdcBaseURL;
    //gfwLogo = logoResource;

    //Lookup components
    @api notifyViaAlerts = false;

    searchableRecords;
    isMultiEntry = false;
    maxSelectionSize = 2;
    errors = [];

    async connectedCallback() {
        this.searchableRecords = JSON.parse(await getSearchableRecords());
    }
    

    handleMenuSelect () {
        this.showMenu = !this.showMenu;
    }

    renderedCallback() {
        this.sfdcBaseURL = window.location.origin;
    }

    

    /**
     * Handles the lookup search event.
     * Calls the server to perform the search and returns the resuls to the lookup.
     * @param {event} event `search` event emmitted by the lookup
     */
     handleLookupSearch(event) {
        const lookupElement = event.target;
        // Filter the list of all items based on search term
        let results = this.searchableRecords.filter(this.containsTerm,event.detail.searchTerm);
        lookupElement.setSearchResults(results);
    }

    containsTerm(obj) {
        return JSON.stringify(obj).toLowerCase().includes(this.toLowerCase());
    }

    handleSearchClick() {
        const selection = this.template.querySelector('[data-id="searchLookup"]').getSelection();
        if (selection.length>0) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: selection[0].id,
                    objectApiName: selection[0].sObjectType,
                    actionName: 'view'
                }
            });
        }
    }

     /**
     * Handles the lookup selection change
     * @param {event} event `selectionchange` event emmitted by the lookup.
     * The event contains the list of selected ids.
     */
    // eslint-disable-next-line no-unused-vars
    handleLookupSelectionChange(event) {
        this.checkForErrors();
    }

    handleLookupTypeChange(event) {
        this.initialSelection = [];
        this.errors = [];
        this.isMultiEntry = event.target.checked;
    }

    handleMaxSelectionSizeChange(event) {
        this.maxSelectionSize = event.target.value;
    }

    handleSubmit() {
        this.checkForErrors();
        if (this.errors.length === 0) {
            this.notifyUser('Success', 'The form was submitted.', 'success');
        }
    }

    handleClear() {
        this.initialSelection = [];
        this.errors = [];
    }

    checkForErrors() {
        this.errors = [];
        const selection = this.template.querySelector('c-lookup').getSelection();
        // Custom validation rule
        if (this.isMultiEntry && selection.length > this.maxSelectionSize) {
            this.errors.push({ message: `You may only select up to ${this.maxSelectionSize} items.` });
        }
        // Enforcing required field
        if (selection.length === 0) {
            this.errors.push({ message: 'Please make a selection.' });
        }
    }

    notifyUser(title, message, variant) {
        if (this.notifyViaAlerts) {
            // Notify via alert
            // eslint-disable-next-line no-alert
            alert(`${title}\n${message}`);
        } else {
            // Notify via toast (only works in LEX)
            const toastEvent = new ShowToastEvent({ title, message, variant });
            this.dispatchEvent(toastEvent);
        }
    }

    handleLogout(){
        this[NavigationMixin.Navigate]({
            type: 'comm__loginPage',
            attributes: {
              actionName: 'logout'
            }
          });    
    }

    handleHome () {
        console.log('handle home');
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Home'
            }
        });
    }
}