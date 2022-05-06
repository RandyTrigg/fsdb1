global class InvitesAllocationsForRstInvocable {
    @InvocableMethod(
        label='Build invites and allocations for charges on a fund'
        description='Build invites and allocations for charges on a fund'
    )
    global static void newInvitesAllocations(
        List<NewInvsAllocsRequest> requests
    ) {
        for (NewInvsAllocsRequest request : requests) {
            handleRequest(request);
        }
    }

    // Update target field specified by given form data.
    private static void handleRequest(NewInvsAllocsRequest request) {
        system.debug('handleRequest: request = ' + JSON.serialize(request));
        InviteController.newAllocationsInvitesForFund(request.fundId);
    }

    global class NewInvsAllocsRequest {
        @InvocableVariable(required=true)
        public Id fundId;
    }
}