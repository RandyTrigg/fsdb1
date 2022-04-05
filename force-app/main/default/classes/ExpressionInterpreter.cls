/**
 * Builds instance of ExpressionLexer, computes prefix, and evaluates expression in given context.
 */
public with sharing class ExpressionInterpreter {
    public static List<String> symbols = new List<String>{
        ',',
        '(',
        ')',
        '+',
        '-',
        '!=',
        '==',
        '!',
        '**',
        '*',
        '/',
        '>=',
        '<=',
        '>',
        '<',
        '&&',
        '||',
        '&',
        '?',
        ':'
    };

    private ExpressionLexer lexer;
    private ExpressionFunctions functions;
    public sObject context;
    private Map<String, Template_macro__c> mNameMap;
    private Map<String, Object> mValues = new Map<String, Object>();

    public ExpressionInterpreter(sObject context) {
        this.context = context;
        this.functions = new ExpressionFunctions();
        this.mNameMap = new Map<String, Template_macro__c>();
    }

    public ExpressionInterpreter(
        sObject context,
        Map<String, Template_macro__c> mNameMap
    ) {
        this.context = context;
        this.functions = new ExpressionFunctions();
        this.mNameMap = mNameMap;
    }

    // Evaluate the expression.
    public Object interpret(String expression) {
        InnerInterpreter innerInt = new InnerInterpreter(
            this,
            expression,
            null
        );
        return innerInt.evaluate(false);
    }

    // Evaluate a macro by name.
    public Object evaluateMacro(String mName) {
        // Use cache to check if we're (recursively) in the middle of this macro's evaluation, or if we've already evaluated it.
        Object val = mValues.containsKey(mName) ? mValues.get(mName) : null;
        if (val instanceof String && (String) val == '@@EXPANDING@@') {
            return '**UNABLE TO EXPAND MACRO ' + mName + ': RECURSIVE CALL';
        }
        system.debug(
            'evaluateMacro ' +
            mName +
            (mValues.containsKey(mName)
                ? ': retrieving from cache'
                : ': expanding')
        );
        if (mValues.containsKey(mName))
            return val;
        // Look up the macro text.
        Template_macro__c m = mNameMap.get(mName);
        if (m == null)
            return '**UNABLE TO EXPAND ' + mName + ': UNKNOWN MACRO';
        // Expand macro text after flagging that it's in the process of being evaluated.
        mValues.put(mName, '@@EXPANDING@@');
        InnerInterpreter innerInt = new InnerInterpreter(
            this,
            m.Macro_text__c,
            m.Macro_text_prefix__c
        );
        Object result = innerInt.evaluate(false);
        mValues.put(mName, result);
        return result;
    }

    // Inner class holds lexer and the evaluate functionality.
    public with sharing class InnerInterpreter {
        ExpressionInterpreter parent;
        ExpressionLexer lexer;
        private sObject context;
        private ExpressionFunctions functions;

        public InnerInterpreter(
            ExpressionInterpreter parent,
            String expression,
            String prefixSerialized
        ) {
            this.parent = parent;
            this.context = parent.context;
            this.functions = parent.functions;
            this.lexer = new ExpressionLexer(expression, symbols);
            this.lexer.initialize(prefixSerialized);
            this.lexer.tIndex = 0;
        }

        // Recursively build lexer (for an embedded macro call) by invoking parent's "evaluateMacro" method.
        public Object evaluateMacro(String mName) {
            return parent.evaluateMacro(mName);
        }

        // Evaluate expression recursively in given context using prefix queue generated from infix.
        // If skipFlg, then consume from prefixQueue without evaluating.
        private Object evaluate(Boolean skipFlg) {
            ExpressionLexer.Token token = lexer.fetchPrefixToken();
            if (token == null)
                return null;
            system.debug(
                'ExpressionInterpreter: in evaluate' +
                (skipFlg ? ' SKIPPING' : '') +
                ', token = ' +
                JSON.serialize(token)
            );
            // Bail if we're skipping and there are no args to gather.
            if (skipFlg && token.numArgs == 0)
                return null;
            Object result;
            switch on token.type {
                when MACRO {
                    result = macro(token, skipFlg);
                }
                when FIELDNAME {
                    result = fieldname(token, skipFlg);
                }
                when FUNCTION {
                    result = function(token, skipFlg);
                }
                when SYMBOL {
                    result = symbol(token, skipFlg);
                }
                when NUMBER_TOKEN {
                    result = (Double) token.value;
                }
                when STRING_TOKEN {
                    result = (String) token.value;
                }
                when BOOLEAN_TOKEN {
                    result = (Boolean) token.value;
                }
                when DATE_TOKEN {
                    result = (Date) token.value;
                }
                when else {
                    system.debug(
                        'evaluate: unexpected token type: ' + token.type
                    );
                    throw new ExpressionException(
                        'Unexpected token type: ' + token.type,
                        token.index
                    );
                }
            }
            return result;
        }

        private Object macro(ExpressionLexer.Token token, Boolean skipFlg) {
            if (skipFlg)
                return null;
            String mName = (String) token.value;
            return evaluateMacro(mName);
        }

        private Object fieldname(ExpressionLexer.Token token, Boolean skipFlg) {
            if (skipFlg)
                return null;
            String fName = (String) token.value;
            Object result;
            try {
                system.debug('In fieldname, fName = ' + fName);
                result = Utilities.getValue(context, fName);
            } catch (Exception e) {
                // Unable to get field value - bail without building a token
                system.debug(
                    'In fieldname cannot get field value, fName = ' +
                    fName +
                    '; context = ' +
                    JSON.serialize(context)
                );
                throw new ExpressionException(
                    'Could not get field value for field with name = ' + fName,
                    token.index
                );
            }
            return result;
        }

        private Object function(ExpressionLexer.Token token, Boolean skipFlg) {
            Object result;
            String fName = (String) token.value;
            switch on fName {
                // Hand off processing if this is a function that conditionally evaluates its args.
                when 'OR' {
                    result = logical(token, skipFlg);
                }
                when 'AND' {
                    result = logical(token, skipFlg);
                }
                when 'IF' {
                    result = ternary(token, skipFlg);
                }
                when 'CASE' {
                    result = case(token, skipFlg);
                }
                when 'CASEFM' {
                    result = casefm(token, skipFlg);
                }
                when else {
                    // Otherwise, look up function and process.
                    // Gather the appropriate number of arguments.
                    List<Object> arguments = new List<Object>();
                    for (Integer i = 0; i < token.numArgs; i++)
                        arguments.add(evaluate(skipFlg));
                    result = skipFlg
                        ? null
                        : functions.evaluate(fName, arguments, token.index);
                }
            }
            return result;
        }

        private Object symbol(ExpressionLexer.Token token, Boolean skipFlg) {
            Object result;
            String s = (String) token.value;
            if (s == '!' || s == '&&' || s == '||')
                result = logical(token, skipFlg);
            else if (s == '&')
                result = concatenate(token, skipFlg);
            else if (('== !=').contains(s))
                result = equality(token, skipFlg);
            else if (('>= <= > <').contains(s))
                result = inequality(token, skipFlg);
            else if (('+ -').contains(s) && token.numArgs == 1)
                result = unary(token, skipFlg);
            else if (('** * / + -').contains(s))
                result = arithmetic(token, skipFlg);
            else if (s == '?')
                result = ternary(token, skipFlg);
            return result;
        }

        // Handle unary + and -.
        private Double unary(ExpressionLexer.Token token, Boolean skipFlg) {
            Object operand = evaluate(skipFlg);
            String operator = (String) token.value;
            if (skipFlg)
                return null;
            Double result;
            if (operand instanceof Double) {
                result = operator == '-'
                    ? -(Double) operand
                    : operator == '+' ? +(Double) operand : null;
            } else {
                throw new ExpressionException(
                    'Type mismatch: cannot apply + or - to ' + operand,
                    token.index
                );
            }
            return result;
        }

        // Handle arithmetic operations **, *, /, +, -.  Supports subtracting dates.
        private Double arithmetic(
            ExpressionLexer.Token token,
            Boolean skipFlg
        ) {
            Object operand1 = evaluate(skipFlg);
            Object operand2 = evaluate(skipFlg);
            String operator = (String) token.value;
            if (skipFlg)
                return null;
            Double result;
            if (operand1 instanceof Double && operand2 instanceof Double) {
                Double d1 = (Double) operand1;
                Double d2 = (Double) operand2;
                if (d2 == 0.0) {
                    throw new ExpressionException(
                        'Divide by zero',
                        token.index
                    );
                }
                result = operator == '**'
                    ? Math.pow(d1, d2)
                    : operator == '*'
                            ? d1 * d2
                            : operator == '/'
                                    ? d1 / d2
                                    : operator == '+'
                                            ? d1 + d2
                                            : operator == '-' ? d1 - d2 : null;
            } else if (
                operand1 instanceof Date &&
                operand2 instanceof Date &&
                operator == '-'
            ) {
                // Allow subtraction of date operands.
                result = ((Date) operand2).daysBetween((Date) operand1);
            } else {
                throw new ExpressionException(
                    'Type mismatch: cannot apply **, *, /, +, - to ' +
                    operand1 +
                    ' and ' +
                    operand2,
                    token.index
                );
            }
            return result;
        }

        // Handle inequality operations >, <, >=, <=.
        private Boolean inequality(
            ExpressionLexer.Token token,
            Boolean skipFlg
        ) {
            Object operand1 = evaluate(skipFlg);
            Object operand2 = evaluate(skipFlg);
            String operator = (String) token.value;
            if (skipFlg)
                return null;
            Boolean result;
            if (operand1 == null || operand2 == null)
                return false;
            if (operand1 instanceof Double && operand2 instanceof Double) {
                Double d1 = (Double) operand1;
                Double d2 = (Double) operand2;
                result = operator == '>='
                    ? d1 >= d2
                    : operator == '<='
                            ? d1 <= d2
                            : operator == '>' ? d1 > d2 : d1 < d2;
            } else if (operand1 instanceof Date && operand2 instanceof Date) {
                Date d1 = (Date) operand1;
                Date d2 = (Date) operand2;
                result = operator == '>='
                    ? d1 >= d2
                    : operator == '<='
                            ? d1 <= d2
                            : operator == '>' ? d1 > d2 : d1 < d2;
            } else {
                throw new ExpressionException(
                    'Type mismatch: cannot apply < or > or <= or >= to ' +
                    operand1 +
                    ' and ' +
                    operand2,
                    token.index
                );
            }
            return result;
        }

        // Handle equality operations == and !=.
        private Boolean equality(ExpressionLexer.Token token, Boolean skipFlg) {
            Object operand1 = evaluate(skipFlg);
            Object operand2 = evaluate(skipFlg);
            String operator = (String) token.value;
            if (skipFlg)
                return null;
            Boolean result;
            if (
                (operand1 instanceof Boolean && operand2 instanceof Boolean) ||
                (operand1 instanceof Double && operand2 instanceof Double) ||
                (operand1 instanceof String && operand2 instanceof String) ||
                (operand1 instanceof Date && operand2 instanceof Date) ||
                operand1 == null ||
                operand2 == null
            ) {
                if (operator == '==')
                    result = operand1 == operand2;
                else
                    result = operand1 != operand2;
            } else {
                throw new ExpressionException(
                    'Type mismatch: cannot apply == or != to ' +
                    operand1 +
                    ' and ' +
                    operand2,
                    token.index
                );
            }
            return result;
        }

        // Handle NOT/AND/OR (!, &&, ||) operations, evaluating args only when necessary.
        private Boolean logical(ExpressionLexer.Token token, Boolean skipFlg) {
            Integer numArgs = token.numArgs;
            String operator = (String) token.value;
            if (operator == 'AND')
                operator = '&&';
            else if (operator == 'OR')
                operator = '||';
            Boolean result = operator == '&&' ? true : false;
            // Fetch args one at a time; start skipping when logical result is fixed.
            for (Integer i = 0; i < numArgs; i++) {
                Object operand = evaluate(skipFlg);
                if (skipFlg)
                    continue;
                if (operand instanceof Boolean) {
                    Boolean operandBool = (Boolean) operand;
                    if (operator == '!') {
                        result = !operandBool;
                    } else if (operator == '&&') {
                        result = result && operandBool;
                        if (!result)
                            skipFlg = true; // False result for AND, so skip rest of args.
                    } else {
                        result = result || operandBool;
                        if (result)
                            skipFlg = true; // True result for OR, so skip rest of args.
                    }
                    system.debug(
                        'logical in loop: operator = ' +
                        operator +
                        '; operandBool = ' +
                        operandBool +
                        '; result = ' +
                        result +
                        '; skipFlg = ' +
                        skipFlg
                    );
                } else {
                    throw new ExpressionException(
                        'Type mismatch: cannot apply logical functions/operators (AND, &&, OR, ||, !) to non-boolean value: ' +
                        operand,
                        token.index
                    );
                }
            }
            return result;
        }

        // Handle ternary operation, either ... ? ... : ... or IF(..., ..., ...)
        private Object ternary(ExpressionLexer.Token token, Boolean skipFlg) {
            Object condition = evaluate(skipFlg);
            Object result;
            if (skipFlg) {
                // skip second and third parts
                evaluate(true);
                evaluate(true);
                return result;
            }
            if (condition instanceof Boolean) {
                // Avoid evaluating the second part of the ternary if first (boolean) part is false,
                // and avoid evaluating the third part if first is true.
                if ((Boolean) condition) {
                    result = evaluate(false); // Grab second part
                    evaluate(true); // Skip third part.
                } else {
                    evaluate(true); // Skip second part.
                    result = evaluate(false); // Grab third part
                }
            } else {
                throw new ExpressionException(
                    'Type mismatch: first part of IF (or value preceding ?) must be a boolean but was ' +
                    condition,
                    token.index
                );
            }
            return result;
        }

        // CASE(expression, value1, result1, value2, result2,..., else_result)
        private Object case(ExpressionLexer.Token token, Boolean skipFlg) {
            Integer numArgs = token.numArgs;
            if (numArgs < 2) {
                throw new ExpressionException(
                    'CASE function must have at least two arguments. ' +
                    numArgs +
                    ' provided.',
                    token.index
                );
            }
            Object result;
            if (skipFlg) {
                for (Integer i = 0; i < numArgs; i++)
                    evaluate(true);
                return result;
            }
            Object expression = evaluate(skipFlg);
            // Walk through argument pairs.  Once there's a match, skip the rest of the args.
            Integer i = 1;
            while (i < numArgs - 1) {
                Object arg1 = evaluate(skipFlg);
                Object arg2 = evaluate(skipFlg);
                if (!skipFlg && expression == arg1) {
                    result = arg2;
                    skipFlg = true; // Start skipping args since we found a match.
                }
                i += 2;
            }
            if (i == numArgs - 1) {
                // There's an else clause.
                Object elseArg = evaluate(skipFlg);
                if (!skipFlg)
                    result = elseArg;
            }
            return result;
        }

        // CASEFM(boolean1, result1, boolean2, result2, ..., else_result)
        // Acts like FileMaker's Case function.
        // Performs a series of checks returning the appropriate result.
        // If none of the booleans evaluates to true then return the else_result.
        private Object casefm(ExpressionLexer.Token token, Boolean skipFlg) {
            Integer numArgs = token.numArgs;
            if (numArgs < 1) {
                throw new ExpressionException(
                    'CASEFM function must have at least one argument. ',
                    token.index
                );
            }
            Object result;
            if (skipFlg) {
                for (Integer i = 0; i < numArgs; i++)
                    evaluate(true);
                return result;
            }
            // Walk through argument pairs.  Once one of the pairs has a true boolean, skip the rest of the args.
            Integer i = 0;
            while (i < numArgs - 1) {
                Object condition = evaluate(skipFlg);
                if (!skipFlg) {
                    if (condition instanceof Boolean) {
                        if ((Boolean) condition) {
                            result = evaluate(false); // Condition is true, so result is the "value" clause
                            skipFlg = true; // Start skipping args since we found a true condition.
                        } else
                            evaluate(true); // Condition is false, so skip the "value" clause
                    } else {
                        throw new ExpressionException(
                            'Type mismatch: odd-numbered argument to CASEFM must be boolean but was ' +
                            JSON.serialize(condition),
                            token.index
                        );
                    }
                }
                i += 2;
            }
            if (i == numArgs - 1) {
                // There's an else clause.
                Object elseArg = evaluate(skipFlg);
                if (!skipFlg)
                    result = elseArg;
            }
            return result;
        }

        // Handle concatenation "&".
        private String concatenate(
            ExpressionLexer.Token token,
            Boolean skipFlg
        ) {
            Object operand1 = evaluate(skipFlg);
            Object operand2 = evaluate(skipFlg);
            if (skipFlg)
                return null;
            String result;
            if (operand1 instanceof String && operand2 instanceof String) {
                result = (String) operand1 + (String) operand2;
            } else {
                throw new ExpressionException(
                    'Type mismatch: cannot apply "&" to ' +
                    operand1 +
                    ' and ' +
                    operand2,
                    token.index
                );
            }
            return result;
        }
    }
}