public with sharing class AdvisorSummary {

    public Boolean hasForms = false;
    public Boolean hasMilestones = false;
    public Boolean hasProfiles = false;
    public Boolean hasProposals = false;
    public Boolean hasRatings = false;
    public Integer formsCount = 0;
    public Integer pendingMilestonesCount = 0;
    public Integer pendingProfilesCount = 0;
    public Integer pendingProposalsCount = 0;
    public Integer pendingRatingsCount = 0;
    public Integer priorityMCount = 0;
    public Integer priorityProfileCount =0;
    public Integer priorityProposalCount = 0;
    public Integer totalPendingItems = 0;
    public Integer totalPriorityItems = 0;
    public String firstName;
    public String fullName;
    public String lastName;
    public String preferredLanguage;

    public List < ItemSummary > milestoneReviewsAssigned;
    public List < ItemSummary > profileReviewsAssigned;
    public List < ItemSummary > proposalReviewsAssigned;
    public List < ItemSummary > ratingsAssigned;
    public List < ItemSummary > viewFormsAvailable;
    
    
    public class ItemSummary {
        public Boolean isPriority;
        public Date dateValue;
        public ID sfId;
        public String dateDescription;
        public String detail1;
        public String detail1Label;
        public String detail2;
        public String detail2Label;
        public String linkURL;
        public String objectName;
        public String title;
        public String titleLabel;
    }

    public AdvisorSummary(String advisorId) {
        
        Advisor__c advRecord = [SELECT ID, Language__c, (SELECT ID, Type__c, Status_external__c, Portfolio__c FROM Advisor_Terms__r WHERE Status_external__c='Active') FROM Advisor__c WHERE ID=:advisorId];

        this.fullName = System.UserInfo.getName();
        this.firstName = System.UserInfo.getFirstName();
        this.lastName = System.UserInfo.getLastName();
        this.preferredLanguage = advRecord.Language__c;

        this.milestoneReviewsAssigned = new List <ItemSummary>();
        this.proposalReviewsAssigned = new List <ItemSummary>();
        this.profileReviewsAssigned = new List <ItemSummary>();
        this.ratingsAssigned = new List <ItemSummary>();
        this.viewFormsAvailable = new List <ItemSummary>();
        

        List < Assessment__c > milestoneAssessments = AssessorSiteController.getMilestoneAssessments(advisorId, 'pending', 3);
        this.pendingMilestonesCount = milestoneAssessments.size();
        
        Integer allMs = [SELECT COUNT()
                            FROM Assessment__c
                            WHERE Advisor__c=:advisorId
                            AND Form__c=null
                            AND Milestone__c!=null];
        
        if (allMs>0) {
            this.hasMilestones = true;
        }

        for (Integer i=0; i<3; i++) {
            if (milestoneAssessments.size()>i) {
                ItemSummary mSumm = new ItemSummary();
                mSumm.sfId = milestoneAssessments[i].Id;
                mSumm.objectName = 'Milestone__c';
                mSumm.linkURL = '/lightning/r/Assessment_Detail__c/'+mSumm.sfId+'/view';
                if (milestoneAssessments[i].Milestone__r.Review_priority__c=='2 - High') {
                    mSumm.isPriority = true;
                    this.priorityMCount++; 
                    this.totalPriorityItems++;
                }
                mSumm.titleLabel = 'Milestone #';
                mSumm.title = milestoneAssessments[i].Milestone__r.Name;
                mSumm.detail1Label = 'Organization Name';
                mSumm.detail1 = milestoneAssessments[i].Milestone__r.Account_name__c;
                mSumm.dateDescription = 'Date Recieved';
                mSumm.dateValue = milestoneAssessments[i].Milestone__r.Date_submitted__c;
                milestoneReviewsAssigned.add(mSumm);
            }
        }
        List < Assessment__c > proposalAssessments = AssessorSiteController.getProposalAssessments(advisorId, 'Pending', null);

        this.pendingProposalsCount = proposalAssessments.size();

        Integer allPropReviews = [SELECT COUNT()
                                    FROM Assessment__c
                                    WHERE Advisor__c=:advisorId
                                    AND Form__c=null
                                    AND Milestone__c=null 
                                    AND Profile__c=null
                                    AND Proposal__c!=null];
        if (allPropReviews>0) {
            this.hasProposals = true;
        }

        for (Integer i=0; i<3; i++) {
            if (proposalAssessments.size()>i) {
                ItemSummary prRev = new ItemSummary();
                prRev.sfId = proposalAssessments[i].Id;
                prRev.objectName = 'Proposal__c';
                prRev.linkURL = '/lightning/r/Assessment_Detail__c/${'+prRev.sfId+'}/view';
                //Todo priority logic
                prRev.titleLabel = 'Proposal #';
                prRev.title = proposalAssessments[i].Proposal__r.Name;
                prRev.detail1Label = 'Organization Name';
                prRev.detail1 = proposalAssessments[i].Proposal__r.Account__r.Name;
                prRev.dateDescription = 'Date Recieved';
                prRev.dateValue = proposalAssessments[i].Proposal__r.Date_received__c;
                proposalReviewsAssigned.add(prRev);
            }
        }

        List <Assessment__c> profileAssessments = AssessorSiteController.getProfileAssessments(advisorId, 'Pending', null);

        this.pendingProfilesCount = profileAssessments.size();

        Integer allProfReviews = [SELECT COUNT()
                                    FROM Assessment__c
                                    WHERE Advisor__c=:advisorId
                                    AND Form__c=null
                                    AND Milestone__c=null
                                    AND Profile__c!=null];
        if (allProfReviews>0) {
            this.hasProfiles = true;
        }

        for (Integer i=0; i<3; i++) {
            if (profileAssessments.size()>i) {
                ItemSummary prRev = new ItemSummary();
                prRev.sfId = profileAssessments[i].Id;
                prRev.objectName = 'Profile__c';
                prRev.linkURL = '/lightning/r/Assessment_Detail__c/${'+prRev.sfId+'}/view';
                prRev.titleLabel = 'Profile #';
                prRev.title = profileAssessments[i].Profile__r.Name;
                prRev.detail1Label = 'Applicant';
                prRev.detail1 = profileAssessments[i].Profile__r.Org_name__c;
                prRev.dateDescription = 'Date Received';
                prRev.dateValue = profileAssessments[i].Profile__r.Date_submitted__c;
                profileReviewsAssigned.add(prRev);
            }
        }

        //Load Ratings Assessments
        List <Assessment__c> pendingRatingsAssessments = AssessorSiteController.getRatingAssessments(advisorId, 'Pending', null);

        this.pendingRatingsCount = pendingRatingsAssessments.size();

        Integer ratingsCount = [SELECT COUNT()
                                FROM Assessment__c
                                WHERE Advisor__c=:advisorId
                                AND Form__c!=null]; 
                                
        if (ratingsCount>0) {
            this.hasRatings = true;
        }

        for (Integer i=0; i<3; i++) {
            if (pendingRatingsAssessments.size()>i) {
                ItemSummary ratingSumm = new ItemSummary();
                ratingSumm.sfId = pendingRatingsAssessments[i].Id;
                ratingSumm.objectName = 'Rating';
                ratingSumm.linkURL = '/lightning/r/Assessment_Detail__c/${'+ratingSumm.sfId+'}/view';
                ratingSumm.titleLabel = 'Proposal #';
                ratingSumm.title = pendingRatingsAssessments[i].Proposal__r.Name;
                ratingSumm.detail1Label = 'Organization Name';
                ratingSumm.detail1 = pendingRatingsAssessments[i].Proposal__r.Account__r.Name;
                ratingSumm.dateDescription = 'Date Recieved';
                ratingSumm.dateValue = pendingRatingsAssessments[i].Proposal__r.Date_received__c;
                ratingsAssigned.add(ratingSumm);
            }
        }

        //Load all the viewable forms that this user has available
        List < Invite__c > invites = AssessorSiteController.loadInviteViewForms(advRecord.Advisor_Terms__r,null);
        if (invites!=null) {
            this.formsCount = invites.size();
        } else {
            this.formsCount = 0;
        }

        if (this.formsCount>0) {
            this.hasForms = true;
        }

        for (Integer i=0; i<3; i++) {
            if (invites!=null && invites.size()>i) {
                ItemSummary invItem = new ItemSummary();
                if (invites[i].Proposal__c!=null) {
                    invItem.objectName = 'Proposal__c';
                } else if (invites[i].Profile__c!=null) {
                    invItem.objectName = 'Profile__c';
                }

                invItem.sfId = invites[i].Id;
                invItem.titleLabel = 'Organization Name';
                invItem.title = invites[i].Account__r.Name;
                invItem.detail1Label = 'Proposal #';
                invItem.detail1 = invites[i].Proposal__r.Name;
                invItem.detail2Label = 'Country';
                invItem.detail2 = invites[i].Account__r.GM_country__r.Name;
                viewFormsAvailable.add(invItem);
            }
        }

        this.totalPendingItems = milestoneAssessments.size() + proposalAssessments.size() + profileAssessments.size() + pendingRatingsAssessments.size();

    }
    
}