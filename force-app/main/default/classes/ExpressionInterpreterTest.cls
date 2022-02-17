@isTest
public with sharing class ExpressionInterpreterTest {
    static testMethod void ExpressionInterpreterTest() {
        // Build 1 new proposal/account/contact
        BuildTestProposals.InitTestObjects(1, 1);
        Account acc = [SELECT Name FROM Account LIMIT 1];
        Decline_Reason__c dr = new Decline_Reason__c(
            Name = '1A US-based group'
        );
        insert dr;
        Proposal__c prop = [SELECT Id FROM Proposal__c LIMIT 1];
        prop.Decline_reason__c = dr.Id;
        update prop;
        Referral_Org__c rOrg1 = new Referral_Org__c(
            Name = 'RefOrg1',
            Contact_info__c = 'Contact Info 1'
        );
        Referral_Org__c rOrg2 = new Referral_Org__c(
            Name = 'RefOrg2',
            Contact_info__c = 'Contact Info 2'
        );
        insert (new List<Referral_Org__c>{ rOrg1, rOrg2 });
        Referral__c ref1 = new Referral__c(
            Referral_Org__c = rOrg1.Id,
            Proposal__c = prop.Id
        );
        Referral__c ref2 = new Referral__c(
            Referral_Org__c = rOrg2.Id,
            Proposal__c = prop.Id
        );
        insert (new List<Referral__c>{ ref1, ref2 });
        Contact con = [SELECT AccountId, LastName, Email FROM Contact LIMIT 1];
        Template__c template = new Template__c(
            Name = 'Test template',
            Type__c = 'Grantmaking'
        );
        insert template;
        Letter__c let = new Letter__c(
            Template__c = template.Id,
            Account__c = acc.Id,
            Contact__c = con.Id,
            Proposal__c = prop.Id
        );
        insert let;
        SObject letterDB = [
            SELECT
                Id,
                Contact__r.AccountId,
                Contact__r.Email,
                Account__r.Name,
                Proposal__c,
                Proposal__r.Decline_Reason__r.Name,
                Account__r.BillingStreet,
                Account__r.BillingCity,
                Account__r.BillingState,
                Account__r.BillingPostalCode,
                Account__r.BillingCountry
            FROM Letter__c
            WHERE id = :let.id
            LIMIT 1
        ];

        Test.StartTest();
        String inputString;
        ExpressionInterpreter parser;
        ExpressionLexer lexer;
        Object result;
        Date d;

        inputString = '/* This is all just comment*/';
        parser = new ExpressionInterpreter(letterDB);
        system.assert(String.isBlank((String) parser.interpret(inputString)));

        inputString = 'CONCATENATE(LEFT("abc", 2), RIGHT("abc", 1), LEFT("abc", 0), LEFT("", 1))';
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals('abc', (String) parser.interpret(inputString));

        inputString = 'CONCATENATE(TEXT(FIND("abcdeabcde", "de")), " | ", TEXT(FIND("abcdeabcde", "de", VALUE("6"))))';
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals('4 | 9', (String) parser.interpret(inputString));

        inputString = 'CONCATENATE (Contact.Email, " ", Account.Name, [[ABC]], {{DEF}})';
        lexer = new ExpressionLexer(inputString, ExpressionInterpreter.symbols);
        Set<String> fNames = lexer.fieldNames();
        system.assertEquals(2, fNames.size()); // Embedded macro [[ABC]] and piece {{DEF}} calls should be ignored.
        system.assert(fNames.contains('Account.Name'));
        system.assert(fNames.contains('Contact.Email'));
        system.assertEquals(
            ExpressionLexer.TokenType.STRING_TOKEN,
            lexer.getType('Account', 'Name')
        );

        inputString = 'CONCATENATE (Contact.Email, " ", Account.Name)';
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(
            'ptest_0@ptest.org ptest_acct_0',
            parser.interpret(inputString)
        );

        inputString = 'IF (AND(!(1!=ROUND(2*1,0)), 1>2, 1>=2, 2<1, 2<=1, (true ? true : false)), ((2-1) * -4) + (1 / 1), 3)';
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(3, (Decimal) parser.interpret(inputString));

        inputString = 'IF (OR(AND(CONTAINS(LOWER("ABC"),"a"),CONTAINS("A", "")),CONTAINS("", "A")), 2, 3)';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(2, (Decimal) parser.interpret(inputString));

        inputString = 'IF(NOT(ISBLANK(Account.BillingStreet)), CONCATENATE(Account.BillingStreet, BR()), "")';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals('', (String) parser.interpret(inputString));

        inputString = '1 <= 2 ? DATE(2014, 12, 19) : "Do not eval"';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        result = parser.interpret(inputString);
        system.assert(result instanceof Date);
        d = (Date) result;
        system.assertEquals(2014, d.Year());

        inputString = 'DATEADDDAYS(DATE(2014, 12, 19), 5)';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        result = parser.interpret(inputString);
        system.assert(result instanceof Date);
        d = (Date) result;
        system.assertEquals(24, d.Day());

        inputString = '(DATE(2014, 12, 19) >= DATE(2013, 3, 4)) || (DATE(2014, 12, 19) <= DATE(2013, 3, 4)) || (DATE(2014, 12, 19) == DATE(2013, 3, 4))';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assert((Boolean) parser.interpret(inputString));

        inputString = 'LEN("abcdefg")';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(7, (Decimal) parser.interpret(inputString));

        String s1 = Datetime.valueof('2015-03-01 00:00:00')
            .format('MMMM d, yyyy');
        inputString = 'CONTAINS(CONCATENATE (DATEVALUE(TODAY()), DATEVALUE("2015-03-01 00:00:00")), "20")';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assert((Boolean) parser.interpret(inputString));

        inputString = 'CASE("a", "d", "no", "b", "not", "a", TEXT(FLOOR(14.0000)), "what up?")';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals('14', (String) parser.interpret(inputString));

        inputString = 'CASEFM(1 == -2, "no", 2 == 2, "yes", "otherwise")';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals('yes', (String) parser.interpret(inputString));

        inputString = 'CURRENCY(2000.1)';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals('2,000.10', (String) parser.interpret(inputString));

        inputString = 'CURRENCYROUND(2000.1, "English")';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals('2,000', (String) parser.interpret(inputString));

        inputString = 'CURRENCYROUND(2000.1, "French")';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals('2.000', (String) parser.interpret(inputString));

        inputString = 'TRANSLATEDATE("French", DATE(2015, 1, 31))';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(
            'le 31 janvier 2015',
            (String) parser.interpret(inputString)
        );

        inputString = 'TRANSLATEDATEMONTHYEAR("Spanish", DATE(2015, 1, 31))';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(
            'enero 2015',
            (String) parser.interpret(inputString)
        );

        inputString = 'CONCATENATE("-", "a")';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals('-a', (String) parser.interpret(inputString));

        inputString = 'CONCATENATE(TEXT(YEAR(DATE(2015, 1, 31))), "-", TEXT(MONTH(DATE(2015, 1, 31))), "-", TEXT(DAY(DATE(2015, 1, 31))))';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(
            '2015-1-31',
            (String) parser.interpret(inputString)
        );

        inputString = 'REFERRALS(Proposal__c)';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(
            '<b>RefOrg1</b><br>Contact Info 1<br><br><b>RefOrg2</b><br>Contact Info 2<br><br>',
            ((String) parser.interpret(inputString)).unescapeHtml4()
        );

        inputString = '1 == 1 ? "Ternary test true" : "Ternary test false"';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(
            'Ternary test true',
            (String) parser.interpret(inputString)
        );

        inputString = '1 == 2 ? UnknownField : "Skipped unknown field!"';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(
            'Skipped unknown field!',
            parser.interpret(inputString)
        );

        inputString = 'FY(DATE(2015, 1, 31)) & " " & FY(DATE(2015, 12, 31))';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(
            'FY2014-2015 FY2015-2016',
            (String) parser.interpret(inputString)
        );

        inputString =
            'TRIM(CONCATENATE( ' +
            'IF(NOT(ISBLANK(Account.Name)), CONCATENATE(Account.Name, BR()), ""),' +
            'IF(NOT(ISBLANK(Account.BillingStreet)), CONCATENATE(Account.BillingStreet, BR()), ""),' +
            'SUBSTITUTE(TRIM(CONCATENATE(TEXT(Account.BillingCity), BR(), TEXT(Account.BillingState))), BR(), ", "),' +
            '" ",' +
            'IF(NOT(ISBLANK(Account.BillingPostalCode)), Account.BillingPostalCode, ""),' +
            'IF(' +
            'NOT(ISBLANK(Account.BillingCountry)) && ' +
            'Account.BillingCountry != "US" && ' +
            'Account.BillingCountry != "USA", ' +
            'CONCATENATE(BR(), Account.BillingCountry), ""' +
            ')' +
            '))';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(
            'ptest_ac',
            ((String) parser.interpret(inputString)).left(8)
        );

        inputString = 'DATE(2015, 1, 7) - DATE(2015, 1, 1)';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(6, parser.interpret(inputString));

        inputString = 'PIECE(Proposal.Decline_reason__c.Name)';
        system.debug('Test case: ' + inputString);
        parser = new ExpressionInterpreter(letterDB);
        system.assertEquals(
            '{{1A US-based group}}',
            (String) parser.interpret(inputString)
        );

        // Run inputStrings with errors just to get code coverage on the error conditions.
        List<String> inputStrings = new List<String>{
            'NOT_REAL(1)',
            'AND(1)',
            'BR(1)',
            'CASE(1)',
            'CASEFM(1)',
            'CONTAINS(1, 1)',
            'CURRENCY("a")',
            'DATE("a",1,1)',
            'DATEVALUE(1)',
            'DAY(1)',
            'FLOOR("a")',
            'FY(1)',
            'IF(1,1,1)',
            'LEN(1)',
            'LEFT(1,1)',
            'LOWER(1)',
            'MONTH(1)',
            'NOT(1)',
            'OR(1)',
            'PIECE(1)',
            'REFERRALS(1)',
            'RIGHT(1,1)',
            'ROUND("a")',
            'SUBSTITUTE(1,1,1)',
            'TODAY(1)',
            'TEXT(1,1)',
            'TRANSLATEDATE(1,1)',
            'TRANSLATEDATEMONTHYEAR(1,1)',
            'TRIM(1)',
            'YEAR(1)'
        };
        for (String s : inputStrings)
            try {
                // Fire things up and catch the error, in order to get code coverage.
                (new ExpressionInterpreter(letterDB)).interpret(s);
            } catch (exception ExpressionException) {
            }

        Test.StopTest();
    }
}