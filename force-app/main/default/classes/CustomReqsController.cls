public class CustomReqsController {
    private String recordId;
    private ApexPages.StandardController standardController;

    public CustomReqsController(ApexPages.StandardController controller) {
        this.standardController = controller;
        recordId = controller.getRecord().Id;
    }

    public PageReference deepClone() {
        // Invoke the custom reqs deep clone code.
        Id cloneId = cloneCustomReqs(recordId);
        // Navigate to the cloned form record, or stay here if no clone.
        Id destId = cloneId != null ? cloneId : recordId;
        PageReference p = new PageReference('/' + destId);
        p.setRedirect(true);
        return p;
    }

    public PageReference doCancel() {
        return standardController.cancel();
    }

    /**********************************
     * For general use
     *********************************/

    // Clone a custom reqs record together with its milestone specs and template pieces.
    // Return the Id of the clone or null if operation failed.
    public static Id cloneCustomReqs(Id cReqsId) {
        // Fetch all fields from custom reqs record and its children to facilitate cloning.
        Custom_reqs__c cReqs = (Custom_reqs__c) Utilities.fetchRecord(
            'Custom_reqs__c',
            cReqsId,
            null
        );
        if (cReqs == null)
            return null;
        String reportSpecQ =
            'SELECT ' +
            String.join(
                Utilities.fieldNamesForObject('Milestone_spec__c'),
                ', '
            ) +
            ' FROM Milestone_spec__c' +
            ' WHERE Custom_reqs__c = : cReqsId';
        Milestone_spec__c[] ms = Database.query(reportSpecQ);
        String templatePieceQ =
            'SELECT ' +
            String.join(
                Utilities.fieldNamesForObject('Template_Piece__c'),
                ', '
            ) +
            ' FROM Template_Piece__c' +
            ' WHERE Custom_reqs__c = : cReqsId';
        Template_Piece__c[] tps = Database.query(templatePieceQ);
        sObject[] toInsert = new List<sObject>();
        // Clone custom reqs, change name.
        Custom_reqs__c cReqsNew = cReqs.clone(false, true);
        if (cReqsNew == null)
            return null;
        cReqsNew.Name = cReqs.Name + ' (Copy)';
        insert cReqsNew;
        // Clone child milestone specs and template pieces, and link to new custom reqs.
        for (Milestone_spec__c m : ms) {
            Milestone_spec__c mNew = m.clone(false, false);
            mNew.Custom_reqs__c = cReqsNew.Id;
            toInsert.add(mNew);
        }
        for (Template_Piece__c tp : tps) {
            Template_Piece__c tpNew = tp.clone(false, false);
            tpNew.Custom_reqs__c = cReqsNew.Id;
            tpNew.Revise__c = true; // Every cloned template piece defaults to needing to be checked.
            toInsert.add(tpNew);
        }
        if (toInsert.size() > 0)
            insert toInsert;
        return cReqsNew.Id;
    }
}