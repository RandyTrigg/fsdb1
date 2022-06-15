@isTest
public without sharing class AssessmentProfileTest {
    
    @TestSetup
    static void makeData(){
        // This will set up a Region, Adviosr, Advisor Term
        AdvisorControllerTest.InitTestObjects(1);
        Region__c reg = [SELECT ID, Name FROM Region__c WHERE Name=:'test region'];

        Advisor__c adv = [SELECT ID, Account__c FROM Advisor__c LIMIT 1];


        Account a = new Account (Name = 'test account', GM_region__c = reg.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        insert a;

        Profile__c prof = new Profile__c (Account__c=a.Id);
        insert prof;

        Classification__c cl =  new Classification__c (Name = 'test classification', Type__c = 'Issue');
        insert cl;

        Portfolio__c porfolio = new Portfolio__c (Name = 'test portfolio', Type__c = 'Priority', Active__c=true);
        insert porfolio;

        Review_Form__c rf = new Review_Form__c (Name = 'test profile review form');
        insert rf;

        Decline_Reason__c dr = new Decline_Reason__c (Name = '1A US-based group',Active__c=true,For_profile__c=true);
        insert dr;

        Assessment__c assess = new Assessment__c (Advisor__c = adv.Id, Account__c = a.Id, Review_Form__c = rf.Id, Profile__c=prof.Id);
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
            Object_name__c = 'Profile__c',
            Field_name__c = 'Registered_NGO__c',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelect',
            Label__c = 'input select label',
            Object_name__c = 'Profile__c',
            Field_name__c = 'Language__c',
            Sort_number__c = 3
        ));

        components.add(new Review_Form_Component__c (
            Review_Form__c = rf.Id, 
            Active__c = true,
            Lightning_component_name__c = 'InputSelectLookup',
            Label__c = 'input select lookup label',
            Object_name__c = 'Profile__c',
            Field_name__c = 'Decline_reason__c',
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
            Field_name__c = 'Mission_Vision__c',
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
        System.assertEquals(null, assessWrapper.linkedMilestone);

    }

    @isTest 
    static void classificationJoinTest() {

        Profile__c prof = [SELECT ID FROM Profile__c LIMIT 1];
        Classification__c cls = [SELECT ID FROM Classification__c LIMIT 1];
        List < String > classIDList = new List < String >{cls.Id};

        ReviewFormController.addClassificationJoin('Profile', prof.Id, classIDList);

        List < Classification_Profile_Assign__c > ca = [SELECT ID FROM Classification_Profile_Assign__c WHERE Classification__c=:cls.Id];

        System.assertEquals(1, ca.size());

        ReviewFormController.removeClassificationJoin('Profile', prof.Id, classIDList);

        List < Classification_Profile_Assign__c > allCA = [SELECT ID FROM Classification_Profile_Assign__c WHERE Classification__c=:cls.Id];

        System.assertEquals(0, allCA.size());
        
    }

    @isTest 
    static void portfolioAssignTest() {

        Profile__c prof = [SELECT ID FROM Profile__c LIMIT 1];
        Portfolio__c port = [SELECT ID FROM Portfolio__c LIMIT 1];
        List < String > portIdList = new List < String >{port.Id};

        ReviewFormController.addPortfolioAssign('Profile', prof.Id, portIdList);

        List < Portfolio_Profile_Assign__c > pas = [SELECT ID FROM Portfolio_Profile_Assign__c WHERE Portfolio__c=:port.Id];

        System.assertEquals(1, pas.size());

        ReviewFormController.removePortfolioAssign('Profile', prof.Id, portIdList);

        List < Portfolio_Profile_Assign__c > allPas = [SELECT ID FROM Portfolio_Profile_Assign__c WHERE Portfolio__c=:port.Id];

        System.assertEquals(0, allPas.size());
         
    }

    @isTest 
    static void submitReviewTest() {
        Assessment__c assess = [SELECT ID FROM Assessment__c LIMIT 1];

        AssessorSiteController.submitReview(assess.Id);

        Assessment__c submittedAssessment = [SELECT ID, Date_submitted__c, Profile__c FROM Assessment__c LIMIT 1];
        Profile__c prof =  [SELECT ID, Date_review_completed__c FROM Profile__c WHERE ID=:submittedAssessment.Profile__c];

        Date d = System.today();
        System.assertEquals(d, submittedAssessment.Date_submitted__c);
        System.assertEquals(d, prof.Date_review_completed__c);

    }

    @isTest 
    static void submitReviewNegativeTest() {
        Assessment__c assess = [SELECT ID, Profile__c FROM Assessment__c LIMIT 1];

        // If there is already a date review completed on Profile, don't overwrite it
        Date lastWeek = System.today().addDays(-7);
        Profile__c prof = new Profile__c (
            Id=assess.Profile__c,
            Date_review_completed__c = lastWeek
        );
        update prof;

        AssessorSiteController.submitReview(assess.Id);

        Assessment__c submittedAssessment = [SELECT ID, Date_submitted__c, Profile__c FROM Assessment__c LIMIT 1];
        Profile__c profile =  [SELECT ID, Date_review_completed__c FROM Profile__c WHERE ID=:submittedAssessment.Profile__c];

        Date d = System.today();
        System.assertEquals(d, submittedAssessment.Date_submitted__c);
        System.assertEquals(lastWeek, profile.Date_review_completed__c);

    }

    @isTest
    static void inviteBasedFormView() {
        // Create the correct Advisor Term and assign the portfolio
        Advisor__c adv = [SELECT ID, Account__c FROM Advisor__c LIMIT 1];
        Account act = [SELECT ID, Name FROM Account WHERE Name='test account' LIMIT 1];
        Portfolio__c port = [SELECT ID FROM Portfolio__c LIMIT 1];
        Portfolio_Account_Assign__c assign = new Portfolio_Account_Assign__c(
            Account__c = act.Id,
            Portfolio__c = port.Id
        );
        insert assign;

        String advTermRecordType = Schema.Sobjecttype.Advisor_Term__c.RecordTypeInfosByName.get('Assessor').RecordTypeId;

        Advisor_Term__c term = new Advisor_Term__c(
            RecordTypeId = advTermRecordType,
            Advisor__c = adv.Id,
            Date_term_begins__c = System.today().addDays(-1),
            Date_term_ends__c = System.today().addYears(1),
            Date_accepted__c = System.today().addDays(-1),
            Portfolio__c = port.Id,
            Type__c = 'View forms'
        );
        insert term;

        Id profileId = [SELECT ID from Profile where name=: AdvisorController.advisorCommunityProfileName].id;

        // Invite__c inv = new Invite__c (
        //     Profile__c = profileId,
        //     Account__c = act.Id, 
        // )

        String advisorRecTypeId = Schema.Sobjecttype.Contact.RecordTypeInfosByName.get('Contact GM Advisor').RecordTypeId;

        Id householdRtId = Utilities.getRecTypeId('Account', 'HH_Account');
        Account a = new Account (
            Name = 'AccountTest',
            RecordTypeId = householdRtId
        );
        insert a;

        Contact c = new Contact (
            AccountId = a.Id,
            RecordTypeId = advisorRecTypeId,
            FirstName = 'testAdvisor',
            LastName = 'testAdvisor'
        );

        insert c;

        adv.Community_contact__c = c.Id;
        update adv;

        User u = new User(alias = 'test123', email='test123@noemail.com',
        emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
        localesidkey='en_US', profileid =profileId, country='United States',IsActive =true,
        ContactId = c.Id,
        timezonesidkey='America/Los_Angeles', username='tester@noemail.com');
    
        insert u;

        User adminUser = [Select Id, UserRoleId From User Where Profile.Name=:AdvisorController.adminProfileName AND IsActive=true Limit 1];
        
        System.runAs(adminUser) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Label = : AdvisorController.advisorCommunityPermSetName LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        
        System.runAs(u) {
            String invites = AssessorSiteController.getAssignedInvites();
            System.debug('invites: '+invites);

            String type = AssessorSiteController.getInterfaceType();
            System.debug('type: '+type);

        }

        


    }
    
}