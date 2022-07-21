// For proposals with no classification assigns, build new ones from their application form data.
Form_Data__c[] fds = [
    SELECT Data_text__c, Form_Instance__r.Proposal__c
    FROM Form_Data__c
    WHERE Form_Component__r.Name = 'ConstituenciesWhoAre'
    AND Form_Instance__r.Date_submitted__c <> null
    AND Form_Instance__r.Proposal__r.Date_received__c <> null
    AND Data_text__c <> null 
];
system.debug('fds.size()' +fds.size());
Map<Id, Proposal__c> props = new Map<Id, Proposal__c>([
    SELECT Id,
    (SELECT Id FROM Classification_Assigns__r)
    FROM Proposal__c
    WHERE Date_received__c <> null
    AND Id NOT IN (SELECT Proposal__c FROM Classification_Assign__c)
    AND Id IN (SELECT Proposal__c FROM Form_Instance__c)
]);
system.debug('props.size()' +props.size());
Classification__c[] cs = [SELECT Name FROM Classification__c WHERE Type__c = 'Population'];
Map<String, Classification__c> cMap = new Map<String, Classification__c>();
for (Classification__c c : cs) cMap.put(c.Name, c);
system.debug('cMap = ' +cMap);

Form_Picklist_Phrase__c[] fpps = [
    SELECT Id, Name, Form_Phrase__c, Form_Phrase__r.Phrase_in_English__c, Form_Phrase__r.Name
    FROM Form_Picklist_Phrase__c
    WHERE Form_Picklist__r.Name = 'ConstituenciesWhoAre'
];
// Map form phrase name to English value, aka classification name
Map<String, String> formPhraseMap = new Map<String, String>();
for (Form_Picklist_Phrase__c fpp : fpps) formPhraseMap.put(fpp.Form_Phrase__r.Name, fpp.Form_Phrase__r.Phrase_in_English__c);

system.debug('formPhraseMap = ' +formPhraseMap);
Classification_Assign__c[] toInsert = new List<Classification_Assign__c>();
for (Form_Data__c fd : fds) {
    String[] phraseNames = fd.Data_text__c.split('\\|');
    system.debug('phraseNames = ' +phraseNames);
    Proposal__c prop = props.get(fd.Form_Instance__r.Proposal__c);
    if (prop != null && phraseNames.size() > 0) {
        for (String phraseName : phraseNames) {
            if (phraseName != 'Other') {
                toInsert.add (new Classification_Assign__c (
                    Proposal__c = prop.Id,
                    Classification__c = cMap.get(formPhraseMap.get(phraseName)).Id
                ));
            }
        }
    }
}
system.debug('toInsert.size() = ' +toInsert.size());
system.debug('toInsert[0] = ' +toInsert[0]);
system.debug('toInsert[1] = ' +toInsert[1]);
if (toInsert.size() > 0) Database.executeBatch(new GenericInsertRecordsBatch(toInsert), 5);