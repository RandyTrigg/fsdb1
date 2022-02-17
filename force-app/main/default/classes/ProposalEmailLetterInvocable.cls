global class ProposalEmailLetterInvocable {
    @InvocableMethod(
        label='Build/email proposal letter'
        description='Build a new proposal letter of given template, and email it.'
    )
    global static void buildAndEmailLetter(List<EmailLetterRequest> requests) {
        for (EmailLetterRequest request : requests) {
            handleRequest(request);
        }
    }

    // Build and email proposal letter.
    private static void handleRequest(EmailLetterRequest request) {
        system.debug('handleRequest: request = ' + JSON.serialize(request));
        ProposalController.buildAndEmailLetter(
            request.propId,
            request.templateId
        );
    }

    global class EmailLetterRequest {
        @InvocableVariable(required=true)
        public Id propId;
        @InvocableVariable(required=true)
        public Id templateId;
    }
}