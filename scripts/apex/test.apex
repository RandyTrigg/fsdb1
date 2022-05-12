/* ApexLog[] logs = [SELECT Id FROM ApexLog];
system.debug(logs.size());
*/
Id usrId = '0058c00000BKxMD';
User usr = [select id, Name, ProfileId, Profile.UserLicense.name from user where Id=:usrId];
system.debug('userprofile: ' + usr.Profile.UserLicense.name);
String fsGroup = FSGroupOfUser(usrId);
system.debug('fsgroup: ' + fsGroup);

// Return public group name of FS Group to which user belongs
    public static String FSGroupOfUser(Id usrId) {
        // If Customer Community user, retrieve FS Group by SF Profile and custom metadata type records.
        // Else, go upstream in hierarchy from user's role to identify FS Group, if any.
        FS_Group_Settings__mdt[] fsGroups = [SELECT Id, DeveloperName, Designated_Role_for_Ownership__c, Public_Group_Name__c 
        FROM FS_Group_Settings__mdt 
        WHERE Active__c = true];
        User usr = [SELECT Id, Profile.Name, Profile.UserLicense.Name, UserRoleId FROM User WHERE Id=:usrId];
        Boolean isCommunityUsr = (usr.Profile.UserLicense.Name == 'Customer Community Login');
        Map<String, String> groupRole = new Map<String, String>();
        for (FS_Group_Settings__mdt fsGrp : fsGroups) {
            if (isCommunityUsr && usr.Profile.Name.contains(fsGrp.DeveloperName)) {
                return fsGrp.Public_Group_Name__c;
            }
            groupRole.put(fsGrp.Designated_Role_for_Ownership__c, fsGrp.Public_Group_Name__c);
        }
        Map<Id, UserRole> usrRoles = new Map<Id, UserRole>([
            SELECT Id, DeveloperName, ParentRoleId 
            FROM UserRole]);
        UserRole thisRole = new UserRole();
        thisRole = usrRoles.get(usr.UserRoleId);
        // Cycle through parent roles to find relevant FS Group
        while (thisRole != null) {
            if (groupRole.containsKey(thisRole.DeveloperName)) return groupRole.get(thisRole.DeveloperName);
            thisRole = usrRoles.get(thisRole.ParentRoleId);
        }
        return '';
    }