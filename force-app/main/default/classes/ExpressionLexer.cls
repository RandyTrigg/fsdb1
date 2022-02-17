/* Fetch tokens from an input string.  Tokens can be symbols (including operators), function names,
 * field names, and numeric and string constants. Skip comments and white space.
 * Look up field names and replace with their values.
 */
public class ExpressionLexer {
    public enum TokenType {
        NUMBER_TOKEN,
        STRING_TOKEN,
        BOOLEAN_TOKEN,
        DATE_TOKEN,
        SYMBOL,
        FUNCTION,
        MACRO,
        PIECE,
        FIELD,
        FIELDNAME
    }
    private static Map<Schema.DisplayType, TokenType> displayTypeToTokenType = new Map<Schema.DisplayType, TokenType>{
        Schema.DisplayType.Integer => TokenType.NUMBER_TOKEN,
        Schema.DisplayType.Double => TokenType.NUMBER_TOKEN,
        Schema.DisplayType.Boolean => TokenType.BOOLEAN_TOKEN,
        Schema.DisplayType.Date => TokenType.DATE_TOKEN
    };
    private static Map<String, Integer> symPrec = new Map<String, Integer>{
        '!' => 11,
        '**' => 10,
        '*' => 9,
        '/' => 9,
        '+' => 8,
        '-' => 8,
        '&' => 7,
        '>=' => 6,
        '<=' => 6,
        '>' => 6,
        '<' => 6,
        '!=' => 5,
        '==' => 5,
        '&&' => 4,
        '||' => 3,
        '?' => 1,
        ':' => 1
    };
    private static String fieldNameChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._';

    public class Stack {
        Object[] items = new List<Object>();
        public Integer size() {
            return items.size();
        }
        public void push(Object item) {
            items.add(item);
        }
        public Object pop() {
            return size() > 0 ? items.remove(size() - 1) : null;
        }
        public Object peek() {
            return size() > 0 ? items[size() - 1] : null;
        }
    }

    // A token is represented by a value, a type, an index into the input string, and the number of args (in the case of an operator).
    public class Token {
        public Object value;
        public TokenType type;
        public Integer index;
        public Integer numArgs;
        public Token(
            Object value,
            TokenType type,
            Integer index,
            Integer numArgs
        ) {
            this.value = value;
            this.type = type;
            this.index = index;
            this.numArgs = numArgs;
        }
        public Boolean isOperator() {
            return this.type == TokenType.SYMBOL ||
                this.type == TokenType.FUNCTION;
        }
        public Integer precedence() {
            if (this.isOperator()) {
                // Use precedence table except for unitary + or -.
                return (this.value == '+' || this.value == '-') &&
                    this.numArgs == 1
                    ? 20
                    : symPrec.get((String) this.value);
            } else
                return null;
        }
    }

    // Tokens converted from infix to prefix
    private List<Token> prefixQueue = new List<Token>();
    public Integer tIndex = 0;
    public Token fetchPrefixToken() {
        Token result;
        if (prefixQueue != null && prefixQueue.size() > tIndex) {
            result = prefixQueue[tIndex];
            tIndex = tIndex + 1;
        }
        return result;
    }

