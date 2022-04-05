public with sharing class ProposalUpdate {
    public static String GMAdminEmail = 'GMadmin@globalfundforwomen.org';

    /**********************************
     * Invoked when a proposal is created/updated, usually from process builder.
     *********************************/

    // To reduce SOQL call count, fetch proposal and all necessary related fields in one go.
    public static Proposal__c fetchProposalAndContext(Id propId) {
        // Build lists of relevant related fields for objects related to Proposal.
        Map<String, List<String>> relatedFieldsMap = new Map<String, List<String>>{
            'Account__r' => new List<String>{
                'Highlights__c',
                'Description',
                'Name',
                'GM_country__c',
                'GM_region__c',
                'GM_applicant__c',
                'First_grant__c',
                'Latest_grant__c'
            },
            'Payment_dependent_on_prior_grant__r' => new List<String>{
                'Status_numeric__c'
            },
            'Country__r' => new List<String>{ 'Region__c' },
            'Country_override__r' => new List<String>{ 'Region__c' },
            'Region_override__r' => new List<String>{ 'Name' },
            'Profile__r' => new List<String>{
                'Name',
                'Account__c',
                'Account__r.Name'
            }
        };
        // Build sub-queries for various child objects of Proposal.
        String[] childSubQueries = new List<String>{
            Utilities.buildChildSubQuery(
                'Milestone__c',
                'Milestones__r',
                'ORDER BY Date_due__c ASC'
            ),
            Utilities.buildChildSubQuery('Invite__c', 'Invites__r', null),
            Utilities.buildChildSubQuery(
                'Payment__c',
                'Payments__r',
                'ORDER BY CreatedDate DESC'
            ),
            Utilities.buildChildSubQuery(
                'Payment_Method__c',
                'Payment_Methods__r',
                'ORDER BY CreatedDate ASC'
            ),
            Utilities.buildChildSubQuery(
                'Portfolio_Assignment__c',
                'Initiative_Assignments__r',
                'WHERE Portfolio_type__c = \'Priority\''
            ),
            Utilities.buildChildSubQuery('Proposal__c', 'Proposals__r', null) // Payment-related dependent proposals
        };
        // Combine into one big list of related field references, and include child queries.
        String[] relatedFieldNames = new List<String>();
        for (String relName : relatedFieldsMap.keySet()) {
            for (String fName : relatedFieldsMap.get(relName))
                relatedFieldNames.add(relName + '.' + fName);
        }
        relatedFieldNames.addAll(childSubQueries);
        // Finally, fetch the proposal plus its context.
        return (Proposal__c) Utilities.fetchRecord(
            'Proposal__c',
            propId,
            relatedFieldNames
        );
    }

    // Perform necessary updates to proposal and related records.  Normally invoked when proposal is created or changed.
    // "allRecursiveCall" parameter used in testing to allow multiple calls for same proposal in single transaction.
    public static Proposal__c updateProposal(Id propId) {
        return updateProposal(propId, false);
    }
    public static Proposal__c updateProposal(
        Id propId,
        Boolean allowRecursiveCall
    ) {
        Map<Id, sObject> toUpdate = new Map<Id, sObject>(); // Related records to update (*after* this proposal)
        // Bail if we're in a recursive call.
        if (
            Utilities.SetOfIDsInProcess.contains(propId) && !allowRecursiveCall
        ) {
            system.debug(
                'updateProposal: skipping recursive call for propId = ' + propId
            );
            return null;
        } else
            Utilities.SetOfIDsInProcess.add(propId);
        // Fetch proposal and necessary related fields in one soql call.
        Proposal__c p = fetchProposalAndContext(propId);
        Boolean propNeedsUpdate = false;
        Account a = p.Account__r;
        Proposal__c[] dependentProps = p.Proposals__r;
        Boolean hasDependentProposals = dependentProps.size() > 0;
        Proposal__c[] accGrants = [
            SELECT Id, Date_awarded__c
            FROM Proposal__c
            WHERE Grant__c = true AND Account__c = :a.Id
            ORDER BY Date_awarded__c ASC
        ];
        // Build lists with for loops to avoid error: Aggregate query has too many rows for direct assignment
        Milestone__c[] milestones = new List<Milestone__c>();
        for (Milestone__c m : p.Milestones__r)
            milestones.add(m);
        Payment__c[] payments = new List<Payment__c>();
        for (Payment__c pay : p.Payments__r)
            payments.add(pay);
        Payment_Method__c[] paymentMeths = new List<Payment_Method__c>();
        for (Payment_Method__c pm : p.Payment_Methods__r)
            paymentMeths.add(pm);
        /**********************************
         * Milestone computations
         *********************************/
        Milestone__c recentMilestone,
            nextMilestone,
            currentPaymentMilestone,
            lastPaymentMilestone;
        Date projectedEndDate;
        String[] pendingMilestoneDescriptionList = new List<String>();
        // Compute total paid and date of first/last payment for each payment milestone.
        Map<Id, Double> totalMap = new Map<Id, Double>();
        Map<Id, Date> firstDateMap = new Map<Id, Date>();
        Map<Id, Date> lastDateMap = new Map<Id, Date>();
        for (Payment__c pay : payments) {
            if (
                pay.Milestone__c != null &&
                pay.Date_paid__c != null &&
                pay.Amount_paid__c != null
            ) {
                Id mId = pay.Milestone__c;
                if (!totalMap.containsKey(mId)) {
                    totalMap.put(mId, pay.Amount_paid__c);
                    firstDateMap.put(mId, pay.Date_paid__c);
                    lastDateMap.put(mId, pay.Date_paid__c);
                } else {
                    totalMap.put(mId, totalMap.get(mId) + pay.Amount_paid__c);
                    firstDateMap.put(
                        mId,
                        Utilities.minDate(
                            firstDateMap.get(mId),
                            pay.Date_paid__c
                        )
                    );
                    lastDateMap.put(
                        mId,
                        Utilities.maxDate(
                            lastDateMap.get(mId),
                            pay.Date_paid__c
                        )
                    );
                }
            }
        }
        // Update milestones where necessary.
        for (Milestone__c m : milestones) {
            if (
                m.Type__c == 'Payment' &&
                m.Date_completed__c == null &&
                totalMap.containsKey(m.Id)
            ) {
                if (
                    m.Planned_amount__c == null ||
                    totalMap.get(m.Id) >= m.Planned_amount__c
                ) {
                    m.Date_completed__c = lastDateMap.get(m.Id);
                    toUpdate.put(m.Id, m);
                }
                if (m.Date_of_first_payment_actual__c == null) {
                    m.Date_of_first_payment_actual__c = firstDateMap.get(m.Id);
                    toUpdate.put(m.Id, m);
                }
            }
        }
        // Compute lookups for most recently received milestone, and next due milestone.
        for (Milestone__c m : milestones) {
            if (m.Date_completed__c != null) {
                // See if completed milestone is recent
                if (
                    recentMilestone == null ||
                    m.Date_completed__c > recentMilestone.Date_completed__c
                )
                    recentMilestone = m;
            } else {
                // Milestone is pending
                // Append to pending descriptions
                pendingMilestoneDescriptionList.add(
                    m.Type__c +
                    ': ' +
                    (m.Date_due__c != null ? m.Date_due__c.format() : '')
                );
                if (
                    // See if it's next pending
                    nextMilestone == null ||
                    m.Date_due__c < nextMilestone.Date_due__c
                )
                    nextMilestone = m;
            }
            if (
                m.Type__c == 'Payment' &&
                m.Date_completed__c == null &&
                (currentPaymentMilestone == null ||
                m.Date_due__c < currentPaymentMilestone.Date_due__c)
            )
                currentPaymentMilestone = m;
            if (
                // Compute last payment milestone whether completed or not.
                m.Type__c == 'Payment' &&
                (lastPaymentMilestone == null ||
                m.Date_due__c > lastPaymentMilestone.Date_due__c)
            )
                lastPaymentMilestone = m;
            if (projectedEndDate == null || m.Date_due__c > projectedEndDate)
                projectedEndDate = m.Date_due__c;
        }
        // If couldn't find a pending payment milestone, then use the last payment milestone even if completed.
        if (currentPaymentMilestone == null)
            currentPaymentMilestone = lastPaymentMilestone;
        // Update milestone lookup fields in proposal where necessary
        Id recentMilestoneId = recentMilestone != null
            ? recentMilestone.Id
            : null;
        Id nextMilestoneId = nextMilestone != null ? nextMilestone.Id : null;
        Id currentPaymentMilestoneId = currentPaymentMilestone != null
            ? currentPaymentMilestone.Id
            : null;
        if (recentMilestoneId != p.Milestone_recent__c) {
            p.Milestone_recent__c = recentMilestoneId;
            propNeedsUpdate = true;
        }
        p.Milestone_recent__r = recentMilestone;
        if (nextMilestoneId != p.Next_milestone_due__c) {
            p.Next_milestone_due__c = nextMilestoneId;
            propNeedsUpdate = true;
        }
        p.Next_milestone_due__r = nextMilestone;
        if (currentPaymentMilestoneId != p.Current_payment_milestone__c) {
            p.Current_payment_milestone__c = currentPaymentMilestoneId;
            propNeedsUpdate = true;
        }
        p.Current_payment_milestone__r = currentPaymentMilestone;
        /**********************************
         * Payment computations
         *********************************/
        // Compute total net paid.
        Decimal paidToDate = 0;
        for (Payment__c payment : payments)
            paidToDate += payment.Net_paid__c;
        // Pick as current payment, the latest that isn't inactive.  (Payments are sorted reverse-chron by created date.)
        // Because of race conditions, need to compute inactive here rather than trusting the payment's Is_inactive__c field.
        Payment__c pay;
        for (Payment__c payment : payments) {
            // Skip inactive payments, that is, those that are returned and the grant is fully paid.
            if (
                payment.Date_returned__c != null &&
                p.Amount_awarded__c == paidToDate
            )
                continue;
            pay = payment;
            break;
        }
        system.debug('updateProposal: pay = ' + JSON.serialize(pay));
        // Update recent payment lookup field in proposal if necessary
        Id recentPaymentId = pay != null ? pay.Id : null;
        if (recentPaymentId != p.Payment_recent__c) {
            p.Payment_recent__c = recentPaymentId;
            propNeedsUpdate = true;
        }
        p.Payment_recent__r = pay;
        Proposal__c priorGrant = p.Payment_dependent_on_prior_grant__r;
        /**********************************
         * Payment Method computations
         *********************************/
        // Recompute first and most recent payment method.
        Payment_Method__c payMeth, firstPayMeth;
        if (paymentMeths.size() > 0) {
            payMeth = paymentMeths[paymentMeths.size() - 1];
            firstPayMeth = paymentMeths[0];
        }
        system.debug('updateProposal: payMeth = ' + JSON.serialize(payMeth));
        // Update current/first payment method lookup fields in proposal if necessary
        Id firstPaymentMethodId = firstPayMeth != null ? firstPayMeth.Id : null;
        Id currentPaymentMethodId = payMeth != null ? payMeth.Id : null;
        if (firstPaymentMethodId != p.First_payment_method__c) {
            p.First_payment_method__c = firstPaymentMethodId;
            propNeedsUpdate = true;
        }
        p.First_payment_method__r = firstPayMeth;
        if (currentPaymentMethodId != p.Current_payment_method__c) {
            p.Current_payment_method__c = currentPaymentMethodId;
            propNeedsUpdate = true;
        }
        p.Current_payment_method__r = payMeth;
        /**********************************
         * Proposal status computations
         *********************************/
        // Vars for status-related fields
        String statusUnderReview,
            statusContract1,
            statusContract2,
            statusContract3,
            statusContract,
            statusPayment1,
            statusPayment2,
            statusPayment,
            statusMilestone,
            statusClosing,
            status,
            statusStage;
        Decimal statusNumeric;
        // Vars for other fields
        Id countryId, regionId, regionOverrideId, firstGrantId, latestGrantId;
        // Build interpreter for status calculations.
        Template__c t = [
            SELECT Id
            FROM Template__c
            WHERE Name = 'Proposal status'
        ];
        TemplateController.TemplateMacros tm = new TemplateController.TemplateMacros(
            t.Id
        );
        tm.initialize(p);
        // Compute status parts first to cache results, reducing recursion depth for the grand STATUS calculation.
        statusUnderReview = (String) tm.evaluate('STATUS UNDER REVIEW');
        statusContract = (String) tm.evaluate('STATUS CONTRACT');
        statusPayment = (String) tm.evaluate('STATUS PAYMENT');
        statusMilestone = (String) tm.evaluate('STATUS MILESTONE');
        statusClosing = (String) tm.evaluate('STATUS CLOSING');
        status = (String) tm.evaluate('STATUS');
        system.debug(
            'updateProposal: status numeric = ' + tm.evaluate('STATUS NUMERIC')
        );
        statusNumeric = (Decimal) tm.evaluate('STATUS NUMERIC');
        statusStage = (String) tm.evaluate('STATUS STAGE');
        system.debug(
            'updateProposal: status = ' +
            status +
            '; statusNumeric = ' +
            statusNumeric +
            '; statusStage = ' +
            statusStage
        );
        /**********************************
         * Other non-status updates in Proposal
         *********************************/
        // Geography fields
        regionOverrideId = p.Country_override__c != null
            ? p.Country_override__r.Region__c
            : p.Region_override__c;
        // Note that if any of the geography overrides are non-blank, then we use the prop's override rather than what's in the account.
        countryId = p.Country_override__c != null ||
            p.Region_override__c != null
            ? p.Country_override__c
            : a.GM_country__c;
        regionId = p.Country_override__c != null ||
            p.Region_override__c != null
            ? regionOverrideId
            : a.GM_region__c;
        // Assign default custom reqs if currently blank, there's an app type, and status isn't >=9.1 in the last year.
        // Otherwise, keep the old one.  Note that we're using the newly calculated status.
        Id customReqsId, newCustomReqsId;
        if (
            p.Custom_Reqs__c == null &&
            p.Grant_type__c != null &&
            statusNumeric >= 1
        ) {
            // Lookup the default custom reqs record for the prop's app type from custom metadata type.
            Grant_type__mdt[] grantTypeMetadata = [
                SELECT Label, Default_custom_reqs_name__c
                FROM Grant_type__mdt
                WHERE Label = :p.Grant_type__c
            ];
            String customReqsName = grantTypeMetadata.size() > 0
                ? grantTypeMetadata[0].Default_custom_reqs_name__c
                : null;
            if (customReqsName != null) {
                Custom_Reqs__c[] customReqs = [
                    SELECT Id
                    FROM Custom_Reqs__c
                    WHERE Name = :customReqsName
                ];
                if (customReqs.size() > 0)
                    newCustomReqsId = customReqs[0].Id;
            }
        }
        customReqsId = newCustomReqsId != null
            ? newCustomReqsId
            : p.Custom_Reqs__c;
        String pendingMilestoneDescriptions = String.join(
            pendingMilestoneDescriptionList,
            '\n'
        );
        /**********************************
         * Update proposal record if necessary
         *********************************/
        propNeedsUpdate =
            propNeedsUpdate ||
            regionOverrideId != p.Region_override__c ||
            countryId != p.Country__c ||
            regionId != p.Region__c ||
            projectedEndDate != p.Projected_end_date__c ||
            hasDependentProposals != p.Has_dependent_proposals__c ||
            customReqsId != p.Custom_Reqs__c ||
            pendingMilestoneDescriptions !=
            p.Pending_milestone_descriptions__c ||
            statusClosing != p.Status_closing__c ||
            statusMilestone != p.Status_milestone__c ||
            statusPayment != p.Status_payment__c ||
            statusContract != p.Status_contract__c ||
            statusUnderReview != p.Status_under_review__c ||
            status != p.Status__c ||
            statusStage != p.Status_stage__c;
        system.debug('updateProposal: propNeedsUpdate = ' + propNeedsUpdate);
        if (propNeedsUpdate) {
            p.Status_under_review__c = statusUnderReview;
            p.Status_contract__c = statusContract;
            p.Status_payment__c = statusPayment;
            p.Status_milestone__c = statusMilestone;
            p.Status_closing__c = statusClosing;
            p.Status__c = status;
            p.Status_stage__c = statusStage;
            p.Region_override__c = regionOverrideId;
            p.Country__c = countryId;
            p.Region__c = regionId;
            p.Projected_end_date__c = projectedEndDate;
            p.Has_dependent_proposals__c = hasDependentProposals;
            p.Custom_Reqs__c = customReqsId;
            p.Pending_milestone_descriptions__c = pendingMilestoneDescriptions;
        }
        /**********************************
         * Update account record if necessary
         *********************************/
        // Find first and last grants for the account, and update account if necessary.
        if (accGrants.size() > 0) {
            firstGrantId = accGrants[0].Id;
            latestGrantId = accGrants[accGrants.size() - 1].Id;
        }
        if (
            !a.GM_applicant__c ||
            firstGrantId != a.First_grant__c ||
            latestGrantId != a.Latest_grant__c
        ) {
            a.GM_applicant__c = true;
            a.First_grant__c = firstGrantId;
            a.Latest_grant__c = latestGrantId;
            toUpdate.put(a.Id, a);
        }
        /**********************************
         * Update profile record if necessary
         *********************************/
        if (p.Profile__c != null && p.Profile__r.Account__c == null) {
            p.Profile__r.Account__c = p.Account__c;
            toUpdate.put(p.Profile__c, p.Profile__r);
        }
        /**********************************
         * Update invite record(s) if necessary
         *********************************/
        for (Invite__c i : p.Invites__r) {
            if (
                i.Amount_awarded__c != i.Amount_awarded_formula__c ||
                i.Grant__c != i.Grant_formula__c
            ) {
                i.Amount_awarded__c = i.Amount_awarded_formula__c;
                i.Grant__c = i.Grant_formula__c;
                toUpdate.put(i.Id, i);
            }
        }
        /**********************************
         * Update dependent proposals if we're updating this proposal.
         * Also update the one we're dependent on, if any.
         * Note that this bi-directional update causes a recursive call, which is one reason for the recursive test at the top of this method.
         *********************************/
        if (propNeedsUpdate) {
            for (Proposal__c depProp : dependentProps)
                toUpdate.put(depProp.Id, depProp);
            if (priorGrant != null)
                toUpdate.put(priorGrant.Id, priorGrant);
        }
        /**********************************
         * Send alert email if there's a clash between proposal's account and the linked profile's account (if any).
         *********************************/
        if (
            p.Profile__r.Account__c != null &&
            p.Account__c != p.Profile__r.Account__c
        ) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ GMAdminEmail });
            mail.setCcAddresses(new List<String>{ Utilities.EmailAddressIM });
            mail.setSubject('Auto-alert: Profile/proposal account clash');
            String[] bodyLines = new List<String>{
                'Profile: ' +
                p.Profile__r.Name +
                ' (' +
                +Utilities.BaseURL +
                p.Profile__c +
                ')',
                'Proposal: ' +
                p.Name +
                ' (' +
                +Utilities.BaseURL +
                p.Id +
                ')',
                '',
                'Profile account: ' +
                p.Profile__r.Account__r.Name +
                ' (' +
                Utilities.BaseURL +
                p.Profile__r.Account__c +
                ')',
                '',
                'Proposal account: ' +
                p.Account__r.Name +
                ' (' +
                Utilities.BaseURL +
                p.Account__c +
                ')'
            };
            mail.setPlainTextBody(String.join(bodyLines, '\n'));
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
        /**********************************
         * Update proposal before updating any other records that were touched.
         *********************************/
        if (propNeedsUpdate)
            update p;
        if (toUpdate.size() > 0)
            update toUpdate.values();
        // Update/build milestone record(s) if necessary (note that DML's are performed by buildMilestones).
        MilestoneController.buildMilestones(p.Id);
        return p;
    }
}