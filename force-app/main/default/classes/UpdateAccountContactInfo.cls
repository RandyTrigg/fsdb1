public class UpdateAccountContactInfo {
    public class myException extends Exception {
    }

    @InvocableMethod(
        label='Update account contact info'
        description='Update Contact Info GM field in account record.'
    )
    public static void UpdateAccountContactInfo(List<Id> accIds) {
        for (Id accId : accIds)
            handleRequest(accId);
    }

    // Look up emails, phones, address, and build (possibly new) contact info string.
    public static void handleRequest(Id accId) {
        system.debug('handleRequest: accId = ' + accId);
        // Get account info, including all necessary email- and contact info-related fields.
        Account acc = AccountController.fetchAccountsContactInfo(
            new Set<Id>{ accId }
        )[0];
        system.debug('handleRequest: acc = ' + JSON.serialize(acc));
        // Get linked addresses. Note that the current address (Yes) sorts ahead of others (No). If no current, then get most recent.
        List<Address__c> addrs = new List<Address__c>(
            [
                SELECT
                    Id,
                    Full_address__c,
                    Address_w_confidential__c,
                    IsCurrentActiveAddress__c,
                    LastModifiedDate,
                    Street__c,
                    Locality__c
                FROM Address__c
                WHERE
                    Account__c = :accId
                    AND (Street__c != null
                    OR Locality__c != null)
                ORDER BY IsCurrentActiveAddress__c DESC, LastModifiedDate DESC
            ]
        );
        system.debug('addrs = ' + JSON.serialize(addrs));
        Address__c addr = addrs.size() > 0 ? addrs[0] : null;
        List<String> emails = AccountController.emailsForAccount(acc);
        String contactInfo = buildContactInfoText(acc, emails, addr);
        String emailsStr = emails.size() > 0
            ? Utilities.stringJoinWithCharLimit(
                    new List<String>(emails),
                    ', ',
                    255
                )
            : null;
        // Update account if the new contact info is different from what was already there.
        system.debug('acc.Contact_info_GM__c = ' + acc.Contact_info_GM__c);
        system.debug('contactInfo = ' + contactInfo);
        system.debug('emailsStr = ' + emailsStr);
        if (
            contactInfo != acc.Contact_info_GM__c ||
            emailsStr != acc.Contact_emails_GM__c
        ) {
            acc.Contact_info_GM__c = contactInfo;
            acc.Contact_emails_GM__c = emailsStr;
            if (addr != null)
                acc.LinkedAddress__c = addr.Id;
            update acc;
            system.debug(
                'After update: acc.Contact_info_GM__c = ' +
                acc.Contact_info_GM__c
            );
        }
    }

    // Return contact info string for given account based on given applicant and address.
    // Pass address rather than fetching, because the record may not yet have been saved in database.
    public static String buildContactInfoText(
        Account acc,
        List<String> emails,
        Address__c addr
    ) {
        system.debug('buildContactInfoText...');
        system.debug('acc = ' + JSON.serialize(acc));
        system.debug('addr = ' + JSON.serialize(addr));
        // Gather phones.
        Set<String> phones = new Set<String>();
        if (acc.Phone != null)
            phones.add(acc.Phone);
        if (acc.Phone2__c != null)
            phones.add(acc.Phone2__c);
        // Build multi-line contact info string.
        List<String> lines = new List<String>();
        system.debug('acc.Contact_primary__c = ' + acc.Contact_primary__c);
        if (
            acc.Contact_primary__c != null &&
            acc.Contact_primary__r.Name != null
        )
            lines.add(acc.Contact_primary__r.Name);
        if (addr != null && addr.Address_w_confidential__c != null)
            lines.add(addr.Address_w_confidential__c.replace('<br>', '\n'));
        else if (acc.BillingAddress != null) {
            String[] lastAddrBits = Utilities.removeNulls(
                new List<String>{
                    acc.BillingState,
                    acc.BillingPostalCode,
                    acc.BillingCountry
                }
            );
            String endOfAddr = lastAddrBits != null
                ? String.join(lastAddrBits, ' ')
                : null;
            lines.add(
                String.join(
                    Utilities.removeNulls(
                        new List<String>{
                            acc.BillingStreet,
                            acc.BillingCity,
                            endOfAddr
                        }
                    ),
                    ', '
                )
            );
        }
        if (acc.Website != null)
            lines.add(acc.Website);
        if (emails.size() > 0)
            lines.add(String.join(emails, ', '));
        if (phones.size() > 0)
            lines.add(String.join(new List<String>(phones), ', '));
        return String.join(lines, '\n');
    }
}