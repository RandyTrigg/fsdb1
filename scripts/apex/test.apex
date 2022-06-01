/* ApexLog[] logs = [SELECT Id FROM ApexLog];
system.debug(logs.size());
*/
Id usrId = '0057i000006Sv9u';
String fsGroupName = Utilities.fsGroupNameByUser(usrId);
Id fsDefaultOwnerId = Utilities.fsDefaultRecordOwnerIdByUser(usrId);
system.debug('fsgroupname: ' + fsGroupName);
system.debug('fsDefaultOwnerId: ' + fsDefaultOwnerId);