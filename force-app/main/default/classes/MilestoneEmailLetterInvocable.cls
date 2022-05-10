global class MilestoneEmailLetterInvocable {
    @InvocableMethod(
        label='Build/email milestone letter'
        description='Build a new milestone letter of given template, and email it.'
    )
    global static void buildAndEmailLetter(List<EmailLetterRequest> requests) {
        for (EmailLetterRequest request : requests) {
            handleRequest(request);
        }
    }

    // Build and email milestone letter.
    private static void handleRequest(EmailLetterRequest request) {
        system.debug('handleRequest: request = ' + JSON.serialize(request));
        MilestoneController.buildAndEmailLetter(
            request.mId,
            request.templateId
        );
    }

    global class EmailLetterRequest {
        @InvocableVariable(required=true)
        public Id mId;
        @InvocableVariable(required=true)
        public Id templateId;
    }
}