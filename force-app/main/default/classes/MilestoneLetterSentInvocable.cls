global with sharing class MilestoneLetterSentInvocable {
    @InvocableMethod(
        label='Actions when milestone letter sent'
        description='Actions when milestone letter sent'
    )
    global static void letterSent(List<MilestoneLetterSentRequest> requests) {
        for (MilestoneLetterSentRequest request : requests) {
            handleRequest(request);
        }
    }

    // Build and email milestone letter.
    private static void handleRequest(MilestoneLetterSentRequest request) {
        system.debug('handleRequest: request = ' + JSON.serialize(request));
        MilestoneController.letterSent(request.letterId);
    }

    global with sharing class MilestoneLetterSentRequest {
        @InvocableVariable(required=true)
        public Id letterId;
    }
}