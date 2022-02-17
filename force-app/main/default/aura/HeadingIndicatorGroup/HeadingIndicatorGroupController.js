({
	collapseIndicatorGroup : function(cmp, event, helper) {
        $A.util.addClass(cmp.find("collapse-group"), 'slds-hide');
        $A.util.removeClass(cmp.find("expand-group"), 'slds-hide');
		var cmpEvent = cmp.getEvent("collapseIndicatorGroup");
        cmpEvent.fire();
        //debugger;
	},
	expandIndicatorGroup : function(cmp, event, helper) {
        $A.util.addClass(cmp.find("expand-group"), 'slds-hide');
        $A.util.removeClass(cmp.find("collapse-group"), 'slds-hide');
		var cmpEvent = cmp.getEvent("expandIndicatorGroup");
        cmpEvent.fire();
        //debugger;
	},
})