/* ApexLog[] logs = [SELECT Id FROM ApexLog];
system.debug(logs.size());
*/
Id usrId = '0058c000008Rzwz';
String fsGroupName = Utilities.fsGroupNameByUser(usrId);
Id fsDefaultOwnerId = Utilities.fsDefaultRecordOwnerIdByUser(usrId);
system.debug('fsgroupname: ' + fsGroupName);
system.debug('fsDefaultOwnerId: ' + fsDefaultOwnerId);