    // Use two stacks to convert infix to prefix.
    // The items in prefixStack are lists of tokens.  If prefixStack isn't a single list at the end, then there are syntax errors.
    private Stack prefixStack = new Stack();
    private void pushOperand(Token operand) {
        prefixStack.push(new List<Token>{ operand });
    }
    // Combine given operator with appropriate number of args from top of stack, and replace on stack with prefix.
    private void buildPrefix(Token operator) {
        Token[] operands = new List<Token>();
        for (Integer i = 0; i < operator.numArgs; i++) {
            // Push each popped prefix list onto the front of the operands queue.
            Token[] topPrefix = (List<Token>) prefixStack.pop();
            topPrefix.addAll(operands);
            operands = topPrefix;
        }
        if (operands.size() == 0)
            operands.add(operator);
        else
            operands.add(0, operator);
        prefixStack.push(operands); // Prefix has operator followed by the queue of operands.
    }
    // The items in operatorStack are tokens (symbols or function names).
    private Stack operatorStack = new Stack();
    private Token previousInfixToken;
    // Add new token to stack - behavior depends on whether operand or operator.
    private void addNewToken(
        Object value,
        TokenType type,
        Integer index,
        Integer numArgs
    ) {
        Token token = new Token(value, type, index, numArgs);
        system.debug('addNewToken: token = ' + JSON.serialize(token));
        if (token.isOperator()) {
            Token topToken = (Token) operatorStack.peek();
            if (token.type == TokenType.FUNCTION) {
                // Create a parenthetical surrounding the function on the operator stack.
                operatorStack.push(new Token('(', TokenType.SYMBOL, index, 0));
                operatorStack.push(token);
            } else if (token.value == ',') {
                // Process operators back to most recent function, and then increment num args in the function token.
                while (
                    topToken != null &&
                    topToken.type != TokenType.FUNCTION
                ) {
                    buildPrefix((Token) operatorStack.pop());
                    topToken = (Token) operatorStack.peek();
                }
                if (topToken == null)
                    throw new ExpressionException(
                        'Unexpected "," - missing function or unbalanced parentheses',
                        index
                    );
                else
                    topToken.numArgs += 1; // The comma indicates the function has one more arg.
            } else if (token.value == ')') {
                // Process operators back to the most recent left parenthesis.
                while (topToken != null && topToken.value != '(') {
                    // Count one more arg for the function unless the last token was in fact the function, in which case the function has zero args.
                    if (
                        topToken.type == TokenType.FUNCTION &&
                        previousInfixToken != topToken
                    )
                        topToken.numArgs += 1;
                    buildPrefix((Token) operatorStack.pop());
                    topToken = (Token) operatorStack.peek();
                }
                if (topToken == null)
                    throw new ExpressionException(
                        'Unbalanced parantheses',
                        index
                    );
                else
                    operatorStack.pop(); // Throw away the left parenthesis
            } else if (token.value == ':') {
                // Ternary: process operators back to the most recent "?".
                // Then leave the "?" on top of the stack, and toss the ":".
                while (topToken != null && topToken.value != '?') {
                    buildPrefix((Token) operatorStack.pop());
                    topToken = (Token) operatorStack.peek();
                }
                if (topToken == null)
                    throw new ExpressionException(
                        'Unbalanced ternary - ":" without matching "?"',
                        index
                    );
            } else {
                // Should be a simple operator.  Process operators on the stack that are of at least as high precedence.
                while (
                    topToken != null &&
                    topToken.precedence() > token.precedence()
                ) {
                    buildPrefix((Token) operatorStack.pop());
                    topToken = (Token) operatorStack.peek();
                }
                operatorStack.push(token);
            }
        } else
            pushOperand(token);
        previousInfixToken = token;
        //system.debug('addNewToken bottom: operatorStack = ' +JSON.serialize(operatorStack));
        //system.debug('addNewToken bottom: prefixStack = ' + JSON.serialize(prefixStack));
    }

    // Process any remaining operators on the operator stack (invoked at the end of the infix string).
    private void processOperators() {
        while (operatorStack.peek() != null)
            buildPrefix((Token) operatorStack.pop());
    }

    private String input;
    private List<String> symbols;
    private Integer currIndex;

    public ExpressionLexer(String input, List<String> symbols) {
        this.input = input;
        this.symbols = symbols;
    }

    // Gather field names (unevaluated) from input string - called in place of initialize().
    public Set<String> fieldNames() {
        Set<String> result = new Set<String>();
        initialize(null); // Tokenize input without evaluating field names.
        for (Token t : prefixQueue) {
            if (t.type == TokenType.FIELDNAME)
                result.add((String) t.value);
        }
        return result;
    }

    // Process input string into a prefix queue of tokens, or accept a serialized version of the cached prefix.
    // Returns the serialized version of the prefix queue.
    public String initialize(String prefixSerialized) {
        if (prefixSerialized != null) {
            Map<String, TokenType> tokenTypesByName = new Map<String, TokenType>();
            for (TokenType tt : TokenType.values())
                tokenTypesByName.put(tt.name(), tt);
            List<Object> deserialized = (List<Object>) JSON.deserializeUntyped(
                prefixSerialized
            );
            prefixQueue = new List<Token>();
            for (Object o : deserialized) {
                Map<String, Object> tFlds = (Map<String, Object>) o;
                Token t = new Token(
                    (Object) tFlds.get('value'),
                    tokenTypesByName.get((String) tFlds.get('type')),
                    (Integer) tFlds.get('index'),
                    (Integer) tFlds.get('numArgs')
                );
                prefixQueue.add(t);
            }
        } else {
            currIndex = 0; // Initialize index into input string.
            // Fill prefix queue with tokens.
            while (fetchToken());
            processOperators(); // Process remaining operators to complete the prefix.
            // After processing, the stack should contain a single combined list of tokens comprising the prefix.
            if (prefixStack.size() > 1) {
                system.debug(
                    'In ExpressionLexer.initialize, prefixStack = ' +
                    JSON.serialize(prefixStack)
                );
                throw new ExpressionException(
                    'Syntax error - possibly unbalanced parentheses',
                    currIndex
                );
            }
            prefixQueue = (List<Token>) prefixStack.peek();
            prefixSerialized = JSON.serialize(prefixQueue);
        }
        tIndex = 0; // Initialize prefix queue index.
        system.debug(
            'In ExpressionLexer.initialize, prefix = ' + prefixSerialized
        );
        return prefixSerialized;
    }

