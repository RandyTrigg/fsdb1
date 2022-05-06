public class InviteCloneProposalInvocable {
    @InvocableMethod(
        label='New proposal by copying an invite\'s prior proposal'
        description='New proposal by copying an invite\'s prior proposal'
    )
    // Expects to be called with a single invite Id (the list parameter is required for invocable methods)
    public static void cloneProposal(List<Id> inviteIds) {
        InviteController.cloneProposal(inviteIds[0]);
    }
}