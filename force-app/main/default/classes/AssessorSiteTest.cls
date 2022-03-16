@isTest
public class AssessorSiteTest {
    
    @TestSetup
    static void makeData(){

        // This will set up a Program, Adviosr, Advisor Term
        AdvisorControllerTest.InitTestObjects(1, 1);
        Program__c prog = [SELECT ID, Name FROM Program__c WHERE Name=:'test program'];

        Advisor__c adv = [SELECT ID, Account__c FROM Advisor__c LIMIT 1];

        Account a = new Account (Name = 'test account', GM_program__c = prog.Id, RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM'));
        insert a;

        Applicant__c app = new Applicant__c (Name='test applicant', Account__c = a.Id);
        insert app;

        Profile__c prof = new Profile__c (Account__c=a.Id, Applicant__c=app.Id);
        insert prof;

        Proposal__c p = new Proposal__c (Account__c = a.Id, App_type__c = 'Standard', Fund__c = 'Program');
        insert p;

        Restriction__c restrict = new Restriction__c(Name='TestRestriction');
        insert restrict;

        Allocation__c alloc = new Allocation__c(Restriction__c=restrict.Id, Grant_size__c=10000, Num_grants__c=2, Years__c='MY2');
        insert alloc;

        Invite__c inv = new Invite__c(Account__c = a.Id,Profile__c=prof.Id,Proposal__c=p.Id, Allocation__c=alloc.Id);
        insert inv;

        //Update the Proposal
        p.Invite__c = inv.Id;
        update p;

        Milestone__c m = new Milestone__c (Proposal__c=p.Id, Which_yearly__c=1, Time_sensitive__c=true);    
        insert m;   

        GM_Data__c gmData = new GM_Data__c (Account__c = a.Id, Proposal__c = p.Id, Milestone__c=m.Id);
        insert gmData;

        Portfolio__c portfolio = new Portfolio__c(Name='Test Portfolio', Active__c=true, Type__c='Externally viewed');
        insert portfolio;

        Portfolio_Account_Assign__c portAcctAssign = new Portfolio_Account_Assign__c(Portfolio__c=portfolio.Id, Account__c=a.Id);
        insert portAcctAssign;

        Portfolio_Assignment__c portAssign = new Portfolio_Assignment__c(Proposal__c=p.Id, Portfolio__c=portfolio.Id);
        insert portAssign;

        Advisor_Term__c at = new Advisor_Term__c(Advisor__c = adv.Id, RecordTypeId = Utilities.getRecTypeId('Advisor_Term__c','Assessor'), Type__c = 'View forms', Portfolio__c=portfolio.Id, Date_term_begins__c=System.today(),Date_accepted__c=System.today());
        insert at;

        Classification__c cl =  new Classification__c (Name = 'test classification', Type__c = 'Population');
        insert cl;

        Indicator__c ind = new Indicator__c (Name = 'Increased Awareness', Outcome_type__c = 'Awareness', Active__c=true);
        insert ind;

        Review_Form__c rf = new Review_Form__c (Name = 'test review form');
        insert rf;

        Form__c form = new Form__c (Name='Rating Form', Type__c='Assessment');
        insert form;

        List < Assessment__c > assessmentsToInsert = new List < Assessment__c >();
        Assessment__c mAssess = new Assessment__c (Advisor__c = adv.Id, Account__c = a.Id, Review_Form__c = rf.Id, Proposal__c=p.Id, Milestone__c=m.Id);
        assessmentsToInsert.add(mAssess);

        Assessment__c prAssess = new Assessment__c (Advisor__c = adv.Id, Account__c = a.Id, Review_Form__c = rf.Id, Proposal__c=p.Id);
        assessmentsToInsert.add(prAssess);

        Assessment__c profAssess = new Assessment__c (Advisor__c = adv.Id, Account__c = a.Id, Review_Form__c = rf.Id, Profile__c=prof.Id);
        assessmentsToInsert.add(profAssess);

        Assessment__c ratingAssess = new Assessment__c (Advisor__c = adv.Id, Account__c = a.Id, Form__c =form.Id, Proposal__c=p.Id);
        assessmentsToInsert.add(ratingAssess);

        insert assessmentsToInsert;

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
    static void loadAdvisorSummary() {
        Advisor__c adv = [SELECT ID, Account__c FROM Advisor__c LIMIT 1];

        AdvisorSummary summary = new AdvisorSummary(adv.ID);

        System.assertEquals(1, summary.viewFormsAvailable.size());
        System.assertEquals(1, summary.ratingsAssigned.size());
        System.assertEquals(1, summary.proposalReviewsAssigned.size());
        System.assertEquals(1, summary.profileReviewsAssigned.size());
        System.assertEquals(1, summary.milestoneReviewsAssigned.size());

    }

    @isTest 
    static void testGetSearchableRecords() {
        List<LookupSearchResult> results = (List<LookupSearchResult>)JSON.deserialize(AssessorSiteController.getSearchableRecords(),List<LookupSearchResult>.class);

        System.assertEquals(6, results.size());
    }

    @isTest 
    static void testGetInterfaceType() {

        //First set up the advisor to be linked to a community user contact
        Advisor__c adv = [SELECT Id, Contact__c, Contact__r.LastName, Contact__r.FirstName, Contact__r.Email FROM Advisor__c LIMIT 1];

        //create account/contact
        Id orgGMRtId = Utilities.getRecTypeId('Account', 'Organization_GM');
        // Build a country record.
        Program__c prog = new Program__c (Name = 'test program');
        insert prog;
        Region__c reg = new Region__c (Name = 'test region', Program__c = prog.Id);
        insert reg;
        Country__c country = new Country__c (Name = 'test country', Region__c = reg.Id);
        insert country;
        //Build the accont
        Account commContactAccount = new Account (
            Name = AdvisorController.communityAccountName, 
            RecordTypeId = orgGMRtId,
            GM_country__c = country.Id
        );
        insert commContactAccount;
        Contact con = new Contact (AccountId = commContactAccount.Id, LastName = 'test contact', email='testAdvisor12346587984@test.com');
        insert con;

        Id pIdAdv = [SELECT Id FROM Profile WHERE Name = : AdvisorController.advisorCommunityProfileName LIMIT 1].Id;
        User u = new User(
            Username = con.Email,
            Email = con.Email,
            CommunityNickname = con.Email.left(10),
            LastName = 'testAdvisor',
            FirstName = 'testAdvisor',
            Alias = con.Email.toLowerCase().left(4),
            ProfileId = pIdAdv,
            ContactId = con.Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'GMT'
        );
        insert u;

        adv.Community_contact__c = con.Id;
        update adv;

        Test.startTest();
        System.runAs(u) {
            String interfaceType = AssessorSiteController.getInterfaceType();
            System.assertEquals('invitations', interfaceType);
        }
    }

    @isTest
    static void testGetAssessmentInvitesReview() {
        Assessment__c mAssess = [SELECT ID, Milestone__c FROM Assessment__c WHERE Milestone__c!=null LIMIT 1];

        Assessment assessment = (Assessment)JSON.deserialize(AssessorSiteController.getAssessmentReview(mAssess.Id),Assessment.class);

        System.assertNotEquals(null, assessment);
    }

    @isTest
    static void testGetAssignedAssessments() {
        //Set up assessor user
        //First set up the advisor to be linked to a community user contact
        Advisor__c adv = [SELECT Id, Contact__c, Contact__r.LastName, Contact__r.FirstName, Contact__r.Email FROM Advisor__c LIMIT 1];

        //create account/contact
        Id orgGMRtId = Utilities.getRecTypeId('Account', 'Organization_GM');
        // Build a country record.
        Program__c prog = new Program__c (Name = 'test program');
        insert prog;
        Region__c reg = new Region__c (Name = 'test region', Program__c = prog.Id);
        insert reg;
        Country__c country = new Country__c (Name = 'test country', Region__c = reg.Id);
        insert country;
        //Build the accont
        Account commContactAccount = new Account (
            Name = AdvisorController.communityAccountName, 
            RecordTypeId = orgGMRtId,
            GM_country__c = country.Id
        );
        insert commContactAccount;
        Contact con = new Contact (AccountId = commContactAccount.Id, LastName = 'test contact', email='testAdvisor12346587984@test.com');
        insert con;

        Id pIdAdv = [SELECT Id FROM Profile WHERE Name = : AdvisorController.advisorCommunityProfileName LIMIT 1].Id;
        User u = new User(
            Username = con.Email,
            Email = con.Email,
            CommunityNickname = con.Email.left(10),
            LastName = 'testAdvisor',
            FirstName = 'testAdvisor',
            Alias = con.Email.toLowerCase().left(4),
            ProfileId = pIdAdv,
            ContactId = con.Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'GMT'
        );
        insert u;

        adv.Community_contact__c = con.Id;
        update adv;

        Test.startTest();
        System.runAs(u) {
            List<Assessment__c> assessments = AssessorSiteController.getAssignedAssessments();
            System.assertEquals(3, assessments.size());

            List < Invite__c > invites = (List < Invite__c >)JSON.deserialize(AssessorSiteController.getAssignedInvites(),List < Invite__c >.class);
            System.assertEquals(1, invites.size());



        }
    }

    @isTest
    static void testGetInviteFormInfo() {
        Invite__c inv = [SELECT ID FROM Invite__c LIMIT 1];

        Map<String, Object> inviteInfo = (Map<String, Object>)JSON.deserializeUntyped(AssessorSiteController.getInviteFormInfo(inv.Id));
        System.assertEquals(2, inviteInfo.size());

        
    }

    @isTest
    static void testLoadAdvisorSummary() {
        //Set up assessor user
        //First set up the advisor to be linked to a community user contact
        Advisor__c adv = [SELECT Id, Contact__c, Contact__r.LastName, Contact__r.FirstName, Contact__r.Email FROM Advisor__c LIMIT 1];

        //create account/contact
        Id orgGMRtId = Utilities.getRecTypeId('Account', 'Organization_GM');
        // Build a country record.
        Program__c prog = new Program__c (Name = 'test program');
        insert prog;
        Region__c reg = new Region__c (Name = 'test region', Program__c = prog.Id);
        insert reg;
        Country__c country = new Country__c (Name = 'test country', Region__c = reg.Id);
        insert country;
        //Build the accont
        Account commContactAccount = new Account (
            Name = AdvisorController.communityAccountName, 
            RecordTypeId = orgGMRtId,
            GM_country__c = country.Id
        );
        insert commContactAccount;
        Contact con = new Contact (AccountId = commContactAccount.Id, LastName = 'test contact', email='testAdvisor12346587984@test.com');
        insert con;

        Id pIdAdv = [SELECT Id FROM Profile WHERE Name = : AdvisorController.advisorCommunityProfileName LIMIT 1].Id;
        User u = new User(
            Username = con.Email,
            Email = con.Email,
            CommunityNickname = con.Email.left(10),
            LastName = 'testAdvisor',
            FirstName = 'testAdvisor',
            Alias = con.Email.toLowerCase().left(4),
            ProfileId = pIdAdv,
            ContactId = con.Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'GMT'
        );
        insert u;

        adv.Community_contact__c = con.Id;
        update adv;

        Test.startTest();
        System.runAs(u) {
            AdvisorSummary summary = (AdvisorSummary)JSON.deserialize(AssessorSiteController.loadAdvisorSummary(),AdvisorSummary.class);

            System.debug('summary: '+summary);

            //Run through advisor record loads
            List < Assessment__c > mAssessments = (List < Assessment__c >)JSON.deserialize(AssessorSiteController.loadAdvisorRecords('Milestone__c'),List < Assessment__c >.class);
            System.assertEquals(1, mAssessments.size());

            List < Assessment__c > propAssessments = (List < Assessment__c >)JSON.deserialize(AssessorSiteController.loadAdvisorRecords('Proposal__c'),List < Assessment__c >.class);
            System.assertEquals(1, propAssessments.size());

            List < Assessment__c > profAssessments = (List < Assessment__c >)JSON.deserialize(AssessorSiteController.loadAdvisorRecords('Profile__c'),List < Assessment__c >.class);
            System.assertEquals(1, profAssessments.size());

            List < Assessment__c > ratingAssessments = (List < Assessment__c >)JSON.deserialize(AssessorSiteController.loadAdvisorRecords('Rating'),List < Assessment__c >.class);
            System.assertEquals(1, ratingAssessments.size());

            List < Invite__c > invites = (List < Invite__c >)JSON.deserialize(AssessorSiteController.loadAdvisorRecords('Form'),List < Invite__c >.class);
            System.assertEquals(1, invites.size());

        }

    }

    

}