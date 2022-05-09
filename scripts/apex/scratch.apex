/*
https://blog.jeffdouglas.com/2011/02/15/find-my-salesforce-users-by-role-hierarchy/
	1. Set<Id> roleAndSubUserIds
	2. Look up FS Administrator Role
	3. Get all roles underneath that one
	4. Get userids for everyone in those roles
Is thisUserId contained in that list? Then belongs in that group.
*/

// Look up public groups from custom metadatatype
/* Map<Id, FS_Group_Settings__mdt> fsGrpMap = new Map<Id, FS_Group_Settings__mdt>(SELECT Id, Designated_Role_for_Ownership__c, Public_Group_Name__c 
    FROM FS_Group_Settings__mdt 
    WHERE Active__c = true]); */

// Look up record.
// See if OwnerId field is a valid field on this object. If so, we're good - pass that in as usrId.
// Otherwise, figure out master/detail relationship: https://salesforce.stackexchange.com/questions/73405/how-to-identify-relationship-type-lookup-master-detail-from-the-field-api-na
// Get that relationship name and OwnerId. Deal with that recursively since master may be more than one level up.


// Decimal status = (Decimal) getValue(rec, statusFieldName);

system.debug('this userid: ' + userInfo.getUserId());
String FSGroup = FSGroupOfUser(userInfo.getUserId());
system.debug('fsgroup: ' + FSGroup);
Template__c t = [SELECT Id
            FROM Template__c
            WHERE Name = 'Proposal status' AND FS_Group__c =:FSGroup
        ];
system.debug('template: ' + t);


private static string FSGroupOfUser(Id usrId) {
    // usrId = '0058c000008TAQPAA4';
Id usrRoleId = [SELECT Id, UserRoleId FROM User WHERE Id=:usrId][0].UserRoleId;

// Check that usrRoleId isn't null
FS_Group_Settings__mdt[] fsGroups = [SELECT Id, Designated_Role_for_Ownership__c, Public_Group_Name__c 
    FROM FS_Group_Settings__mdt 
    WHERE Active__c = true];
Map<String, String> groupRole = new Map<String, String>();
for (FS_Group_Settings__mdt fsGrp : fsGroups) {
    groupRole.put(fsGrp.Public_Group_Name__c, fsGrp.Designated_Role_for_Ownership__c);
}

// Retrieve all related roleIds for FS Group
Set<ID> roleIds;
Id roleId;
String grpName = '';
for (String fsGroup : groupRole.keySet()) {
    roleIds = new Set<Id>();
    roleId = [SELECT Id, DeveloperName FROM UserRole WHERE DeveloperName=:groupRole.get(fsGroup)][0].Id;
    roleIds.add(roleId);
    // Get all subordinate roles underneath
    Set<Id> allSubRoleIds = getAllSubRoleIds(roleIds);
    if (allSubRoleIds.size()>0) {
        roleIds.addAll(allSubRoleIds);
    }
    if ( roleIds.contains(usrRoleId) ) grpName = fsGroup;
}
    return grpName;

}



private static Set<ID> getAllSubRoleIds(Set<ID> roleIds) {
  	
    Set<ID> currentRoleIds = new Set<ID>();
    
    // get all of the roles underneath the passed roles
    for(UserRole userRole :[select Id from UserRole where ParentRoleId 
      IN :roleIds AND ParentRoleID != null])
    currentRoleIds.add(userRole.Id);
    
    // go fetch some more rolls!
    if(currentRoleIds.size() > 0)
      currentRoleIds.addAll(getAllSubRoleIds(currentRoleIds));

    return currentRoleIds;
    
  }





/*********
// From https://help.salesforce.com/s/articleView?id=000336905&type=1
// Used in sync sandbox but only returns single group - not effective.

Id usrId = '0058c000008TAQUAA4';

//Declaring a Set as we don't want Duplicate Group Ids
Set<Id> results = new Set<Id>();

///Declaring a Map for Group with Role
Map<Id,Id> grRoleMap = new Map<Id,Id>();

//Populating the Map with RelatedID(i.e.UserRoledId) as Key
for(Group gr : [select id,relatedid,name from Group])
{
	grRoleMap.put(gr.relatedId,gr.id);
}

//Groups directly associated to user
Set<Id> groupwithUser = new Set<Id>();

//Populating the Group with User with GroupId we are filtering only  for Group of Type Regular,Role and RoleAndSubordinates
for(GroupMember  u :[select groupId from GroupMember where UserOrGroupId= :usrId and (Group.Type = 'Regular' OR Group.Type='Role' OR Group.Type='RoleAndSubordinates')])
{
	groupwithUser.add(u.groupId);
}

//Groups with Role
for(User  u :[select UserRoleId from User where id= :usrId])
{
	//Checking if the current User Role is part of Map or not
	if(grRoleMap.containsKey(u.UserRoleId))
	{
		results.add(grRoleMap.get(u.UserRoleId));
	}
}
//Combining both the Set
results.addAll(groupwithUser);

//Traversing the whole list of Groups to check any other nested Group
Map<Id,Id> grMap = new Map<Id,Id>();
for(GroupMember gr : [select id,UserOrGroupId,Groupid from GroupMember where
        (Group.Type = 'Regular' OR Group.Type='Role' OR Group.Type='RoleAndSubordinates')])
{
	grMap.put(gr.UserOrGroupId,gr.Groupid);
}
for(Id i :results)
{
	if(grMap.containsKey(i))
	{
		results.add(grMap.get(i));
	}
}

for(Id i :results)
{
    system.debug('i: ' + i);
}

system.debug('########' + results);

**********/

/******** This one illustrates problem.
// Look up FS Public Groups and build Map of UserOrGroupIds by FSGroupName
Id usrId = '0058c000008TAQUAA4';


system.debug('***All groups***');
for(Group gr : [select id,relatedid,name, type from Group WHERE (Type = 'Regular' OR Type='Role' OR Type='RoleAndSubordinates')]) {
    system.debug('Group: ' + gr.name + '; Type: ' + gr.Type + ' (' + gr.Id + ')');
}

system.debug('Group userorgroupids for this group: 00G8c000005iv31EAA');
for (GroupMember gm : [SELECT Id, UserOrGroupId, Group.DeveloperName, Group.Id 
    FROM GroupMember 
    WHERE Group.Id = '00G8c000005iv31EAA']) {
        system.debug('UserOrGroupId: ' + gm.UserOrGroupId);
}



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
for (GroupMember gm : [SELECT Id, UserOrGroupId, Group.DeveloperName FROM GroupMember 
    WHERE Group.DeveloperName IN :groupNames]) {
	fsGroup = gm.Group.DeveloperName;
    if (fsGrpMemberIds.containsKey(fsGroup) ) {
		extSet = fsGrpMemberIds.get(fsGroup);
	} else {
		extSet = new Set<String>();
	}
    extSet.add(gm.UserOrGroupId);
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

// Plug UsrGrpIds in for other related groups.
for (GroupMember gm : [SELECT Id, UserOrGroupId, Group.DeveloperName, Group.Id 
    FROM GroupMember 
    WHERE UserOrGroupId IN :thisUsrGrpIds]) {
    System.debug('This is second group loop: ' + gm.Group.Id);
    thisUsrGrpIds.add(gm.Group.Id);
}

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

******/



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