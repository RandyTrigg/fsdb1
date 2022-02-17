({
    getInfo: function (cmp) {
        // Fetch the invite and related records.
        cmp.set('v.waiting', true);
        var action = cmp.get('c.getInfo');
        action.setParams({
            inviteId: cmp.get('v.recordId')
        });
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                var returnVal = JSON.parse(response.getReturnValue());
                //console.log('In getInfo: returnVal = ' +JSON.stringify(returnVal));
                cmp.set('v.propToClone', returnVal.results.propToClone);
                var i = returnVal.results.invite;
                cmp.set('v.invite', i);
                //console.log('In getInfo: invite = ' +cmp.get("v.invite"));
                cmp.set('v.alloc', i.Allocation__r);
                cmp.set('v.profile', i.Profile__r);
                cmp.set('v.customReqs', i.Allocation__r.Custom_Reqs__r);
                this.setWarningsAndErrors(cmp);
                cmp.set('v.inviteLoaded', true);
                cmp.set('v.waiting', false);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'Error message: ' + JSON.stringify(response.getError())
                );
            }
        });
        $A.enqueueAction(action);
    },

    setWarningsAndErrors: function (cmp) {
        var i = cmp.get('v.invite');
        var propToClone = cmp.get('v.propToClone');
        var alloc = i.Allocation__r;
        var errMessage = i.Proposal__c
            ? 'A new proposal may not be created, because this invite record already has a linked proposal.'
            : i.Status_numeric__c < 4
            ? "This invite is not ready for a proposal as its invite's status is less than 4. " +
              "Date approved must be non-blank as well as the allocation's Date invite specs completed."
            : null;
        if (errMessage)
            errMessage +=
                ' Please direct any questions to the Grantmaking systems administrator.';
        cmp.set('v.errMessage', errMessage);
        var pr = cmp.get('v.profile');
        var profileWarning = !pr
            ? 'The invite has no linked profile.'
            : pr.Next_profile__c
            ? 'The linked profile has expired.'
            : !pr.Date_submitted__c
            ? 'The linked profile has not been submitted.'
            : !pr.Date_review_completed__c
            ? 'The linked profile has not been reviewed.'
            : null;
        if (profileWarning)
            profileWarning += ' Click Continue if you want to proceed anyway.';
        cmp.set('v.profileWarning', profileWarning);
        cmp.set('v.readyToBuildProposal', !errMessage && !profileWarning);
        cmp.set(
            'v.buildProposalTitle',
            propToClone
                ? 'Clone specified proposal'
                : 'Build proposal without form (offline)'
        );
        cmp.set(
            'v.buildProposalText',
            propToClone
                ? 'The new proposal will be created by cloning proposal ' +
                      propToClone.Name +
                      '.'
                : "The new proposal will be created from the default values for this invite's Allocation record WITHOUT an online form."
        );
        cmp.set('v.invitationDeadline', alloc.Date_prop_due__c);
        cmp.set(
            'v.awardNotificationDeadline',
            alloc.Date_of_award_notification__c
        );
    },

    cloneProposal: function (cmp) {
        // Build a new proposal.
        cmp.set('v.waiting', true);
        var action = cmp.get('c.cloneProposal');
        action.setParams({
            inviteId: cmp.get('v.recordId')
        });
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                var returnVal = JSON.parse(response.getReturnValue());
                cmp.set('v.proposal', returnVal.results.proposal);
                cmp.set('v.waiting', false);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'Error message: ' + JSON.stringify(response.getError())
                );
            }
        });
        $A.enqueueAction(action);
    },

    newProposal: function (cmp) {
        // Build a new proposal.
        cmp.set('v.waiting', true);
        var action = cmp.get('c.newProposal');
        action.setParams({
            jsonString: JSON.stringify({
                inviteId: cmp.get('v.recordId'),
                invitationDeadline: cmp.get('v.invitationDeadline'),
                awardNotificationDeadline: cmp.get(
                    'v.awardNotificationDeadline'
                )
            })
        });
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (cmp.isValid() && state === 'SUCCESS') {
                var returnVal = JSON.parse(response.getReturnValue());
                //console.log('In newProposal: returnVal = ' +JSON.stringify(returnVal));
                cmp.set('v.proposal', returnVal.results.proposal);
                cmp.set('v.waiting', false);
            } else if (cmp.isValid() && state === 'ERROR') {
                console.log(
                    'Error message: ' + JSON.stringify(response.getError())
                );
            }
        });
        $A.enqueueAction(action);
    },

    closeWindow: function () {
        $A.get('e.force:closeQuickAction').fire();
    }
});