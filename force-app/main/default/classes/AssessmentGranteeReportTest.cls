@isTest
public without sharing class AssessmentMilestoneTest {
    
    
    @TestSetup
    static void makeData(){

        // This will set up a Program, Adviosr, Advisor Term
        AdvisorControllerTest.InitTestObjects(1, 1);
        Program__c prog = [SELECT ID, Name FROM Program__c WHERE Name=:'test program'];

        Advisor__c adv = [SELECT ID, Account__c FROM Advisor__c LIMIT 1];

        Account a = new Account (Name = 'test account', GM_program__c = prog.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        insert a;

        Proposal__c p = new Proposal__c (Account__c = a.Id, App_type__c = 'Standard', Fund__c = 'Program');
        insert p;

        Milestone__c m = new Milestone__c (Proposal__c=p.Id);    
        insert m;   

        GM_Data__c gmData = new GM_Data__c (Account__c = a.Id, Proposal__c = p.Id, Milestone__c=m.Id);
        insert gmData;

        Classification__c cl =  new Classification__c (Name = 'test classification', Type__c = 'Population');
        insert cl;

        Indicator__c ind = new Indicator__c (Name = 'Increased Awareness', Outcome_type__c = 'Awareness', Active__c=true);
        insert ind;

        Review_Form__c rf = new Review_Form__c (Name = 'test review form');
        insert rf;

        Assessment__c assess = new Assessment__c (Advisor__c = adv.Id, Account__c = a.Id, Review_Form__c = rf.Id, Proposal__c=p.Id, Milestone__c=m.Id);
        insert assess;

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

    }

    @isTest
    static void instantiateTest() {
        Assessment__c assess = [SELECT ID FROM Assessment__c LIMIT 1];

        Assessment assessWrapper = new Assessment(assess.Id);

        System.debug('assessorwrapper: '+JSON.serialize(assessWrapper));

    }

    @isTest
    static void IndicatorAssignTest() {

        GM_Data__c gmData = [SELECT ID FROM GM_Data__c LIMIT 1];
        Indicator__c ind = [SELECT ID FROM Indicator__c LIMIT 1];

        ReviewFormController.addIndicatorAssign(gmData.Id, ind.Id, 10, 'Test Comments');

        List < Indicator_Assign__c > indAssigns = [SELECT ID, Quantity__c, Comment__c FROM Indicator_Assign__c];

        System.assertEquals('Test Comments', indAssigns[0].Comment__c);
        System.assertEquals(10, indAssigns[0].Quantity__c);

        ReviewFormController.updateIndicatorComment(gmData.Id, ind.Id, 'Updated Comment');
        Indicator_Assign__c updatedCommentInd = [SELECT ID, Quantity__c, Comment__c FROM Indicator_Assign__c LIMIT 1];

        System.assertEquals('Updated Comment', updatedCommentInd.Comment__c);

        ReviewFormController.updateIndicatorQuantity(gmData.Id, ind.Id, 20);
        Indicator_Assign__c updatedQuantityInd = [SELECT ID, Quantity__c, Comment__c FROM Indicator_Assign__c LIMIT 1];

        System.assertEquals(20, updatedQuantityInd.Quantity__c);

        ReviewFormController.removeIndicatorAssign(gmData.Id, ind.Id);
        List < Indicator_Assign__c > allIndAssigns = [SELECT ID, Quantity__c, Comment__c FROM Indicator_Assign__c];
        System.assertEquals(0, allIndAssigns.size());
    }

    @isTest 
    static void submitReviewTest() {
        Assessment__c assess = [SELECT ID FROM Assessment__c LIMIT 1];

        AssessorSiteController.submitReview(assess.Id);

        Assessment__c submittedAssessment = [SELECT ID, Date_submitted__c, Milestone__c FROM Assessment__c LIMIT 1];
        Milestone__c milestone =  [SELECT ID, Date_review_completed__c FROM Milestone__c WHERE ID=:submittedAssessment.Milestone__c];

        Date d = System.today();
        System.assertEquals(d, submittedAssessment.Date_submitted__c);
        System.assertEquals(d, milestone.Date_review_completed__c);

    }

    @isTest 
    static void submitReviewNegativeTest() {
        Assessment__c assess = [SELECT ID, Milestone__c FROM Assessment__c LIMIT 1];

        // If there is already a date review completed on Milestone, don't overwrite it
        Date lastWeek = System.today().addDays(-7);
        Milestone__c rep = new Milestone__c (
            Id=assess.Milestone__c,
            Date_review_completed__c = lastWeek
        );
        update rep;

        AssessorSiteController.submitReview(assess.Id);

        Assessment__c submittedAssessment = [SELECT ID, Date_submitted__c, Milestone__c FROM Assessment__c LIMIT 1];
        Milestone__c milestone =  [SELECT ID, Date_review_completed__c FROM Milestone__c WHERE ID=:submittedAssessment.Milestone__c];

        Date d = System.today();
        System.assertEquals(d, submittedAssessment.Date_submitted__c);
        System.assertEquals(lastWeek, milestone.Date_review_completed__c);

    }
}