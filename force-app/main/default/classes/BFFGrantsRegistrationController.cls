public without sharing class BFFGrantsRegistrationController {
    
    private class Registrant {
        public String email;
        public String groupName;
    }
    
    @AuraEnabled
    public static String handleRegistration(String registrantJSON) {
        strike_responseData responseData = new strike_responseData();
        Registrant reg = (Registrant)JSON.deserialize(registrantJSON, Registrant.class);
        System.debug('reg: '+reg);

        ID profileId = [SELECT Id, Name from Profile WHERE Name = 'BFF Basic Community Login User' LIMIT 1].Id;

        // Attach users to blanket account
        Account a = [SELECT ID FROM Account WHERE Name='BFF Community Users Account'];

        String contactRecordTypeId = Schema.Sobjecttype.Contact.RecordTypeInfosByName.get('Contact GM').RecordTypeId;
        try{
            Contact c = new Contact (
                LastName = reg.groupName.left(80),
                AccountId = a.Id,
                Email = reg.email
            );
            insert c;

            User u = new User();
            u.ProfileId = profileId;
            u.LastName = reg.groupName.left(80);
            u.Email = reg.email;
            u.Username = 'bff-'+reg.email; // prefix email with 'bff' to ensure uniqueness
            u.EmailEncodingKey = 'UTF-8';
            u.LocaleSidKey = 'en_US';
            u.LanguageLocaleKey = 'en_US';
            u.ContactId = c.Id;
            u.TimeZoneSidKey = 'GMT';
            u = handleUnsetRequiredFields(u);
    
            System.debug('u: '+u);
            insert u;
        } catch(Exception e) {
            responseData.addError(e.getMessage());
            // throw new GFW_Exception('BFFGrantsRegistrationController.handleRegistration', 'Could not create user account: ' + e.getMessage(), e);
        }
        return responseData.getJsonString();
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