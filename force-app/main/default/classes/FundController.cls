public with sharing class FundController {
    /**********************************
     * For general use
     *********************************/

    // Update totals for all funds.
    // The fund with given id (if non-null) is updated immediately, the others are updated in a batch process.
    public static void updateTotals(Id fundId) {
        // Get all funds.
        Map<Id, Fund__c> funds = new Map<Id, Fund__c>(
            [
                SELECT
                    Total_available__c,
                    RecordType.DeveloperName,
                    Fiscal_year__c
                FROM Fund__c
            ]
        );
        Integer batchSize = 100;
        Map<Id, Fund__c> fundsToUpdate = new Map<Id, Fund__c>();
        // Gather the overhead funds for updating based on non-grantmaking amounts of non-revenue projections.
        List<Fund__c> overheadFunds = [
            SELECT Fiscal_year__c
            FROM Fund__c
            WHERE RecordType.DeveloperName = 'Overhead'
        ];
        // Total overhead by fiscal year
        Map<String, Decimal> overheadTotals = new Map<String, Decimal>();
        for (Fund__c f : overheadFunds)
            overheadTotals.put(f.Fiscal_year__c, 0);
        // Total projection amounts by fund.
        List<AggregateResult> projGrouped = [
            SELECT
                SUM(Total_grantmaking__c) sumGM,
                SUM(Total_grantmaking_converted__c) sumGMConv,
                SUM(Total_non_grantmaking__c) sumNonGM,
                SUM(Total_amount__c) sum,
                Fund__c
            FROM Projection__c
            WHERE
                Fund__c != null
                AND Fund__c IN :funds.keySet()
                AND Total_amount__c > 0
            GROUP BY Fund__c
        ];
        // Total distribution amounts by fund.
        List<AggregateResult> distGrouped = [
            SELECT SUM(Amount__c) sum, Target_fund__c
            FROM Distribution__c
            WHERE
                Target_fund__c != null
                AND Target_fund__c IN :funds.keySet()
                AND Amount__c > 0
            GROUP BY Target_fund__c
        ];
        // Sum projections and distributions into lookup table of totals for the fund's auto-totaling field.
        Map<Id, Decimal> fundTotals = new Map<Id, Decimal>();
        for (AggregateResult t : projGrouped) {
            Fund__c f = funds.get((Id) t.get('Fund__c'));
            // Standard and Pending funds sum the grantmaking part of the projection.
            Decimal tot = (f.RecordType.DeveloperName == 'Standard' ||
                f.RecordType.DeveloperName == 'Pending')
                ? (Decimal) t.get('sumGMConv') // Use converted amounts, in case projections do currency conversion
                : (Decimal) t.get('sum');
            system.debug(
                'UpdateTotals: tot = ' +
                tot +
                '; f = ' +
                JSON.serialize(f)
            );
            fundTotals.put(
                f.Id,
                tot + (fundTotals.containsKey(f.Id) ? fundTotals.get(f.Id) : 0)
            );
            // Sum up the non-grantmaking into overhead.
            if (
                f.RecordType.DeveloperName != 'Revenue' &&
                f.RecordType.DeveloperName != 'Overhead' &&
                overheadTotals.containsKey(f.Fiscal_year__c)
            )
                overheadTotals.put(
                    f.Fiscal_year__c,
                    (Decimal) t.get('sumNonGM') +
                    overheadTotals.get(f.Fiscal_year__c)
                );
        }
        for (AggregateResult t : distGrouped) {
            Fund__c f = funds.get((Id) t.get('Target_fund__c'));
            fundTotals.put(
                f.Id,
                (Decimal) t.get('sum') +
                (fundTotals.containsKey(f.Id) ? fundTotals.get(f.Id) : 0)
            );
        }
        // Update totaling field in the affected funds.
        for (Fund__c f : funds.values()) {
            // If fund is for overhead, take accumulated total for the FY.
            if (f.RecordType.DeveloperName == 'Overhead') {
                String fy = f.Fiscal_year__c;
                if (
                    overheadTotals.containsKey(fy) &&
                    f.Total_available__c != overheadTotals.get(fy)
                ) {
                    f.Total_available__c = overheadTotals.get(fy);
                    fundsToUpdate.put(f.Id, f);
                }
            } else {
                // Non-overhead fund
                // Handle case where fund has projections/distributions and the total needs updating.
                if (
                    fundTotals.containsKey(f.Id) &&
                    f.Total_available__c != fundTotals.get(f.Id)
                ) {
                    f.Total_available__c = fundTotals.get(f.Id);
                    fundsToUpdate.put(f.Id, f);
                }
                // Handle case where fund has no projection/distributions, and total needs to be reset to zero.
                if (!fundTotals.containsKey(f.Id) && f.Total_available__c > 0) {
                    f.Total_available__c = 0;
                    fundsToUpdate.put(f.Id, f);
                }
            }
        }
        // If given fund needs updating, do it immediately.  Then do others in a batch process.
        Fund__c fund = fundId != null ? fundsToUpdate.remove(fundId) : null;
        if (fund != null)
            update fund;
        if (fundsToUpdate.size() > 0)
            Database.executeBatch(
                new GenericUpdateRecordsBatch(fundsToUpdate.values()),
                batchSize
            );
    }

    /**********************************
     * For use in Lightning components
     *********************************/

    // Fetch the fund's charges, projections, and distributions, after ensuring that totals released are up to date.
    // Include names of current user's permission sets, so lightning code can restrict permission to release/unrelease.
    @AuraEnabled
    public static String getRecordsForReleasing(String fundIdStr) {
        Id fundId = Id.valueOf(fundIdStr);
        strike_responseData responseData = new strike_responseData();
        try {
            updateProjsDistsReleasing(fundId);
            responseData.results = new Map<String, Object>{
                'charges' => getCharges(fundId),
                'projections' => getProjections(fundId),
                'distributions' => getDistributions(fundId),
                'permissionSets' => Utilities.currentUserPermissionSetNames()
            };
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        system.debug(
            'getRecordsForReleasing: responseData = ' +
            JSON.serialize(responseData)
        );
        return responseData.getJsonString();
    }

    // Ensure that the amount released fields in the fund's projections and distributions are up to date.
    public static void updateProjsDistsReleasing(Id fundId) {
        sObject[] toUpdate = new List<sObject>();
        Map<Id, Decimal> projTotals = new Map<Id, Decimal>();
        Map<Id, Decimal> distTotals = new Map<Id, Decimal>();
        Map<Id, Projection__c> projs = new Map<Id, Projection__c>(
            [
                SELECT Amount_released__c
                FROM Projection__c
                WHERE Fund__c = :fundId
            ]
        );
        Map<Id, Distribution__c> dists = new Map<Id, Distribution__c>(
            [
                SELECT Amount_released__c
                FROM Distribution__c
                WHERE Target_fund__c = :fundId
            ]
        );
        Charge__c[] charges = new List<Charge__c>(
            [
                SELECT Projection__c, Distribution__c, Amount_charged__c
                FROM Charge__c
                WHERE
                    Fund__c = :fundId
                    AND (Projection__c != null
                    OR Distribution__c != null)
            ]
        );
        // Total up charges linked to projections or distributions.
        for (Id pId : projs.keySet())
            projTotals.put(pId, 0);
        for (Id dId : dists.keySet())
            distTotals.put(dId, 0);
        for (Charge__c c : charges) {
            Id pId = c.Projection__c;
            Id dId = c.Distribution__c;
            if (pId != null)
                projTotals.put(pId, c.Amount_charged__c + projTotals.get(pId));
            else if (dId != null)
                distTotals.put(dId, c.Amount_charged__c + distTotals.get(dId));
        }
        // Gather projections/distributions whose releasing totals need updating.
        for (Projection__c p : projs.values()) {
            Decimal total = projTotals.get(p.Id);
            if (p.Amount_released__c != total) {
                p.Amount_released__c = total;
                toUpdate.add(p);
            }
        }
        for (Distribution__c d : dists.values()) {
            Decimal total = distTotals.get(d.Id);
            if (d.Amount_released__c != total) {
                d.Amount_released__c = total;
                toUpdate.add(d);
            }
        }
        if (toUpdate.size() > 0)
            update toUpdate;
    }

    public static List<Charge__c> getCharges(Id fundId) {
        String objName = 'Charge__c';
        String[] fieldNames = Utilities.fieldNamesForObject(objName);
        fieldNames.addAll(
            new List<String>{
                'Projection__r.Name',
                'Distribution__r.Name',
                'Proposal__r.Name',
                'Proposal__r.Account__c',
                'Proposal__r.Account__r.Name',
                'Proposal__r.Date_awarded__c'
            }
        );
        String q =
            'SELECT ' +
            String.join(fieldNames, ', ') +
            ' FROM ' +
            objName +
            ' WHERE Fund__c = : fundId';
        system.debug('getCharges: fundId = ' + fundId + '; q = ' + q);
        return Database.query(q);
    }

    public static List<Projection__c> getProjections(Id fundId) {
        String objName = 'Projection__c';
        String[] fieldNames = Utilities.fieldNamesForObject(objName);
        fieldNames.addAll(
            new List<String>{ 'Opportunity__r.Name', 'ChartofAccounts__r.Name' }
        );
        String q =
            'SELECT ' +
            String.join(fieldNames, ', ') +
            ' FROM ' +
            objName +
            ' WHERE Fund__c = : fundId';
        system.debug('getProjections: q = ' + q);
        return Database.query(q);
    }

    public static List<Distribution__c> getDistributions(Id fundId) {
        String objName = 'Distribution__c';
        String[] fieldNames = Utilities.fieldNamesForObject(objName);
        fieldNames.addAll(
            new List<String>{ 'Source_fund__r.Name', 'ChartofAccounts__r.Name' }
        );
        String q =
            'SELECT ' +
            String.join(fieldNames, ', ') +
            ' FROM ' +
            objName +
            ' WHERE Target_fund__c = : fundId';
        system.debug('getDistributions: q = ' + q);
        return Database.query(q);
    }

    // Release the charges selected in the lightning component app against given projection/distribution on given date.
    @AuraEnabled
    public static String releaseCharges(String jsonString) {
        sObject[] toUpdate = new List<sObject>();
        sObject[] toInsert = new List<sObject>();
        strike_responseData responseData = new strike_responseData();
        try {
            system.debug('releaseCharges: jsonString = ' + jsonString);
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(
                jsonString
            );
            system.debug(
                'releaseCharges: jsonMap = ' + JSON.serialize(jsonMap)
            );
            List<Object> chargeObjs = (List<Object>) jsonMap.get('chargeIds');
            List<String> chargeIds = new List<String>();
            for (Object cObj : chargeObjs)
                chargeIds.add(String.valueOf(cObj));
            system.debug('releaseCharges: chargeIds = ' + chargeIds);
            Id projId = jsonMap.get('projectionId') != null
                ? Id.valueOf((String) jsonMap.get('projectionId'))
                : null;
            Id distId = jsonMap.get('distributionId') != null
                ? Id.valueOf((String) jsonMap.get('distributionId'))
                : null;
            system.debug(
                'releaseCharges: projId = ' +
                projId +
                '; distId = ' +
                distId
            );
            Date dateReleased = Date.valueOf(
                (String) jsonMap.get('dateReleased')
            );
            // Fetch records
            Charge__c[] charges = new List<Charge__c>(
                [
                    SELECT
                        Amount_charged__c,
                        Projection__c,
                        Distribution__c,
                        Date_released__c,
                        Fund__c,
                        Proposal__c
                    FROM Charge__c
                    WHERE Id IN :chargeIds
                ]
            );
            Projection__c proj;
            Distribution__c dist;
            if (projId != null)
                proj = [
                    SELECT Amount_released__c, To_be_released__c
                    FROM Projection__c
                    WHERE Id = :projId
                ];
            else if (distId != null)
                dist = [
                    SELECT Amount_released__c, To_be_released__c
                    FROM Distribution__c
                    WHERE Id = :distId
                ];
            Decimal toBeRel = proj != null
                ? proj.To_be_released__c
                : dist != null ? dist.To_be_released__c : 0;
            Decimal total = 0;
            // Release charges until the total released passes the amount left to be released in the projection/distribution.
            for (Charge__c c : charges) {
                Decimal chgAmt = c.Amount_charged__c;
                if (c.Date_released__c != null)
                    continue; // Skip charges that have already been released.
                if (total + chgAmt > toBeRel) {
                    // This charge would overflow proj/dist.
                    // "Split" the charge by cloning so we fully release the proj/dist.
                    Charge__c newChg = c.clone(false, false, false, false);
                    // New charge holds the extra amount, and will not be released.
                    newChg.Amount_charged__c = total + chgAmt - toBeRel;
                    toInsert.add(newChg);
                    system.debug(
                        'releaseCharges cloning charge: total = ' +
                        total +
                        '; chgAmt = ' +
                        chgAmt +
                        '; toBeRel = ' +
                        toBeRel
                    );
                    system.debug(
                        'releaseCharges cloning charge: newChg = ' +
                        JSON.serialize(newChg)
                    );
                    // Reduce amount of original charge.
                    chgAmt = toBeRel - total;
                    c.Amount_charged__c = chgAmt;
                }
                // Release the charge.
                if (proj != null)
                    c.Projection__c = proj.Id;
                else if (dist != null)
                    c.Distribution__c = dist.Id;
                c.Date_released__c = dateReleased;
                toUpdate.add(c);
                total += chgAmt;
                if (total >= toBeRel)
                    break; // Bail if we've hit the proj/dist's limit.
            }
            if (toUpdate.size() > 0)
                update toUpdate;
            if (toInsert.size() > 0)
                insert toInsert;
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        system.debug(
            'getRecordsForReleasing: responseData = ' +
            JSON.serialize(responseData)
        );
        return responseData.getJsonString();
    }

    // Unrelease the charges selected in the lightning component app.
    @AuraEnabled
    public static String unreleaseCharges(String jsonString) {
        sObject[] toUpdate = new List<sObject>();
        strike_responseData responseData = new strike_responseData();
        try {
            system.debug('unreleaseCharges: jsonString = ' + jsonString);
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(
                jsonString
            );
            system.debug(
                'unreleaseCharges: jsonMap = ' + JSON.serialize(jsonMap)
            );
            List<Object> chargeObjs = (List<Object>) jsonMap.get('chargeIds');
            List<String> chargeIds = new List<String>();
            for (Object cObj : chargeObjs)
                chargeIds.add(String.valueOf(cObj));
            system.debug('unreleaseCharges: chargeIds = ' + chargeIds);
            // Fetch records
            Charge__c[] charges = new List<Charge__c>(
                [
                    SELECT
                        Amount_charged__c,
                        Projection__c,
                        Distribution__c,
                        Date_released__c
                    FROM Charge__c
                    WHERE Id IN :chargeIds
                ]
            );
            // Unrelease charges by clearing date released and the projection/distribution lookups.
            for (Charge__c c : charges) {
                // Skip charges that have already been released.
                if (
                    c.Date_released__c == null &&
                    c.Projection__c == null &&
                    c.Distribution__c == null
                )
                    continue;
                c.Projection__c = null;
                c.Distribution__c = null;
                c.Date_released__c = null;
                toUpdate.add(c);
            }
            if (toUpdate.size() > 0)
                update toUpdate;
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        system.debug(
            'getRecordsForReleasing: responseData = ' +
            JSON.serialize(responseData)
        );
        return responseData.getJsonString();
    }
}