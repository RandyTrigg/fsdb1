@isTest
public without sharing class AssessmentProposalTest {
        
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

        GM_Data__c gmData = new GM_Data__c (Account__c = a.Id, Proposal__c = p.Id);
        insert gmData;

        Classification__c cl =  new Classification__c (Name = 'test classification', Type__c = 'Population');
        insert cl;

        Portfolio__c porfolio = new Portfolio__c (Name = 'test portfolio', Type__c = 'Priority', Active__c=true);
        insert porfolio;

        Review_Form__c rf = new Review_Form__c (Name = 'test review form');
        insert rf;

        Decline_Reason__c dr = new Decline_Reason__c (Name = '1A US-based group',Active__c=true);
        insert dr;

        Assessment__c assess = new Assessment__c (Advisor__c = adv.Id, Account__c = a.Id, Review_Form__c = rf.Id, Proposal__c=p.Id);
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
            Lightning_component_name__c = 'Label',
            Label__c = 'Label Content',
            Sort_number__c = 3
        ));
        
        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id,
            Active__c = true,
            Lightning_component_name__c = 'InputCheckbox',
            Label__c = 'input checkbox label',
            Object_name__c = 'GM_Data__c',
            Field_name__c = 'New_group_with_established_players__c',
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
            Field_name__c = 'Org_capacity_risk_description__c',
            Sort_number__c = 2
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputNumber',
            Label__c = 'input number label',
            Help_text__c = 'help text',
            Object_name__c = 'Proposal__c',
            Field_name__c = 'Amount_recommended__c',
            Sort_number__c = 2
        ));

        insert components;

    }

    @isTest
    static void instantiateTest() {
        Assessment__c assess = [SELECT ID FROM Assessment__c LIMIT 1];

        Assessment assessWrapper = new Assessment(assess.Id);

        System.assertEquals('Pending', assessWrapper.statusExternal);
        System.assertEquals(1, assessWrapper.classificationAssignMap.values().size());
        System.assertEquals(null, assessWrapper.linkedGranteeReport);

    }

    @isTest
    static void getAssessmentReviewTest() {

        //getTest
        Assessment__c assess = [SELECT ID FROM Assessment__c LIMIT 1];
        String reviewJson = AssessorSiteController.getAssessmentReview(assess.Id);
        Assessment assessWrapper = (Assessment)JSON.deserialize(reviewJson, Assessment.class);
        System.assertEquals(assess.Id, assessWrapper.Id);

    }

    @isTest
    static void getAssignedAssessmentsTest() {

        Profile profile = [select id, Name from profile where name='GFW Community Member Assessor'];
        Contact c = [SELECT ID, FirstName, LastName, Email FROM Contact LIMIT 1];

        // Assign the community user on the advisor
        Advisor__c adv = [SELECT ID, Account__c FROM Advisor__c LIMIT 1];
        adv.Community_contact__c = c.Id;
        update adv;

        // Create user record for Assessor
        User usr = new User (
            FirstName = c.FirstName, 
            LastName = c.LastName, 
            Username = c.FirstName + c.LastName + '@gfw.org',
            Email = c.FirstName + c.LastName + '@gfw.org',
            Alias = '6745475',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = c.Id
        );

        insert usr;

        System.runAs(usr) {
            List <Assessment__c> assessments = AssessorSiteController.getAssignedAssessments();
            System.debug('returned assessments: '+assessments);
            // System.assertEquals(1, assessments.size());
        }

    }

    @isTest 
    static void updateTextPickOrLookupTest() {
        GM_Data__c gmData = [SELECT ID FROM GM_Data__c LIMIT 1];

        ReviewFormController.updateTextPickOrLookup('GM_Data__c', gmData.Id, 'Org_capacity_risk_description__c', 'test description value');

        GM_Data__c updatedGmData = [SELECT ID, Org_capacity_risk_description__c FROM GM_Data__c LIMIT 1];

        System.assertEquals('test description value', updatedGmData.Org_capacity_risk_description__c);

    }

    @isTest 
    static void updateBooleantest() {
        GM_Data__c gmData = [SELECT ID FROM GM_Data__c LIMIT 1];

        ReviewFormController.updateBoolean('GM_Data__c', gmData.Id, 'New_group_with_established_players__c', true);

        GM_Data__c updatedGmData = [SELECT ID, New_group_with_established_players__c FROM GM_Data__c LIMIT 1];

        System.assertEquals(true, updatedGmData.New_group_with_established_players__c);
        
    }

    @isTest 
    static void classificationJoinTest() {

        Proposal__c prop = [SELECT ID FROM Proposal__c LIMIT 1];
        Classification__c cls = [SELECT ID FROM Classification__c LIMIT 1];
        List < String > classIDList = new List < String >{cls.Id};


        ReviewFormController.addClassificationJoin('Proposal', prop.Id, classIDList);

        List < Classification_Assign__c > ca = [SELECT ID FROM Classification_Assign__c WHERE Classification__c=:cls.Id];

        System.assertEquals(1, ca.size());

        ReviewFormController.removeClassificationJoin('Proposal', prop.Id, classIDList);

        List < Classification_Assign__c > allCA = [SELECT ID FROM Classification_Assign__c WHERE Classification__c=:cls.Id];

        System.assertEquals(0, allCA.size());
        
    }

    @isTest 
    static void portfolioAssignTest() {

        Proposal__c prop = [SELECT ID FROM Proposal__c LIMIT 1];
        Portfolio__c port = [SELECT ID FROM Portfolio__c LIMIT 1];
        List < String > portIdList = new List < String >{port.Id};

        ReviewFormController.addPortfolioAssign('Proposal', prop.Id, portIdList);

        List < Portfolio_Assignment__c > pas = [SELECT ID FROM Portfolio_Assignment__c WHERE Portfolio__c=:port.Id];

        System.assertEquals(1, pas.size());

        ReviewFormController.removePortfolioAssign('Proposal', prop.Id, portIdList);

        List < Portfolio_Assignment__c > allPas = [SELECT ID FROM Portfolio_Assignment__c WHERE Portfolio__c=:port.Id];

        System.assertEquals(0, allPas.size());
         
    }

    @isTest 
    static void submitReviewTest() {
        Assessment__c assess = [SELECT ID FROM Assessment__c LIMIT 1];

        AssessorSiteController.submitReview(assess.Id);

        Assessment__c submittedAssessment = [SELECT ID, Date_submitted__c, Proposal__c FROM Assessment__c LIMIT 1];
        Proposal__c prop =  [SELECT ID, Date_review_completed__c FROM Proposal__c WHERE ID=:submittedAssessment.Proposal__c];

        Date d = System.today();
        System.assertEquals(d, submittedAssessment.Date_submitted__c);
        System.assertEquals(d, prop.Date_review_completed__c);

    }

    @isTest 
    static void submitReviewNegativeTest() {
        Assessment__c assess = [SELECT ID, Proposal__c FROM Assessment__c LIMIT 1];

        // If there is already a date review completed on Grantee Report, don't overwrite it
        Date lastWeek = System.today().addDays(-7);
        Proposal__c prop = new Proposal__c (
            Id=assess.Proposal__c,
            Date_review_completed__c = lastWeek
        );
        update prop;

        AssessorSiteController.submitReview(assess.Id);

        Assessment__c submittedAssessment = [SELECT ID, Date_submitted__c, Proposal__c FROM Assessment__c LIMIT 1];
        Proposal__c proposal =  [SELECT ID, Date_review_completed__c FROM Proposal__c WHERE ID=:submittedAssessment.Proposal__c];

        Date d = System.today();
        System.assertEquals(d, submittedAssessment.Date_submitted__c);
        System.assertEquals(lastWeek, proposal.Date_review_completed__c);

    }

}