    // Read the next token in the input string. Return true if successful.
    // Note that we're gathering field names, and letting the interpreter (that is, the caller) do the evaluation.
    public Boolean fetchToken() {
        //system.debug('Top of fetchToken. currIndex = ' + currIndex);
        //system.debug('Top of fetchToken. Rest of input = ' + restInput() );
        if (currIndex >= input.length())
            return false; // Bail if no more input to read.
        skipWhiteAndComments();
        if (currIndex >= input.length())
            return false; // Bail if no more input to read.
        if (stringToken())
            return true;
        if (booleanToken())
            return true;
        if (symbolToken(symbols))
            return true;
        if (functionToken())
            return true;
        if (numberToken())
            return true;
        if (macroToken())
            return true;
        if (pieceToken())
            return true;
        if (fieldNameToken())
            return true;
        // Remaining input is not a recognizable token.
        throw new ExpressionException(
            'Unrecognizable token in expression text: ' +
            input.substring(currIndex).left(20),
            currIndex
        );
    }

    // Skip past indeterminate number of comments and interspersed white space.
    private void skipWhiteAndComments() {
        skipWhite();
        while (skipComment())
            skipWhite();
    }

    // Skip over white space.
    private void skipWhite() {
        String restInput = input.substring(currIndex);
        String trimmed = restInput.trim().replaceAll('\\u00A0', ''); // Remove non-breaking spaces, in addition to trim's white space chars
        currIndex = (trimmed.length() > 0)
            ? currIndex + restInput.indexOf(trimmed)
            : input.length();
    }

    // Skip a comment, either // or /*...*/. Return true if one was skipped.
    private Boolean skipComment() {
        String restInput = input.substring(currIndex);
        if (restInput.startsWith('//')) {
            Integer newLinePos = currIndex + restInput.indexOf('\n');
            currIndex = (newLinePos > currIndex)
                ? newLinePos + 1
                : input.Length();
            return true;
        }
        restInput = input.substring(currIndex);
        if (restInput.startsWith('/*')) {
            Integer endCommentPos = currIndex + restInput.indexOf('*/');
            currIndex = (endCommentPos >= currIndex)
                ? endCommentPos + 2
                : input.Length();
            return true;
        }
        return false;
    }

    // Try to read a boolean token, either true or false - return true if successful.
    private Boolean booleanToken() {
        String restInput = input.substring(currIndex);
        if (restInput.startsWithIgnoreCase('true')) {
            addNewToken(true, TokenType.BOOLEAN_TOKEN, currIndex, null);
            currIndex += 4;
            return true;
        }
        restInput = input.substring(currIndex);
        if (restInput.startsWithIgnoreCase('false')) {
            addNewToken(false, TokenType.BOOLEAN_TOKEN, currIndex, null);
            currIndex += 5;
            return true;
        }
        return false;
    }

    // Try to read a symbol - return true if successful.
    private Boolean symbolToken(List<String> strings) {
        for (String s : strings) {
            if (input.substring(currIndex).startsWithIgnoreCase(s)) {
                // Most operator symbols take two args.
                Integer numArgs = s == '!'
                    ? 1 // Unary "NOT" operator // Distinguish unary versus binary versions of - and +.
                    : (s == '-' || s == '+') &&
                            (previousInfixToken == null ||
                            (previousInfixToken.isOperator() &&
                            previousInfixToken.value != ')'))
                            ? 1
                            : s == '?'
                                    ? 3 // ternary operator
                                    : s == ':' ? 0 : 2;
                addNewToken(s, TokenType.SYMBOL, currIndex, numArgs);
                currIndex += s.length();
                return true;
            }
        }
        return false;
    }

    // Try to read a function name followed by optional white space and required left parenthesis - return true if successful.
    // Note that the left parenthesis is eaten and is not part of the token.
    private Boolean functionToken() {
        String restInput = input.substring(currIndex);
        if (restInput.left(1).isAlpha()) {
            Integer nonAlphaNumPos =
                currIndex + restInput.indexOfAnyBut(fieldNameChars);
            String fName = (nonAlphaNumPos > currIndex)
                ? input.subString(currIndex, nonAlphaNumPos)
                : restInput;
            Integer leftParenPos = currIndex + restInput.indexOf('(');
            if (
                leftParenPos > currIndex &&
                input.subString(nonAlphaNumPos, leftParenPos).isWhiteSpace()
            ) {
                addNewToken(fName, TokenType.FUNCTION, currIndex, 0);
                currIndex = leftParenPos + 1;
                return true;
            }
            return false;
        }
        return false;
    }

