public with sharing class ExpressionException extends Exception {
    public Integer pos;
    // Exception class constructor     
    public ExpressionException(string message, Integer pos) {
        // Pass 'message' to the base class
        this.setMessage(message + ' (at char ' + pos + ')');
        this.pos = pos;
    }
}