

// Look up FS Public Groups and build Map of UserOrGroupIds by FSGroupName
Id usrId = '0058c000008TAQUAA4';

// Look up public groups from custom metadatatype
FS_Group_Settings__mdt[] fsGroups = [SELECT Public_Group_Name__c 
    FROM FS_Group_Settings__mdt 
    WHERE Active__c = true];
List<String> groupNames = new List<String>();
for (FS_Group_Settings__mdt fsGrp : fsGroups) {
    groupNames.add(fsGrp.Public_Group_Name__c);
}

// Build map of UserGroupIds by FSGroup
Set<String> extSet = new Set<String>();
String fsGroup;
Map<String,Set<String>> fsGrpMemberIds = new Map<String,Set<String>>();
for (GroupMember gm : [SELECT Id, UserOrGroupId, Group.DeveloperName FROM GroupMember WHERE Group.DeveloperName IN :groupNames]) {
	fsGroup = gm.Group.DeveloperName;
    if (fsGrpMemberIds.containsKey(fsGroup) ) {
		extSet = fsGrpMemberIds.get(fsGroup);
	} else {
		extSet = new Set<String>();
	}
    extSet.add(gm.UserOrGroupId);
    fsGrpMemberIds.put(fsGroup, extSet);
}


// No, this gets role. i'm missing something.
for (Group gp : [SELECT Id, RelatedId, 
    FROM Group WHERE DeveloperName IN :groupNames]) {
        fsGroup = gp.DeveloperName;
        if (fsGrpMemberIds.containsKey(fsGroup)) {
            extSet = fsGrpMemberIds.get(fsGroup);
        } else {
            extSet = new Set<String>();
        }
        extSet.add(gp.RelatedId);
        fsGrpMemberIds.put(fsGroup, extSet);
}

System.debug('fsGrpMemberIds: ' + fsGrpMemberIds);
for (String fsName : fsGrpMemberIds.keySet()) {
    System.debug('fsName: ' + fsName + ' -- ' + fsGrpMemberIds.get(fsName));
}

// Look up Groups where user's RoleId is in relatedId.
Map<ID, Group> userGrps = new Map<ID, Group>([SELECT Id,Name,DeveloperName,RelatedId,Type 
    FROM Group 
    WHERE RelatedId IN 
     (SELECT UserRoleId FROM User WHERE Id = :usrId )]);
Set<Id> thisUsrGrpIds = new Set<Id>(userGrps.keyset());
thisUsrGrpIds.add(usrId);
System.debug('thisUsrGrpIds: ' + thisUsrGrpIds);

// Loop thru fsGroups and return fsGroup if any contain the User or Group Ids for this user.
for (String thisFS : fsGrpMemberIds.keyset()) {
    System.debug('thisFS: ' + thisFS);
    for (Id thisId : thisUsrGrpIds) {
        System.debug('thisId: ' + thisId);
        if (fsGrpMemberIds.get(thisFS).contains(thisId)) {
            // return thisFSGroup
            System.debug('This is the FS Group: ' + thisFS);
        }
    }
}




/*
System.debug('-- Groups where Hakima UserRole included in RelatedIn --');
Group[] grps = [SELECT Id,Name,DeveloperName,RelatedId,Type FROM Group 
WHERE RelatedId IN 
     (SELECT UserRoleId FROM User WHERE Id = '0058c000008TAQUAA4')];
for (Group gp : grps) {
    System.debug('Group: ' + gp.DeveloperName);
    System.debug('Group: ' + gp.Id);
    System.debug('RelatedId: ' + gp.RelatedId);
}

System.debug('-- All group members for all groups --');
GroupMember[] gms = [select id, UserOrGroupId, GroupId, Group.DeveloperName, Group.Type 
from GroupMember];
for (GroupMember gm : gms) {
    System.debug('Group name: ' + gm.Group.DeveloperName);
    System.debug('groupid: ' + gm.GroupId);
    System.debug('UserOrGroupId: ' + gm.UserOrGroupId);
}

System.debug('-- Group members of BFF Public Group --');
GroupMember[] gmsembedded = [select id,UserOrGroupId, GroupId, Group.DeveloperName, Group.Type 
from GroupMember WHERE GroupId = '00G8c000005iv3KEAQ'];
for (GroupMember thisgm : gmsembedded) {
    System.debug('group embedded UserOrGroupId: ' + thisgm.UserOrGroupId);
    System.debug('group embedded group name: ' + thisgm.Group.DeveloperName);
}

System.debug('-- All groups --');
Group[] gps = [select id,DeveloperName, Type, RelatedId 
from Group];
for (Group thisgp : gps) {
    System.debug('group embedded developer name: ' + thisgp.DeveloperName);
    System.debug('group embedded groupId: ' + thisgp.Id);
    System.debug('group embedded type: ' + thisgp.Type);
    System.debug('group embedded relatedId: ' + thisgp.RelatedId);
}


*/