ApexLog[] logs = [SELECT Id FROM ApexLog];
system.debug(logs.size());
/*
        insert new Account(
            Name = 'test_acct_1',
            RecordTypeId = Utilities.getRecTypeId('Account', 'HH_Account')
        );
        Account acct1 = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'test_acct_1'
            LIMIT 1
        ];
        system.debug(acct1);
*/

GroupMember[] gms = [select id,UserOrGroupId,Groupid, Group.DeveloperName, Group.Type from GroupMember WHERE Group.DeveloperName LIKE 'FS_'];
String grpName = !gms.isEmpty() ? gms[0].Group.DeveloperName : null;
System.debug('grpName: ' + grpName);

String gName = Utilities.FSGroupNameFromUserId(getUserId());
System.debug('gName: ' + gName);

/*    
    System.debug('UserOrGroupId: ' + gm.UserOrGroupId);
    System.debug('Group type: ' + gm.Group.Type);
*/