    // Try to read a double quote-delimited string - return true if successful,
    // including if starting, but no ending double-quote.
    // NOTE: Needs to handle embedded escaped double-quotes.
    private Boolean stringToken() {
        if (input.substring(currIndex).startsWith('"')) {
            currIndex += 1;
            Integer doubleQuotePos =
                currIndex + input.substring(currIndex).indexOf('"');
            if (doubleQuotePos >= currIndex) {
                addNewToken(
                    input.subString(currIndex, doubleQuotePos),
                    TokenType.STRING_TOKEN,
                    currIndex - 1,
                    null
                );
                currIndex = doubleQuotePos + 1;
            } // No closing double-quote - bail without building a token.
            return true;
        }
        return false;
    }

    // Try to read a number - return true if successful.
    private Boolean numberToken() {
        String restInput = input.substring(currIndex);
        Decimal d;
        Integer i;
        if (restInput.startsWith('.') || restInput.left(1).isNumeric()) {
            Integer nonNumericPos =
                currIndex + restInput.indexOfAnyBut('0123456789.');
            String numString = (nonNumericPos > currIndex)
                ? input.subString(currIndex, nonNumericPos)
                : restInput;
            try {
                // Don't build token unless coerceable to a double.
                d = Double.valueof(numString);
                addNewToken(d, TokenType.NUMBER_TOKEN, currIndex, null);
            } catch (Exception e) {
                // Badly formed number - bail without building a token.
            }
            currIndex = (nonNumericPos > currIndex)
                ? nonNumericPos
                : input.Length();
            return true;
        }
        return false;
    }

    // Try to read a field name - return true if successful.
    private Boolean fieldNameToken() {
        String restInput = input.subString(currIndex);
        if (restInput.left(1).isAlpha()) {
            Integer nonAlphaNumPos =
                currIndex + restInput.indexOfAnyBut(fieldNameChars);
            String fName = (nonAlphaNumPos > currIndex)
                ? input.subString(currIndex, nonAlphaNumPos)
                : restInput;
            addNewToken(fName, TokenType.FIELDNAME, currIndex, null);
            currIndex = (nonAlphaNumPos > currIndex)
                ? nonAlphaNumPos
                : input.length();
            return true;
        }
        return false;
    }

    // Look up type of given record of given object.
    // NOTE: This is not currently used by ExpressionLexer.  Perhaps could be moved to Utilities
    // in which case, it should probably just return the display type (or its name) rather than
    // an instance of TokenType.
    public TokenType getType(String oName, String fName) {
        //system.debug('In getType, oName = ' + oName + '; fName = ' + fName);
        Map<String, Schema.SObjectField> fieldsMap = Utilities.fieldMaps.get(
            oName
        );
        Schema.DisplayType fieldType = fieldsMap.get(fName)
            .getDescribe()
            .getType();
        // Map types in Schema.DisplayType to our token types - default to String.
        if (displayTypeToTokenType.containsKey(fieldType)) {
            return displayTypeToTokenType.get(fieldType);
        } else {
            return TokenType.STRING_TOKEN;
        }
    }

    // Try to read a macro call (string enclosed in double square brackets) - return true if successful.
    private Boolean macroToken() {
        if (input.substring(currIndex).startsWith('[[')) {
            currIndex += 2;
            Integer doubleSqBracketPos =
                currIndex + input.substring(currIndex).indexOf(']]');
            if (doubleSqBracketPos >= currIndex) {
                addNewToken(
                    input.subString(currIndex, doubleSqBracketPos),
                    TokenType.MACRO,
                    currIndex - 2,
                    null
                );
                currIndex = doubleSqBracketPos + 2;
            } // No closing square brackets - bail without building a token.
            return true;
        }
        return false;
    }

    // Try to read a template piece call (string enclosed in double curly brackets) - return true if successful.
    // NOTE: These should only be present in FieldNames calls to the lexer.  For normal evaluation, embedded
    // piece calls should have been expanded.
    private Boolean pieceToken() {
        if (input.substring(currIndex).startsWith('{{')) {
            currIndex += 2;
            Integer doubleCurlyBracketPos =
                currIndex + input.substring(currIndex).indexOf('}}');
            if (doubleCurlyBracketPos >= currIndex) {
                addNewToken(
                    input.subString(currIndex, doubleCurlyBracketPos),
                    TokenType.PIECE,
                    currIndex - 2,
                    null
                );
                currIndex = doubleCurlyBracketPos + 2;
            } // No closing curly brackets - bail without building a token.
            return true;
        }
        return false;
    }
}