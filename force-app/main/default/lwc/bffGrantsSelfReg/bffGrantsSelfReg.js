import { LightningElement, wire } from 'lwc';
import { handleError } from 'c/lwcUtilities';
import { NavigationMixin } from 'lightning/navigation';

import handleRegistration from '@salesforce/apex/BFFGrantsRegistrationController.handleRegistration';

export default class BffGrantsSelfReg extends NavigationMixin ( LightningElement ) {

    firstName;
    lastName;
    email;
    groupName;
    showForm = true;
    registerDisabled = true;
    showSpinner = false;
    showSuccess = false;
    showFailure = false;

    handleEmail(event) {
        this.email = event.target.value;
        this.checkSubmittable();
    }

    handleFirstName(event) {
        this.firstName = event.target.value;
        this.checkSubmittable();
    }

    handleLastName(event) {
        this.lastName = event.target.value;
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
                "firstName":this.firstName,
                "lastName":this.lastName,
                "email":this.email,
                "groupName":this.groupName
            };
            
            await handleRegistration({registrantJSON: JSON.stringify(registrant)});
            this.showForm = false;
            this.showSuccess =true;
            this.showSpinner = false;
        } catch (error) {
            this.showSpinner = false;
            // let errorData = JSON.parse(error.body.message);
            console.log('error',error);
            handleError(error); 
        }       

    }

    checkSubmittable() {
        console.log('update submit entered');

        let email = this.template.querySelector('.email-input');

        if (this.firstName && this.lastName && this.groupName && this.email && (email.validity.valid === true)) {
            console.log('baseline fields valid');           
            this.registerDisabled = false;
        } else {
            this.registerDisabled = true;
        }
    }
}