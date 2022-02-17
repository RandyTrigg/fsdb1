({
    doInit: function(component, event, helper) {
        console.log('MilestoneEditController doInit');
        helper.init(component);
    },
    expandIndicatorGroup: function(cmp, event, helper) {
        cmp.set('v.expanded', true);
    },
    collapseIndicatorGroup: function(cmp, event, helper) {
        cmp.set('v.expanded', false);
    }
});