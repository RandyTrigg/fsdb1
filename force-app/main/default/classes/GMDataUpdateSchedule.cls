/*
 * Update the risk fields in gm data for under review props.
 */
global class GMDataUpdateSchedule implements Schedulable {
    global void execute(SchedulableContext scMain) {
        Map<Id, GM_Data__c> gmDatas = new Map<Id, GM_Data__c>(
            [
                SELECT Id
                FROM GM_Data__c
                WHERE
                    Proposal__c != null
                    AND Proposal__r.Date_declined__c = null
                    AND Proposal__r.Date_awarded__c = null
                    AND Proposal__r.Date_request_withdrawn__c = null
                    AND Proposal__r.Date_award_withdrawn__c = null
            ]
        );
        GMDataController.updateGMData(gmDatas.keySet());
    }
}