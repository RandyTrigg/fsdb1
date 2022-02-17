({
    inviteRecordUpdated: function(cmp, event, helper) {
        console.log('inviteRecordUpdated: ...');
        helper.getInfo(cmp);
    },

    handleProfileWarningContinue: function(cmp, event, helper) {
        console.log('handleProfileWarningContinue: ...');
        cmp.set("v.profileWarningContinued", true);
        cmp.set("v.readyToBuildProposal", true);
    },
    
    handleBuildProposalGo: function(cmp, event, helper) {
        console.log('handleBuildProposalGo: ...');
        if (cmp.find("invitationDeadline")) cmp.set("v.invitationDeadline", cmp.find("invitationDeadline").get("v.value"));
        if (cmp.find("awardNotificationDeadline")) cmp.set("v.awardNotificationDeadline", cmp.find("awardNotificationDeadline").get("v.value"));
        var i = cmp.get("v.invite");
        if (i.Proposal_to_clone__c) helper.cloneProposal(cmp);
        else helper.newProposal(cmp);
    },

    handleCancel: function(cmp, event, helper) {
        console.log('handleCancel: ...');
        helper.closeWindow();
    },
    
})