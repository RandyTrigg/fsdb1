/* ApexLog[] logs = [SELECT Id FROM ApexLog];
system.debug(logs.size());
*/
system.debug('this userid: ' + userInfo.getUserId());
String FSGroup = Utilities.FSGroupOfUser(userInfo.getUserId());
system.debug('fsgroup: ' + FSGroup);
Template__c t = [SELECT Id
            FROM Template__c
            WHERE Name = 'Proposal status' AND FS_Group__c =:FSGroup
        ];
system.debug('template: ' + t);