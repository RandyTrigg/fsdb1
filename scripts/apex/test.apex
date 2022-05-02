/*
ApexLog[] logs = [SELECT Id FROM ApexLog];
system.debug(logs.size());

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

for(GroupMember gm : [select id,UserOrGroupId,Groupid, Group.Name, Group.Type from GroupMember])
{
	System.debug('group name: ' + gm.Group.Name);
    System.debug('UserOrGroupId: ' + gm.UserOrGroupId);
    System.debug('Group type: ' + gm.Group.Type);
}