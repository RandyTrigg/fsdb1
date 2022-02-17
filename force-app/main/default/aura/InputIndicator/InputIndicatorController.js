({
	doInit : function(cmp, event, helper) {
        helper.init(cmp, event);		
	},
    hideIndicator : function(cmp, event, helper) {
        $A.util.addClass(cmp.find("indicatorContent"), 'slds-hide');
    },
    showIndicator : function(cmp, event, helper) {
        $A.util.removeClass(cmp.find("indicatorContent"), 'slds-hide');
    },
})