global with sharing class ReparentChildrenInvocable {
    @InvocableMethod(
        label='Reparent the children of one record to another record.'
        description='Reparent the children of one record to another record.'
    )
    global static void reparentChildren(
        List<ReparentChildrenRequest> requests
    ) {
        for (ReparentChildrenRequest request : requests) {
            handleRequest(request);
        }
    }

    // Reparent the children.
    private static void handleRequest(ReparentChildrenRequest request) {
        system.debug('handleRequest: request = ' + JSON.serialize(request));
        Utilities.reparentChildren(
            request.srcId,
            request.targetId,
            new List<Id>()
        );
    }

    global with sharing class ReparentChildrenRequest {
        @InvocableVariable(required=true)
        public Id srcId;
        @InvocableVariable(required=true)
        public Id targetId;
    }
}