public without sharing class BFFGrantsRegistrationController {
    
    private class Registrant {
        public String firstName;
        public String lastName;
        public String email;
        public String groupName;
    }
    
    @AuraEnabled
    public static void handleRegistration(String registrantJSON) {
        Registrant reg = (Registrant)JSON.deserialize(registrantJSON, Registrant.class);
        System.debug('reg: '+reg);

        ID profileId = [SELECT Id, Name from Profile WHERE Name = 'BFF Basic Community Login User' LIMIT 1].Id;

        //Create Account (TODO: Karen, not sure if the goal is to attach users to this blanket account? or create a new account with the group name?)
        Account a = [SELECT ID FROM Account WHERE Name='BFF Community Users Account'];

        String contactRecordTypeId = Schema.Sobjecttype.Contact.RecordTypeInfosByName.get('Contact GM').RecordTypeId;
        Contact c = new Contact (
            FirstName = reg.firstName,
            LastName = reg.lastName,
            AccountId = a.Id,
            Email = reg.email
        );

        insert c;

        User u = new User();
        u.ProfileId = profileId;
        u.FirstName = reg.firstName;
        u.LastName = reg.lastName;
        u.Email = reg.email;
        u.Username = reg.email; //TODO: you may want to add some special handling to username to ensure uniqueness
        u.EmailEncodingKey = 'UTF-8';
        u.LocaleSidKey = 'en_US';
        u.LanguageLocaleKey = 'en_US';
        u.ContactId = c.Id;
        u.TimeZoneSidKey = 'GMT';
        u = handleUnsetRequiredFields(u);

        System.debug('u: '+u);
        insert u;

    }

    // Loops over required fields that were not passed in to set to some default value
    private static User handleUnsetRequiredFields(User u) {
        if (String.isBlank(u.Alias)) {
        u.Alias = generateAlias();
        }
        if (String.isBlank(u.CommunityNickname)) {
        u.CommunityNickname = generateCommunityNickname();
        }
        return u;
    }

    // Default implementation to try to provide uniqueness
    private static String generateAlias() {
        String timeString = String.valueOf(Datetime.now().getTime());
        return timeString.substring(timeString.length() - 8);
    }

    // Default implementation to try to provide uniqueness
    private static String generateCommunityNickname() {
        return 'ExternalUser' + Datetime.now().getTime();
    }
}