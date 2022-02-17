global class ProfileCloneBatch implements Database.Batchable<sObject>, Database.Stateful {
    global final String query;
    global final List<Id> profileIds;
    global Map<Id, Profile__c> pCloneMap = new Map<Id, Profile__c>();

    global ProfileCloneBatch(String q) {
        system.debug('ProfileCloneBatch create: q = ' + q);
        query = q;
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        system.debug('ProfileCloneBatch start: query = ' + query);
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<sObject> scope) {
        system.debug(
            'ProfileCloneBatch execute: scope = ' + JSON.serialize(scope)
        );
        Map<Id, Profile__c> pMap = new Map<Id, Profile__c>(
            (List<Profile__c>) scope
        );
        // Clone profiles and gather results.
        // Note that we're cloning one profile at a time, so keep the batch size small.
        for (Profile__c p : pMap.values()) {
            system.debug('ProfileCloneBatch execute in loop: p.Id = ' + p.Id);
            Profile__c pClone = ProfileController.profileDeepClone(p.Id);
            // Don't send notification email if the original profile was ineligible, that is, had a type 1 decline reason.
            Boolean ineligible =
                p.Decline_reason__c != null &&
                p.Decline_reason__r.Name.startsWith('1');
            if (pClone != null && !ineligible)
                pCloneMap.put(pClone.Id, pClone);
        }
    }

    global void finish(Database.BatchableContext BC) {
        AsyncApexJob a = [
            SELECT
                Id,
                Status,
                NumberOfErrors,
                JobItemsProcessed,
                TotalJobItems,
                CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :BC.getJobId()
        ];
        system.debug('ProfileCloneBatch finish: a = ' + JSON.serialize(a));
        // Send error email if there were errors.
        if (a.NumberOfErrors > 0)
            Utilities.BatchErrorEmail('ProfileCloneBatch', a);
        else
            // Send notification emails to group.
            ProfileController.sendCloneNotificationEmails(pCloneMap.keySet());
    }
}