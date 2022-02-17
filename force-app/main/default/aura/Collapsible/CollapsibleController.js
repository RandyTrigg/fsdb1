({
	expand : function(cmp, event, helper) {
        cmp.set("v.expanded", true);
	},
	collapse : function(cmp, event, helper) {
        cmp.set("v.expanded", false);
	},
})