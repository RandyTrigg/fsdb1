public with sharing class LWC_ExceptionData {
    public string codeLocation;
    public string title;
    public string variant;
    public string userMessage;
    public string exceptionMessage;
    public integer exceptionCode;
    public string mode;
    public boolean isFatal;
    public List < string > missingRequiredFields;
    public Map < string, string > invalidFields;

    public LWC_ExceptionData () {
        this.isFatal = false;
    }

    public static LWC_ExceptionData deserialize ( string jsonString ) {
        system.debug ( jsonString );
        return ( LWC_ExceptionData ) JSON.deserialize ( jsonString, LWC_ExceptionData.class );
    }

    public string serialize () {
        return JSON.serialize ( this );
    }
}