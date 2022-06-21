import { LightningElement, wire } from 'lwc';
import { handleError } from 'c/lwcUtilities';
import { NavigationMixin } from 'lightning/navigation';

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
            this.showSpinner = false;
            this.showForm = false;
            console.log('error',error);
            this.showFailure=true;
            this.errMsg = error.body.message;
            // this.errMsg = JSON.parse(error.body.message);
            // handleError(error); 
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