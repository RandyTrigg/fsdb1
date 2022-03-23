public with sharing class ExpressionFunctions {
    // All function classes implement this interface, specifying the number of args (or -1 if any number is permitted), and
    // the function's implementation.
    public interface function {
        Integer numArgs();
        Object function(List<Object> arguments, Integer fPosition);
    }

    public Object evaluate(
        String fName,
        List<Object> arguments,
        Integer fPosition
    ) {
        system.debug(
            'ExpressionFunctions, in "evaluate", fName = ' +
            fName +
            '; arguments = ' +
            JSON.serialize(arguments) +
            '; fPosition = ' +
            fPosition
        );
        // Build new instance of function implementation class.
        Type t = Type.forName('ExpressionFunctions.' + fName + '_function');
        // Check for unknown function.
        if (t == null) {
            // Unknown function error
            throw new ExpressionException(
                'Unknown function ' + fName,
                fPosition
            );
        }
        Function f = (Function) t.newInstance();
        // Check for wrong number of arguments.
        // If f.numArgs() is -1, then any number of arguments is fine.
        Integer argsCount = f.numArgs();
        if (argsCount >= 0 && argsCount != arguments.size()) {
            throw new ExpressionException(
                fName +
                ' function must have ' +
                argsCount +
                '  arguments. ' +
                arguments.size() +
                ' provided.',
                fPosition
            );
        }
        // Execute the function.
        return f.function(arguments, fPosition);
    }

    /*
     * Classes implementing each of the permitted functions.
     * The class name is formed from the function name (usually taken from SF's formula interface) followed by '_function'.
     * NOTE: Try to keep these alphabetized for easy lookup!
     */

    public with sharing class BR_function implements function {
        public Integer numArgs() {
            return 0;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            return '\n';
        }
    }

    public with sharing class CONCATENATE_function implements function {
        public Integer numArgs() {
            return -1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            Object result = '';
            for (Object arg : arguments) {
                if (arg instanceof String) {
                    result = result + (String) arg;
                } else if (arg != null) {
                    throw new ExpressionException(
                        'Type mismatch: arguments to CONCATENATE must be strings but were ' +
                        JSON.serialize(arguments),
                        fPosition
                    );
                }
            }
            return result;
        }
    }

    public with sharing class CONTAINS_function implements function {
        public Integer numArgs() {
            return 2;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null) {
                return false;
            } else if (arguments[1] == null) {
                return true;
            } else if (
                arguments[0] instanceof String && arguments[1] instanceof String
            ) {
                return ((String) arguments[0]).contains((String) arguments[1]);
            } else {
                throw new ExpressionException(
                    'Type mismatch: arguments to CONTAINS must be strings but were ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    // This one is not in SF's standard list of formula functions. Uses a function scarfed from stackexchange.
    public with sharing class CURRENCY_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null || arguments[0] instanceof Decimal) {
                return Utilities.formatCurrency((Decimal) arguments[0]);
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to CURRENCY must be number but was ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    // Convert decimal to text with commas after rounding, taking account of language.
    public with sharing class CURRENCYROUND_function implements function {
        public Integer numArgs() {
            return 2;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (
                arguments[0] == null ||
                (arguments[0] instanceof Decimal &&
                arguments[1] instanceof String)
            ) {
                String language = (String) arguments[1];
                String result = Utilities.formatInteger((Decimal) arguments[0]);
                if (language == 'French')
                    result = result.replace(',', '.');
                return result;
            } else {
                throw new ExpressionException(
                    'Type mismatch: arguments to CURRENCYROUND must be number and string (language) but were ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    // DATE takes three numeric args: year, month, day
    public with sharing class DATE_function implements function {
        public Integer numArgs() {
            return 3;
        }
        public Object function(List<Object> args, Integer fPosition) {
            // Expect the args to DATE to be integers, but Double is what the lexer returns.
            if (
                args[0] instanceof Double &&
                args[1] instanceof Double &&
                args[2] instanceof Double
            ) {
                return Date.newInstance(
                    ((double) args[0]).intValue(),
                    ((double) args[1]).intValue(),
                    ((double) args[2]).intValue()
                );
            } else {
                throw new ExpressionException(
                    'Type mismatch: arguments to DATE must be numbers but were ' +
                    JSON.serialize(args),
                    fPosition
                );
            }
        }
    }

    public with sharing class DATEADDDAYS_function implements function {
        public Integer numArgs() {
            return 2;
        }
        public Object function(List<Object> args, Integer fPosition) {
            if (args[0] == null || args[1] == null) {
                return null;
            } else if (args[0] instanceof Date && args[1] instanceof Double) {
                return ((Date) args[0]).addDays(((double) args[1]).intValue());
            } else {
                throw new ExpressionException(
                    'Type mismatch: arguments to DATEADDDAYS must be date and number, but were ' +
                    JSON.serialize(args),
                    fPosition
                );
            }
        }
    }

    public with sharing class DATEVALUE_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> args, Integer fPosition) {
            // Expect the arg to DATEVALUE to be date, datetime, or string.
            if (args[0] == null) {
                return null;
            } else if (args[0] instanceof Date) {
                return DateTime.newInstance(
                        (Date) args[0],
                        time.newInstance(0, 0, 0, 0)
                    )
                    .format('MMMM d, yyyy');
            } else if (args[0] instanceof DateTime) {
                return ((DateTime) args[0]).format('MMMM d, yyyy');
            } else if (args[0] instanceof String) {
                return DateTime.valueOf((String) args[0])
                    .format('MMMM d, yyyy');
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to DATEVALUE must be date, datetime, or string but was ' +
                    JSON.serialize(args),
                    fPosition
                );
            }
        }
    }

    public with sharing class DAY_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> args, Integer fPosition) {
            if (args[0] == null) {
                return null;
            } else if (args[0] instanceof Date) {
                return ((Date) args[0]).day();
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to DAY must be date, but was ' +
                    JSON.serialize(args),
                    fPosition
                );
            }
        }
    }

    // Follow rules of the Formula function FIND, including that string starts at position 1 rather than 0.
    public with sharing class FIND_function implements function {
        public Integer numArgs() {
            return -1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            Integer numArgs = arguments.size();
            if (numArgs < 2 || numArgs > 3) {
                throw new ExpressionException(
                    'Wrong number of arguments: FIND must have either two or three arguments: ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            } else if (
                arguments[0] instanceof String &&
                arguments[1] instanceof String &&
                (numArgs == 2 || arguments[2] instanceof Decimal)
            ) {
                String text = (String) arguments[0];
                String textToFind = (String) arguments[1];
                Integer position = numArgs == 3
                    ? ((Decimal) arguments[2]).intValue()
                    : 1;
                // Adjusting to the zero-position first char of the Apex indexOf method
                return text.indexOf(textToFind, position - 1) + 1;
            } else {
                throw new ExpressionException(
                    'Type mismatch: FIND must have two string arguments and an optional numeric argument: ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class FLOOR_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null) {
                return null;
            } else if (arguments[0] instanceof Decimal) {
                return ((Decimal) arguments[0]).intValue();
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to FLOOR must be numeric but was ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class FY_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null) {
                return null;
            } else if (arguments[0] instanceof Date) {
                Date d = (Date) arguments[0];
                return (d.month() > 6)
                    ? 'FY' + d.year() + '-' + (d.year() + 1)
                    : 'FY' + (d.year() - 1) + '-' + d.year();
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to FY must be date but was ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class IF_function implements function {
        public Integer numArgs() {
            return 3;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] instanceof Boolean) {
                if ((Boolean) arguments[0]) {
                    return arguments[1];
                } else {
                    return arguments[2];
                }
            } else {
                throw new ExpressionException(
                    'Type mismatch: first argument to IF must be a boolean but was ' +
                    arguments[0],
                    fPosition
                );
            }
        }
    }

    public with sharing class ISBLANK_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            return (arguments[0] == null ||
            (arguments[0] instanceof String &&
            String.isBlank((String) arguments[0])));
        }
    }

    public with sharing class LEFT_function implements function {
        public Integer numArgs() {
            return 2;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null || arguments[1] == null) {
                return '';
            } else if (
                arguments[0] instanceof String &&
                arguments[1] instanceof Decimal
            ) {
                return ((String) arguments[0])
                    .left(((Decimal) arguments[1]).intValue());
            } else {
                throw new ExpressionException(
                    'Type mismatch: arguments to LEFT must be string and numeric but were ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class LEN_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] instanceof String) {
                return ((String) arguments[0]).length();
            } else if (arguments[0] instanceof List<Object>) {
                return ((List<Object>) arguments[0]).size();
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to LEN must be string or list but was ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class LOWER_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null) {
                return '';
            } else if (arguments[0] instanceof String) {
                return ((String) arguments[0]).toLowerCase();
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to LOWER must be string but was ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class MONTH_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> args, Integer fPosition) {
            if (args[0] == null) {
                return null;
            } else if (args[0] instanceof Date) {
                return ((Date) args[0]).month();
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to MONTH must be date, but was ' +
                    JSON.serialize(args),
                    fPosition
                );
            }
        }
    }

    public with sharing class NOT_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] instanceof Boolean) {
                return !((Boolean) arguments[0]);
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to NOT must be boolean but was ' +
                    arguments[0],
                    fPosition
                );
            }
        }
    }

    public with sharing class PIECE_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null) {
                return '';
            } else if (arguments[0] instanceof String) {
                return ('{{' + (String) arguments[0] + '}}');
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to PIECE must be a string but was ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    // Build return-separated list of names and contact info of the referral orgs linked to the given prop ID.
    public with sharing class REFERRALS_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null) {
                return null;
            } else if (arguments[0] instanceof Id) {
                List<Referral_Org__c> rOrgs = new List<Referral_Org__c>(
                    [
                        SELECT Name, Contact_info__c
                        FROM Referral_Org__c
                        WHERE
                            Id IN (
                                SELECT Referral_Org__c
                                FROM Referral__c
                                WHERE Proposal__c = :(Id) arguments[0]
                            )
                        ORDER BY Name
                    ]
                );
                String result = '';
                for (Referral_Org__c rOrg : rOrgs) {
                    result =
                        result +
                        '<b>' +
                        rOrg.Name +
                        '</b><br>' +
                        rOrg.Contact_info__c +
                        '<br><br>';
                }
                return result;
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to REFERRALS must be a SalesForce Id but was ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class RIGHT_function implements function {
        public Integer numArgs() {
            return 2;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null || arguments[1] == null) {
                return '';
            } else if (
                arguments[0] instanceof String &&
                arguments[1] instanceof Decimal
            ) {
                return ((String) arguments[0])
                    .right(((Decimal) arguments[1]).intValue());
            } else {
                throw new ExpressionException(
                    'Type mismatch: arguments to RIGHT must be string and numeric but were ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class ROUND_function implements function {
        public Integer numArgs() {
            return 2;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null || arguments[1] == null) {
                return null;
            } else if (
                arguments[0] instanceof Decimal &&
                arguments[1] instanceof Decimal
            ) {
                return ((Decimal) arguments[0])
                    .setScale(((Decimal) arguments[1]).intValue());
            } else {
                throw new ExpressionException(
                    'Type mismatch: arguments to ROUND must be numeric but were ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class SUBSTITUTE_function implements function {
        public Integer numArgs() {
            return 3;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (
                arguments[0] instanceof String &&
                arguments[1] instanceof String &&
                arguments[2] instanceof String
            ) {
                return ((String) arguments[0])
                    .replace((String) arguments[1], (String) arguments[2]);
            } else {
                throw new ExpressionException(
                    'Type mismatch: arguments to SUBSTITUTE must be strings but were ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class TEXT_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            return (arguments[0] == null) ? '' : String.valueOf(arguments[0]);
        }
    }

    public with sharing class TODAY_function implements function {
        public Integer numArgs() {
            return 0;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            return Date.today();
        }
    }

    // First argument is language, second is date to translate.
    public with sharing class TRANSLATEDATE_function implements function {
        public Integer numArgs() {
            return 2;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (
                arguments[0] instanceof String && arguments[1] instanceof Date
            ) {
                return Utilities.translateDate(
                    (String) arguments[0],
                    (Date) arguments[1]
                );
            } else {
                throw new ExpressionException(
                    'Type mismatch: arguments to TRANSLATEDATE must be string (language) and date but were ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class TRANSLATEDATEMONTHYEAR_function implements function {
        public Integer numArgs() {
            return 2;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (
                arguments[0] instanceof String && arguments[1] instanceof Date
            ) {
                String language = (String) arguments[0];
                if (!Utilities.monthTranslations.containsKey(language))
                    language = 'English';
                Date d = (Date) arguments[1];
                String mTrans = Utilities.monthTranslations.get(language)[
                    d.month() - 1
                ];
                return mTrans + ' ' + d.year();
            } else {
                throw new ExpressionException(
                    'Type mismatch: arguments to TRANSLATEDATEMONTHYEAR must be string (language) and date but were ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    // NOTE: This function removes newlines as well as spaces and tabs at front and end of the text string (unlike the TRIM formula function).
    public with sharing class TRIM_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> arguments, Integer fPosition) {
            if (arguments[0] == null) {
                return '';
            } else if (arguments[0] instanceof String) {
                return ((String) arguments[0]).trim();
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to TRIM must be string but was ' +
                    JSON.serialize(arguments),
                    fPosition
                );
            }
        }
    }

    public with sharing class VALUE_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> args, Integer fPosition) {
            if (args[0] == null) {
                return null;
            } else if (args[0] instanceof String) {
                return Decimal.valueOf((String) args[0]);
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to VALUE must be a string, but was ' +
                    JSON.serialize(args),
                    fPosition
                );
            }
        }
    }

    public with sharing class YEAR_function implements function {
        public Integer numArgs() {
            return 1;
        }
        public Object function(List<Object> args, Integer fPosition) {
            if (args[0] == null) {
                return null;
            } else if (args[0] instanceof Date) {
                return ((Date) args[0]).year();
            } else {
                throw new ExpressionException(
                    'Type mismatch: argument to YEAR must be date, but was ' +
                    JSON.serialize(args),
                    fPosition
                );
            }
        }
    }
}