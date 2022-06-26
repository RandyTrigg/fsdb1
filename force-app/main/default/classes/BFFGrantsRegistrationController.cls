public without sharing class BFFGrantsRegistrationController {
    
    private class Registrant {
        public String email;
        public String groupName;
        public String language;
    }
    
    @AuraEnabled
    public static String handleRegistration(String registrantJSON) {
        Registrant reg = (Registrant)JSON.deserialize(registrantJSON, Registrant.class);
        System.debug('reg: '+reg);
        String regUsername = 'bff-' + reg.email;
        System.debug('username: ' + regUsername);

        // Check if username already exists. If so, return error
        List<User> extUsrs = new List<User>([SELECT Id FROM User WHERE Username =: regUsername]);
        System.debug('extUsrs:' + extUsrs);
        if (extUsrs.size()>0) {
            System.debug('DuplicateUsername');
            return 'DuplicateUsername';
        } else {
            // Create new user and contact
            ID profileId = [SELECT Id, Name from Profile WHERE Name = 'BFF Basic Community Login User' LIMIT 1].Id;
            Account a = [SELECT ID, OwnerId FROM Account WHERE Name='BFF Community Users Account'];
            String contactRecordTypeId = Schema.Sobjecttype.Contact.RecordTypeInfosByName.get('Contact GM').RecordTypeId;
            Id fsOwnerId = a.OwnerId;
            Contact c = new Contact (
                LastName = reg.groupName.left(80),
                AccountId = a.Id,
                Email = reg.email,
                OwnerId = fsOwnerId,
                Preferred_language__c = reg.language,
                Org_name_submitted__c = reg.groupName
            );
            // Update ProfileController to set Profile's language and org name.
            // Prefill Profile form components from those 
            insert c;
        
            User u = new User();
            u.ProfileId = profileId;
            u.LastName = reg.groupName.left(80);
            u.Email = reg.email;
            u.Username = regUsername; // prefix email with 'bff' to ensure uniqueness
            u.EmailEncodingKey = 'UTF-8';
            u.LocaleSidKey = 'en_US';
            u.LanguageLocaleKey = 'en_US'; // YIKES. Is there where we want language to go? Create new?
            u.ContactId = c.Id;
            u.TimeZoneSidKey = 'GMT';
            u = handleUnsetRequiredFields(u);

            System.debug('u: '+u);
            insert u;

            return '';
        }
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