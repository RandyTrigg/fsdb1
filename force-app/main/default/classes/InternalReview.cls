public with sharing class InternalReview extends Review{
    public String name;
    public Id accountId;
    public String accountName;
    public Date dateReceived;
    public String status;
    public String statusExternal;
    public String proposalAppType;
    public String proposalGrantType;
    public String milestoneType;


    public InternalReview(Id recordId) {
        // is this a proposal review or a milestone review?
        String objName = Utilities.objectNameFromRecordId(recordId);
        System.debug('objName: '+objName);

        if (objName=='Proposal__c') {
            Proposal__c prop = [SELECT ID, Account__r.Name, Account__c, Status__c, Status_external__c, Date_declined__c, Date_awarded__c, Date_received__c, App_type__c FROM Proposal__c WHERE ID=:recordId];
            this.type = 'Proposal';
            this.accountId = prop.Account__c;
            this.accountName = prop.Account__r.Name;
            this.status = prop.Status__c;
            this.statusExternal = prop.Status_external__c;
            this.dateReceived = prop.Date_received__c;
            this.proposalGrantType = prop.Grant_type__c;
            this.proposalAppType = prop.App_type__c;
            // Determine Review Form
            this.reviewFormId = getProposalReviewForm();
            System.debug('this.reviewFormId: '+this.reviewFormId);
            
            loadProposal(recordId);
            
        } else if (objName=='Milestone__c') {
            Milestone__c milestone = [SELECT ID, Name, Type__c, Date_submitted__c, Proposal__c, Proposal__r.Grant_type__c, Proposal__r.App_type__c, Proposal__r.Account__c, Proposal__r.Account__r.Name, Milestone_Spec__r.Review_Form__c FROM Milestone__c WHERE ID=:recordId];
            this.type = 'Milestone';
            this.accountId = milestone.Proposal__r.Account__c;
            this.accountName = milestone.Proposal__r.Account__r.Name;
            this.dateReceived = milestone.Date_submitted__c;
            this.milestoneType = milestone.Type__c;
            this.proposalGrantType = milestone.Proposal__r.Grant_type__c;
            this.proposalAppType = milestone.Proposal__r.App_type__c;
            // Determine Review Form
            this.reviewFormId = getMilestoneReviewForm(milestone);
            loadMilestone(recordId);
            System.debug('this.reviewFormId: '+this.reviewFormId);
            
        } else if (objName=='Profile__c') {
            Profile__c prof = [SELECT ID, Account__c, Account__r.Name, Status__c, Status_external__c, Date_submitted__c, Date_declined__c, Date_review_completed__c FROM Profile__c WHERE ID=:recordId];
            List < Review_Form__c > profileReviewForm;
            try {
                profileReviewForm = [SELECT ID, Name FROM Review_Form__c WHERE Name='Profile' LIMIT 1];
            } catch (Exception e) {
                throw new GFW_Exception('InternalReview.Constructor', 'No Review Form named "Profile" found.  Cannot load Profile Review', e);
            }
            
            this.type = 'Profile';
            this.accountId = prof.Account__c;
            this.accountName = prof.Account__r.Name;
            this.status = prof.Status__c;
            this.statusExternal = prof.Status_external__c;
            this.dateReceived = prof.Date_submitted__c;
            this.reviewFormId = profileReviewForm[0].Id;
            loadProfile(recordId);
        }

        // Initialize Maps and lists
        formComponents = new List < FormComponent >();
        indicatorAssignMap = new Map < String, Map < String, IndicatorAssign > >();
        classificationAssignMap = new Map < String, List < ClassificationAssign > >();
        portfolioAssignments = new List < PortfolioAssign >();

        loadReviewFormComponents();
        loadPortfolioAssigns();
        loadProfilePortfolioAssigns();
        loadIndicatorAssigns();
        loadClassificationAssigns();
        finishFormComponentBuild();
       
    }

    public void submit() {
        try {
            Date today = System.today();

            // Update the Milestone or Proposal Review Completion Date if not already filled in
            if (this.type == 'Milestone') {
                if (this.linkedMilestone.Date_reviewed__c==null) {
                    Milestone__c m = new Milestone__c (
                        Id=this.linkedMilestone.Id,
                        Date_reviewed__c = today
                    );
                    update m;
                }
            } else if (this.type == 'Proposal') {
                if (this.linkedProposal.Date_review_completed__c==null) {
                    Proposal__c prop = new Proposal__c (
                        Id=this.linkedProposal.Id,
                        Date_review_completed__c = today
                    );
                    update prop;
                }
            } else if (this.type == 'Profile') {
                if (this.linkedProfile.Date_review_completed__c==null) {
                    Profile__c prof = new Profile__c (
                        Id=this.linkedProfile.Id,
                        Date_review_completed__c = today
                    );
                    update prof;
                }
            }
        } catch (Exception e) {
            throw new GFW_Exception('InternalReview.submit', 'Review Submit Failed, please refresh and try again.', e);
        }


    }

    //todo: default review form
    private ID getProposalReviewForm() {
        // First, get all the active review forms.
        Review_Form__c[] reviewForms = [SELECT Id, Name FROM Review_Form__c WHERE Active__c = true];
        

        Map<String, Review_Form__c> rfMap = new Map<String, Review_Form__c> ();
        for (Review_Form__c rf : reviewForms) rfMap.put(rf.Name, rf);
        System.debug('rfMap: '+rfMap);

        // Try first to find a review form for the proposal's app type, else use standard.
        String baseFormName = 'Proposal' + this.proposalAppType;
        System.debug('baseFormName: '+baseFormName);
        Id baseFormId;
        if (rfMap.containsKey(baseFormName)) {
            baseFormId = rfMap.get(baseFormName).Id;
        } else if (rfMap.containsKey('ProposalStandard')) {
            baseFormId = rfMap.get('ProposalStandard').Id;
        }    
        System.debug('baseFormId: '+baseFormId);  
        
        return baseFormId;
    }

    private ID getMilestoneReviewForm(Milestone__c milestone) {
        //First check and see if the form behind the milestone links to a review form.  If so, use that form
        if (milestone.Milestone_Spec__r.Review_Form__c !=null) {
            return milestone.Milestone_Spec__r.Review_Form__c;
        } else {
            // First, get all the active review forms.
            Review_Form__c[] reviewForms = [SELECT Id, Name FROM Review_Form__c WHERE Active__c = true];
            Map<String, Review_Form__c> rfMap = new Map<String, Review_Form__c> ();
            for (Review_Form__c rf : reviewForms) rfMap.put(rf.Name, rf);

            // Find an appropriate review form based on app type, grant type, and whether the account is WF.
            Id baseFormId;

            String baseFormName = 'Report' + (this.proposalGrantType == 'Crisis' ? 'Crisis' : this.proposalAppType);

            Id formId = rfMap.containsKey(baseFormName +this.milestoneType) ? rfMap.get(baseFormName +this.milestoneType).Id :
                    rfMap.containsKey(baseFormName) ? rfMap.get(baseFormName).Id : 
                    rfMap.containsKey('ReportStandard' +this.milestoneType) ? rfMap.get('ReportStandard' +this.milestoneType).Id : 
                    rfMap.containsKey('ReportStandard') ? rfMap.get('ReportStandard').Id : 
                    null;

            return formId;
        }
        
    }
}