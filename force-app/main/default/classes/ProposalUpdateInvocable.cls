public class ProposalUpdateInvocable {
    @InvocableMethod(label='Update proposal' description='Update proposal')
    public static void updateProposal(List<Id> proposalIds) {
        // Note that we don't do the update under test methods.
        for (Id pId : proposalIds)
            if (!Test.isRunningTest())
                ProposalUpdate.updateProposal(pId);
    }
}