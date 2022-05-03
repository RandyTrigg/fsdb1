// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

    List<Profile__c> runningProfile = new List<Profile__c>([SELECT ID FROM Profile__c WHERE Community_contact__c =:'123' LIMIT 1]);
System.debug('RunningProfile: ' + runningProfile);