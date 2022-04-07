ApexLog[] logs = [SELECT Id FROM ApexLog];
system.debug(logs.size());
/*
        insert new Account(
            Name = 'test_acct_1',
            RecordTypeId = Utilities.getRecTypeId('Account', 'HH_Account')
        );
        Account acct1 = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'test_acct_1'
            LIMIT 1
        ];
        system.debug(acct1);
*/