({
    doInit: function(component, event, helper) {
        console.log('MilestoneEditController doInit');
        helper.init(component);
    },
    save: function(component, event, helper) {
        helper.save(component);
    },
    submitReview: function(component, event, helper) {
        helper.submitReview(component);
    }
});