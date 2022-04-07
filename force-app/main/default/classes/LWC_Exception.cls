/**===========================================================================================================
* @author Melissa Hansen
* @date Jan 2021
*
* @category LWC
*
* @description Custom Exception Class to format exception messages and display in a readable format for end users
* 
* @usage
*    If in Aura Context: 
*       throw new LWC_Exception(required parameters for chosen constructor);
===========================================================================================================*/

public with sharing class LWC_Exception extends Exception {
    
    public LWC_Exception ( String methodIdentifier, String message, Exception e, Integer exceptionCode ) {
        System.debug('Original Exception: '+e);
        System.debug('Stack Trace: '+e.getStackTraceString());
        System.debug('message: '+message);
        LWC_ExceptionData data = new LWC_ExceptionData ();
        data.title = 'An Error Has Occurred';
        data.variant = 'error';
        data.codeLocation = e.getStackTraceString();
        data.exceptionMessage = e.getMessage ();
        data.exceptionCode = exceptionCode;
        data.userMessage = message;
        data.mode = 'sticky';
        throwAuraHandledException ( data );
    }

    // w/o exception and with code
    public LWC_Exception ( String methodIdentifier, String message, Integer exceptionCode ) {
        System.debug('exceptionCode: '+exceptionCode);
        System.debug('message: '+message);
        System.debug ( 'LWC Exception --> ' + methodIdentifier + ' [ ' + message + ' ] ');
        LWC_ExceptionData data = new LWC_ExceptionData ();
        data.title = 'An Error Has Occurred';
        data.variant = 'error';
        data.codeLocation = methodIdentifier;
        data.userMessage = message;
        data.exceptionCode = exceptionCode;
        data.mode = 'sticky';
        throwAuraHandledException ( data );
    }

    public static void throwAuraHandledException ( LWC_ExceptionData data ) {
        AuraHandledException e = new AuraHandledException ( data.serialize () );
        throw e;
    }
}