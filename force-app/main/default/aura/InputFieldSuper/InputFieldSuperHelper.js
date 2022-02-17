({
	errorMessageChange : function(cmp, event) {
        console.log('InputFieldSuperHelper errorMessageChange');
        if(cmp.get("v.errorMessage")) {
            $A.util.addClass(cmp.find("formElement"), 'slds-has-error');
            $A.util.removeClass(cmp.find("errorSpan"), 'slds-hide');
        } else {
            $A.util.removeClass(cmp.find("formElement"), 'slds-has-error');
            $A.util.addClass(cmp.find("errorSpan"), 'slds-hide'); 
        }
	},
})