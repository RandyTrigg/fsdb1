@isTest
public without sharing class InternalReviewTest {
    

    @isTest
    static void proposalReviewTest() {

        String proposalId = setupProposalData();
        InternalReview rev = new InternalReview(proposalId);

        // Submit the Review
        rev.submit();

        Proposal__c prop = [SELECT ID, Date_review_completed__c FROM Proposal__c WHERE ID=:proposalId];

        Date today = System.today();
        System.assertEquals(today, prop.Date_review_completed__c);

    }

    @isTest
    static void profileReviewTest() {

        String profileId = setupProfileData();
        InternalReview rev = new InternalReview(profileId);

        // Submit the Review
        rev.submit();

        Profile__c prof = [SELECT ID, Date_review_completed__c FROM Profile__c WHERE ID=:profileId];

        Date today = System.today();
        System.assertEquals(today, prof.Date_review_completed__c);

    }

    @isTest
    static void milestoneReviewTest() {
        String milestoneId = setupMilestoneData();
        InternalReview rev = new InternalReview(milestoneId);

        // Submit the review
        rev.submit();

        Milestone__c rep = [SELECT ID, Date_reviewed__c FROM Milestone__c WHERE ID=:milestoneId];

        Date today = System.today();
        System.assertEquals(today, rep.Date_reviewed__c);
    }

    @isTest
    static void controllerTest() {
        String proposalId = setupProposalData();

        String reviewJson = ReviewFormController.getInternalReview(proposalId);
        InternalReview revWraqpper = (InternalReview)JSON.deserialize(reviewJson, InternalReview.class);
        System.assertEquals(proposalId, revWraqpper.linkedProposal.Id);

        ReviewFormController.submitInternalReview(proposalId);

        Proposal__c prop = [SELECT ID, Date_review_completed__c FROM Proposal__c WHERE ID=:proposalId];

        Date today = System.today();
        System.assertEquals(today, prop.Date_review_completed__c);

    }

    static String setupMilestoneData(){
        Region__c reg = new Region__c (Name = 'test region');
        insert reg;
        insert new Country__c (Name = 'test country', Region__c = reg.Id);

        Account a = new Account (Name = 'test account', GM_region__c = reg.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        insert a;

        Proposal__c p = new Proposal__c (Account__c = a.Id, App_type__c = 'Standard');
        insert p;

        Milestone__c gr = new Milestone__c (Proposal__c=p.Id);    
        insert gr;   

        GM_Data__c gmData = new GM_Data__c (Account__c = a.Id, Proposal__c = p.Id);
        insert gmData;

        Classification__c cl =  new Classification__c (Name = 'test classification', Type__c = 'Population');
        insert cl;

        Indicator__c ind = new Indicator__c (Name = 'Increased Awareness', Outcome_type__c = 'Awareness', Active__c=true);
        insert ind;

        Review_Form__c rf = new Review_Form__c (Name = 'ReportStandard', Active__c=true);
        insert rf;

        List < Review_Form_Component__c > components = new List < Review_Form_Component__c > ();

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'HeadingMedium',
            Label__c = 'Heading Content',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'HeadingSmall',
            Label__c = 'Heading Content',
            Sort_number__c = 3
        ));
       
        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id,
            Active__c = true,
            Lightning_component_name__c = 'InputCheckbox',
            Label__c = 'input checkbox label',
            Object_name__c = 'GM_Data__c',
            Field_name__c = 'Story_individual__c',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelect',
            Label__c = 'input select label',
            Object_name__c = 'Milestone__c',
            Field_name__c = 'Quality_of_report_ranking__c',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputTextArea',
            Label__c = 'input text area label',
            Help_text__c = 'help text',
            Object_name__c = 'GM_Data__c',
            Field_name__c = 'Resource_mobilization_comment__c',
            Sort_number__c = 2
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'IndicatorGroup',
            Label__c = 'Indicator Group label',
            Help_text__c = 'help text',
            Join_object_name__c = 'Indicator_Assign__c',
            Join_object_type__c = 'Awareness__c',
            Indicator_outcome_type__c = 'Awareness',
            Sort_number__c = 2
        ));

        insert components;
        return gr.Id;
    }

    static String setupProposalData() {
        // Build a country record.
        Region__c reg = new Region__c (Name = 'test region');
        insert reg;
        insert new Country__c (Name = 'test country', Region__c = reg.Id);

        Account a = new Account (Name = 'test account', GM_region__c = reg.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        insert a;

        Proposal__c p = new Proposal__c (Account__c = a.Id, App_type__c = 'Standard');
        insert p;

        GM_Data__c gmData = new GM_Data__c (Account__c = a.Id, Proposal__c = p.Id);
        insert gmData;

        Classification__c cl =  new Classification__c (Name = 'test classification', Type__c = 'Population');
        insert cl;

        Portfolio__c porfolio = new Portfolio__c (Name = 'test portfolio', Type__c = 'Priority', Active__c=true);
        insert porfolio;

        Review_Form__c rf = new Review_Form__c (Name = 'ProposalStandard', Active__c=true);
        insert rf;

        Decline_Reason__c dr = new Decline_Reason__c (Name = '1A US-based group',Active__c=true);
        insert dr;

        List < Review_Form_Component__c > components = new List < Review_Form_Component__c > ();

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'HeadingMedium',
            Label__c = 'Heading Content',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'HeadingSmall',
            Label__c = 'Heading Content',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'Label',
            Label__c = 'Label Content',
            Sort_number__c = 3
        ));
        
        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id,
            Active__c = true,
            Lightning_component_name__c = 'InputCheckbox',
            Label__c = 'input checkbox label',
            Object_name__c = 'Proposal__c',
            Field_name__c = 'CFO_approved__c',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelect',
            Label__c = 'input select label',
            Object_name__c = 'GM_Data__c',
            Field_name__c = 'Org_capacity_risk_level__c',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelectLookup',
            Label__c = 'input select lookup label',
            Object_name__c = 'Proposal__c',
            Field_name__c = 'Decline_reason_1__c',
            Sort_number__c = 3
        ));
        
        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelectMulti1',
            Label__c = 'Populations',
            Join_object_name__c = 'Classification_Assign__c',
            Join_object_type__c = 'Population',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelectMulti1',
            Label__c = 'Portfolios',
            Join_object_name__c = 'Portfolio_Assignment__c',
            Sort_number__c = 3
        ));


        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputTextArea',
            Label__c = 'input text area label',
            Help_text__c = 'help text',
            Object_name__c = 'GM_Data__c',
            Field_name__c = 'Resource_mobilization_comment__c',
            Sort_number__c = 2
        ));

        insert components;

        return p.Id;
    }

    static String setupProfileData() {
        // Build a country record.
        Region__c reg = new Region__c (Name = 'test region');
        insert reg;

        Account a = new Account (Name = 'test account', GM_region__c = reg.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        insert a;

        Profile__c prof = new Profile__c (Account__c=a.Id);
        insert prof;

        Classification__c cl =  new Classification__c (Name = 'test classification', Type__c = 'Issue');
        insert cl;

        Portfolio__c porfolio = new Portfolio__c (Name = 'test portfolio', Type__c = 'Priority', Active__c=true);
        insert porfolio;

        Review_Form__c rf = new Review_Form__c (Name = 'Profile', Active__c=true);
        insert rf;

        Decline_Reason__c dr = new Decline_Reason__c (Name = '1A US-based group',Active__c=true);
        insert dr;

        List < Review_Form_Component__c > components = new List < Review_Form_Component__c > ();

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'HeadingMedium',
            Label__c = 'Heading Content',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'HeadingSmall',
            Label__c = 'Heading Content',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'Label',
            Label__c = 'Label Content',
            Sort_number__c = 3
        ));
        
        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id,
            Active__c = true,
            Lightning_component_name__c = 'InputCheckbox',
            Label__c = 'input checkbox label',
            Object_name__c = 'Profile__c',
            Field_name__c = 'Intersectional_analysis__c',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelect',
            Label__c = 'input select label',
            Object_name__c = 'Profile__c',
            Field_name__c = 'Girl_centered_org__c',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelectLookup',
            Label__c = 'input select lookup label',
            Object_name__c = 'Profile__c',
            Field_name__c = 'Decline_reason_1__c',
            Sort_number__c = 3
        ));
        
        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelectMulti1',
            Label__c = 'Populations/Beneficiaries',
            Join_object_name__c = 'Classification_Profile_Assign__c',
            Join_object_type__c = 'Population',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelectMulti1',
            Label__c = 'Portfolios',
            Join_object_name__c = 'Portfolio_Profile_Assign__c',
            Sort_number__c = 3
        ));


        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputTextArea',
            Label__c = 'input text area label',
            Help_text__c = 'help text',
            Object_name__c = 'Profile__c',
            Field_name__c = 'Overall_alignment__c',
            Sort_number__c = 2
        ));

        insert components;

        return prof.Id;
    }


    @isTest
    static void getInternalReviewVFPageNameTest() {
        String result = ReviewFormController.getInternalReviewVFPageName();
        System.assertEquals(true, result.contains('Applications'));
    }


}