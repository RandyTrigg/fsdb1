Id fiId = Id.valueOf('a245d00001cC5IZAA0');
FormDataController.updateTargetFields(fiId);
/*
Id profId = Id.valueOf('a1O8c000009hndWEAQ');
Form_Instance__c[] fis = FormInstanceController.getFormInstances(profId);
system.debug(fis.size());
*/
/*
Boolean bbb = true;
Boolean ccc;
Boolean aaa = false;

//system.debug(bbb instanceof Boolean);
system.debug(ccc instanceof Boolean);
system.debug(aaa instanceof Boolean);
*/
/*
Id fiId = Id.valueOf('a248H000000DlpEQAS');
Form_Instance__c fi = [SELECT Profile__c, Advisor__r.Contact__c FROM Form_Instance__c WHERE Id =: fiId];
system.debug(Utilities.getValue(fi, 'Advisor__r.Contact__c'));
system.debug(Utilities.getValue(fi, 'Profile__c'));
*/
/* ApexLog[] logs = [SELECT Id FROM ApexLog];
system.debug(logs.size());
*/
/*
Id usrId = '0058c000008Rzwz';
String fsGroupName = Utilities.fsGroupNameByUser(usrId);
Id fsDefaultOwnerId = Utilities.fsDefaultRecordOwnerIdByUser(usrId);
system.debug('fsgroupname: ' + fsGroupName);
system.debug('fsDefaultOwnerId: ' + fsDefaultOwnerId);
*/