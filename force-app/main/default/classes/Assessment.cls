public with sharing class Assessment extends Review {
    
    public String name;
    public Id accountId;
    public Id Id;
    public String accountName;
    public Id advisorId;
    public Id advisorTermId;
    public Date dateSubmitted;
    public String status;
    public String statusExternal;


    public Assessment(Id assessmentId) {
        try {
            Assessment__c assess = [SELECT Id, Name, Account__c, Account__r.Name, Advisor__c, Advisor__r.Name, Advisor_Term__c, Date_submitted__c, Milestone__c, Portfolio__c, Profile__c, Proposal__c, Review_Form__c, Status__c, Status_external__c FROM Assessment__c WHERE ID=:assessmentId];

            // if there is no linked review form, there is nothing to load
            if (assess.Review_Form__c !=null ) {
                this.Id = assess.Id;
                this.name = assess.Name;
                this.accountId = assess.Account__c;
                this.reviewerName = assess.Advisor__r.Name;
                this.accountName = assess.Account__r.Name;
                this.advisorId = assess.Advisor__c;
                this.advisorTermId = assess.Advisor_Term__c;
                this.dateSubmitted = assess.Date_submitted__c;
                this.status = assess.Status__c;
                this.statusExternal = assess.Status_external__c;
                this.reviewFormId = assess.Review_Form__c;
                // Initialize Maps and lists
                indicatorAssignMap = new Map < String, Map < String, IndicatorAssign > >();
                classificationAssignMap = new Map < String, List < ClassificationAssign > >();
                formComponents = new List < FormComponent >();
                portfolioAssignments = new List < PortfolioAssign >();
    
                if (assess.Milestone__c!=null) {
                    this.type = 'Milestone';
                    loadMilestone(assess.Milestone__c);
                } else if (assess.Profile__c!=null) {
                    this.type = 'Profile';
                    loadProfile(assess.Profile__c);
                } else {
                    this.type = 'Proposal';
                    loadProposal(assess.Proposal__c);
                }
    
                loadReviewFormComponents();
                loadPortfolioAssigns();
                loadProfilePortfolioAssigns();
                loadIndicatorAssigns();
                loadClassificationAssigns();
                finishFormComponentBuild();
            }

        } catch (Exception e) {
            throw new GFW_Exception ('Assessment.IdConstructor', 'Could Not load the requested Assessment.', e);
        }
        
    }

    public void submit() {
        try {
            Date today = System.today();
            this.dateSubmitted = today;

            //Update Assessment Submitted Date
            Assessment__c completedAssessment = new Assessment__c (
                ID=this.Id,
                Date_submitted__c=today
            );
            update completedAssessment;

            // Update the Milestone or Proposal Review Completion Date if not already filled in
            if (this.type=='Milestone') {
                if (this.linkedMilestone.Date_reviewed__c==null) {
                    Milestone__c m = new Milestone__c (
                        Id=this.linkedMilestone.Id,
                        Date_reviewed__c = today
                    );
                    update m;
                }
            } else if (this.type=='Proposal') {
                if (this.linkedProposal.Date_review_completed__c==null) {
                    Proposal__c prop = new Proposal__c (
                        Id=this.linkedProposal.Id,
                        Date_review_completed__c = today
                    );
                    update prop;
                }
            } else if (this.type=='Profile') {
                if (this.linkedProfile.Date_review_completed__c==null) {
                    Profile__c prof = new Profile__c (
                        Id=this.linkedProfile.Id,
                        Date_review_completed__c = today
                    );
                    update prof;
                }
            }
        } catch (Exception e) {
            throw new GFW_Exception('Assessment.submit', 'Review Submit Failed, please refresh and try again.', e);
        }
        
    }
}