@isTest
public with sharing class ProfileControllerTest {
    /**********************************
     * Test the component-related methods
     * *******************************/

    static testMethod void ProfileControllerTest1() {
        // Build new records
        insert new Region__c(Name = 'Region test');
        Region__c reg = [SELECT Id FROM Region__c LIMIT 1];
        insert new Account(
            Name = 'test account',
            GM_Region__c = reg.Id,
            RecordTypeId = Utilities.getRecTypeId('Account', 'Organization_GM')
        );
        Id aId = [SELECT Id FROM Account LIMIT 1].Id;
        insert new Review_Form__c(Name = 'Profile');
        Id rfId = [SELECT Id FROM Review_Form__c LIMIT 1].Id;
        insert new Review_Form_Component__c(
            Review_Form__c = rfId,
            Lightning_component_name__c = 'InputCheckbox',
            Sort_number__c = 1
        );
        insert new Profile__c(
            Expiration_date__c = Date.newInstance(1960, 2, 17)
        );
        Profile__c p = [SELECT Id FROM Profile__c LIMIT 1];
        Id pId = p.Id;
        insert new Portfolio__c(Name = 'Test portfolio', Type__c = 'Priority');
        Id portId = [SELECT Id FROM Portfolio__c LIMIT 1].Id;
        insert new Portfolio_Profile_Assign__c(
            Profile__c = pId,
            Portfolio__c = portId
        );
        insert new Classification__c(
            Name = 'Test classification',
            Type__c = 'Population'
        );
        Id cpId = [SELECT Id FROM Classification__c LIMIT 1].Id;
        insert new Classification__c(
            Name = 'Test classification',
            Type__c = 'Strategy'
        );
        Id csId = [SELECT Id FROM Classification__c LIMIT 1].Id;
        insert new Classification__c(
            Name = 'Test classification',
            Type__c = 'Issue'
        );
        Id ciId = [SELECT Id FROM Classification__c LIMIT 1].Id;
        insert new Classification__c(
            Name = 'Test pop classification',
            Type__c = 'Population'
        );
        Id cId = [SELECT Id FROM Classification__c LIMIT 1].Id;
        insert new Classification_Profile_Assign__c(
            Profile__c = pId,
            Classification__c = cId
        );
        insert new Restricted_Classification__c(
            Name = 'Test restr classification',
            Type__c = 'Outcome'
        );
        Id rcId = [SELECT Id FROM Restricted_Classification__c LIMIT 1].Id;
        insert new Restricted_Classification_Portfolio__c(
            Portfolio__c = portId,
            Restricted_Classification__c = rcId
        );

        Test.StartTest();
        ProfileController.getProfile(pId);
        ProfileController.saveProfile(p);
        ProfileController.getProfileInfo(pId);
        ProfileController.saveProfileInfo2(
            p,
            String.valueOf(cId),
            String.valueOf(csId),
            String.valueOf(ciId),
            String.valueOf(portId)
        );
        ProfileController.getClassificationInfo('Issue', pId);
        Test.StopTest();
    }

    static testMethod void ProfileControllerTest2() {
        // Build new records
        insert new Profile__c(
            Expiration_date__c = Date.newInstance(1960, 2, 17)
        );
        Profile__c p = [SELECT Id FROM Profile__c LIMIT 1];
        Id pId = p.Id;
        insert new Template__c(Name = 'Request to submit Updated Profile');

        Test.StartTest();
        // Test profile clone batch class.  Check results after test.stopTest().
        String q =
            'SELECT Id, Decline_reason__c, Decline_reason__r.Name FROM Profile__c ' +
            ' WHERE Expiration_date__c <> null ' +
            ' AND Expiration_date__c <= TODAY ' +
            ' AND Next_profile__c = null';
        Database.executeBatch(new ProfileCloneBatch(q), 10);
        Test.StopTest();
        p = [SELECT Id, Next_profile__c FROM Profile__c WHERE Id = :pId];
        system.assertNotEquals(null, p);
        system.assertNotEquals(null, p.Next_profile__c);
        Profile__c pClone = [
            SELECT Id
            FROM Profile__c
            WHERE Id = :p.Next_profile__c
        ];
        system.assertNotEquals(null, pClone);
    }

    static testMethod void ProfileControllerTest3() {
        // Build new records
        insert new Profile__c(
            Expiration_date__c = Date.newInstance(1960, 2, 17)
        );
        Profile__c p = [SELECT Id FROM Profile__c LIMIT 1];
        Id pId = p.Id;
        insert new Template__c(Name = 'Request to submit Updated Profile');

        Test.StartTest();
        // Schedule test of profile clone.  Check results after test.stopTest().
        String cronExp = '0 0 0 15 3 ?';
        String jobId = System.schedule(
            'ScheduleApexClassTest',
            cronExp,
            new ProfileCloneSchedule()
        );
        Test.StopTest();
    }

    /**********************************
     * Test the VF-related methods
     * *******************************/

    static testMethod void ProfileControllerTestVF() {
        // Build new records
        InitTestObjects(10);
        Map<Id, Profile__c> pMap = new Map<Id, Profile__c>(
            [SELECT Id FROM Profile__c]
        );
        // Build new standard set controller and select the new profiles.
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            pMap.values()
        );
        ssc.setSelected(pMap.values());

        Test.StartTest();
        // Build a new profile controller and use it to build new letters for the selected profiles.
        insert (new Template__c(
            Name = 'Test template',
            Source_object__c = 'Profile__c'
        ));
        ProfileController pc = new ProfileController(ssc);
        pc.selectedTemplate = 'Test template';
        system.assertNotEquals(
            Utilities.recordIdFromName('Template__c', pc.selectedTemplate),
            null
        );
        pc.buildLetters();
        Test.StopTest();

        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [SELECT Id FROM Letter__c]
        );
        validate(lMap.keySet());
    }

    static void validate(Set<ID> lIds) {
        Map<Id, Letter__c> lMap = new Map<Id, Letter__c>(
            [
                SELECT Emails__c, Profile__c
                FROM Letter__c
                WHERE Id IN :lIds
            ]
        );
        Map<Id, Profile__c> pMap = new Map<Id, Profile__c>(
            [
                SELECT Id
                FROM Profile__c
                WHERE Id IN (SELECT Profile__c FROM Letter__c WHERE Id IN :lIds)
            ]
        );
        // Should be a different letter for each profile.
        system.assertEquals(lMap.size(), pMap.size());
    }

    // NOTE: Not providing email address for these profiles, because we'd have to create linked contacts and accounts.
    static void InitTestObjects(Integer NumberOfProfiles) {
        List<Profile__c> pas = new List<Profile__c>();
        for (Integer x = 0; x < NumberOfProfiles; x++) {
            pas.add(new Profile__c());
        }
        insert pas;
    }
}