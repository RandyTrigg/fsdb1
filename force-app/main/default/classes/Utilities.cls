global inherited sharing class Utilities {
    // Miscellaneous utility constants and methods

    public static String EmailAddressIM = 'im@globalfundforwomen.org';
    public static String BaseUrl = URL.getSalesforceBaseUrl().toExternalForm();
    public static String ffdbPermissionSetName = 'FFDB_System_admin';

    public static Map<String, Map<String, Schema.SObjectField>> fieldMaps = new Map<String, Map<String, Schema.SObjectField>>{
        'Letter__c' => Schema.SObjectType.Letter__c.fields.getMap(),
        'Account' => Schema.SObjectType.Account.fields.getMap(),
        'Contact' => Schema.SObjectType.Contact.fields.getMap()
    };

    public static Map<String, List<String>> monthTranslations = new Map<String, List<String>>{
        'English' => new List<String>{
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December'
        },
        'French' => new List<String>{
            'janvier',
            'février',
            'mars',
            'avril',
            'mai',
            'juin',
            'juillet',
            'août',
            'septembre',
            'octobre',
            'novembre',
            'décembre'
        },
        'Spanish' => new List<String>{
            'enero',
            'febrero',
            'marzo',
            'abril',
            'mayo',
            'junio',
            'julio',
            'agosto',
            'septiembre',
            'octubre',
            'noviembre',
            'diciembre'
        },
        'Portuguese' => new List<String>{
            'janeiro',
            'fevereiro',
            'março',
            'abril',
            'maio',
            'junho',
            'julho',
            'agosto',
            'setembro',
            'outubro',
            'novembro',
            'dezembro'
        },
        'Russian' => new List<String>{
            'января',
            'февраля',
            'марта',
            'апреля',
            'мая',
            'июня',
            'июля',
            'августа',
            'сентября',
            'октября',
            'ноября',
            'декабря'
        },
        'Arabic' => new List<String>{
            'يناير/كانون الثاني',
            'فبراير/شباط',
            'مارس/آذار',
            'أبريل/نيسان',
            'مايو/أيّار',
            'يونيو/حزيران',
            'يوليو/تمّوز',
            'أغسطس/آب',
            'سبتمبر/أيلول',
            'أكتوبر/تشرين الأول',
            'نوفمبر/تشرين الثاني',
            'ديسمبر/كانون الأول'
        }
    };

    // Track which records are in is-updated or is-inserted processing.  Avoids recursive calls within a transaction.
    // Add record ids to the set as they're processed (say, in a trigger).  The "static" attribute means the set will be cleared for the next transaction.
    public static Set<Id> SetOfIDsInProcess = new Set<Id>();

    // Return first parameter if not null, else second parameter.
    public static object blankValue(object param1, object param2) {
        return param1 == null ? param2 : param1;
    }

    /*******************
     * ID
     *******************/

    // Return ID of record of given sobject with given name.
    public static Id recordIdFromName(string sobjectName, string recordName) {
        Id recordId = null;
        string nameQuery =
            'SELECT Name FROM ' +
            sobjectName +
            ' WHERE Name = \'' +
            recordName +
            '\'';
        //system.debug('In recordIdFromName sobjectName = ' + sobjectName + '; recordName = ' + recordName + '; nameQuery = ' + nameQuery);
        List<sObject> matches = Database.query(nameQuery);
        try {
            recordId = matches[0].Id;
        } catch (ListException e) {
            // Send email to IM if can't find the default record for the given sobject.
            Utilities.ExceptionAlertEmailToIM(
                e,
                'Cannot find the ' +
                recordName +
                ' record in ' +
                sobjectName
            );
        }
        return recordId;
    }

    // Return the record type ID for given object and type
    public static Id getRecTypeId(string objectName, string typeName) {
        Id RtId = [
            SELECT DeveloperName
            FROM RecordType
            WHERE SobjectType = :objectName AND DeveloperName = :typeName
            LIMIT 1
        ]
        .Id;
        return RtId;
    }

    // Return id of the ffdb app's permission set
    public static Id getPermSetId() {
        PermissionSet[] pSets = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :ffdbPermissionSetName
        ];
        return pSets.size() > 0 ? pSets[0].Id : null;
    }

    /*******************
     * NUMBER
     *******************/

    // Return a random integer number between lower (inclusive) and upper (exclusive)
    public static Integer getRandomInt(Integer lower, Integer upper) {
        return Math.round(Math.random() * (upper - lower)) + lower;
    }

    // Take max of two integers, handling null parameters.
    public static Integer maxInteger(Integer num1, Integer num2) {
        return num1 == null ? num2 : num2 == null ? num1 : Math.max(num1, num2);
    }

    // Take max of two decimals, handling null parameters.
    public static Decimal maxDecimal(Decimal num1, Decimal num2) {
        return num1 == null ? num2 : num2 == null ? num1 : Math.max(num1, num2);
    }

    // Convert set of strings into set of numbers.
    public static Set<Decimal> commaSepStringToDecimalSet(String commaSepStr) {
        if (commaSepStr == null)
            return null;
        Set<Decimal> result = new Set<Decimal>();
        for (String s : commaSepStr.split(',')) {
            String sTrim = s.trim();
            system.debug(
                'commaSepStringToDecimalSet: s = ' +
                s +
                '; sTrim = ' +
                sTrim +
                '; getNumber(sTrim) = ' +
                getNumber(sTrim)
            );
            if (getNumber(sTrim) != null)
                result.add(getNumber(sTrim).stripTrailingZeros());
        }
        system.debug(
            'commaSepStringToDecimalSet: result = ' + JSON.serialize(result)
        );
        return result;
    }

    // Use regex to check for numeric including decimal.
    static Pattern decimalPattern = Pattern.compile('^[-+]?\\d+(\\.\\d*)?$');
    public static Decimal getNumber(String value) {
        return String.isBlank(value) || !decimalPattern.matcher(value).find()
            ? null
            : Decimal.valueOf(value);
    }

    /*******************
     * DATE
     *******************/

    // Return true if given date is in particular/previous FY
    public static Boolean dateInThisFY(Date dateToTest) {
        return dateInFY(dateToTest, 0);
    }
    public static Boolean dateInLastFY(Date dateToTest) {
        return dateInFY(dateToTest, 1);
    }
    public static Boolean dateInLastFY2(Date dateToTest) {
        return dateInFY(dateToTest, 2);
    }
    public static Boolean dateInLastFY3(Date dateToTest) {
        return dateInFY(dateToTest, 3);
    }
    public static Boolean dateInLastFY4(Date dateToTest) {
        return dateInFY(dateToTest, 4);
    }

    // Return true if given date is in the given FY (given offset into the past from the current FY).
    public static Boolean dateInFY(Date d, integer offset) {
        if (d == null || offset == null)
            return false;
        integer FYStartYear = (date.today().month() >= 7)
            ? date.today().year() - offset
            : date.today().year() - offset - 1;
        return d >= date.newInstance(FYStartYear, 7, 1) &&
            d <= date.newInstance(FYStartYear + 1, 6, 30);
    }
    // Return the FY containing given date
    // For FFDB, simply returns the year.
    public static String FYfromDate(Date d) {
        if (d == null)
            return null;
        else
            return String.valueOf(d.Year());
        /*
        integer FYStartYear = (d.Month() >= 7) ? d.Year() : d.Year() - 1;
        return 'FY' +
            String.valueof(FYStartYear) +
            '-' +
            String.valueof(FYStartYear + 1);
        */
    }

    // Translate date to given language (with month spelled out, etc.)
    public static String translateDate(String language, Date d) {
        if (!monthTranslations.containsKey(language))
            language = 'English';
        String mTrans = monthTranslations.get(language)[d.month() - 1];
        if (language == 'Russian') {
            return d.day() + '.' + d.month() + '.' + d.year();
        } else if (language == 'French') {
            return 'le ' + d.day() + ' ' + mTrans + ' ' + d.year();
        } else if (language == 'Spanish' || language == 'Portuguese') {
            return d.day() + ' de ' + mTrans + ' de ' + d.year();
        } else if (language == 'Arabic') {
            return d.day() + ' ' + mTrans + ' ' + d.year();
        } else {
            return mTrans + ' ' + d.day() + ', ' + d.year();
        }
    }

    // Take maximum of two dates.
    public static date maxDate(Date date1, Date date2) {
        return date1 == null
            ? date2
            : date2 == null ? date1 : date1 >= date2 ? date1 : date2;
    }

    // Take minimum of two dates.
    public static date minDate(Date date1, Date date2) {
        return date1 == null
            ? date2
            : date2 == null ? date1 : date1 <= date2 ? date1 : date2;
    }

    /*******************
     * STRING
     *******************/

    // Return a random alphanumeric string of given length.
    // Found at http://salesforce.stackexchange.com/questions/43823/how-do-i-generate-a-random-string
    public static String generateRandomString(Integer len) {
        final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String randStr = '';
        while (randStr.length() < len) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), 62);
            randStr += chars.substring(idx, idx + 1);
        }
        return randStr;
    }

    // Format number appropriately for currency, e.g. 2000.1 as 2,000.10.
    // Found at http://salesforce.stackexchange.com/questions/318/what-is-a-concise-function-that-formats-a-string-decimal-into-a-currency-forma
    public static String formatCurrency(Decimal i) {
        if (i == null)
            return '0.00';
        i = Decimal.valueOf(Math.roundToLong(i * 100)) / 100;
        String s = (i.setScale(2) + (i >= 0 ? 0.001 : -0.001)).format();
        return s.substring(0, s.length() - 1);
    }

    // Round number to integer and then format with commas, e.g. 2000.1 as 2,000.
    public static String formatInteger(Decimal i) {
        if (i == null)
            return '0';
        i = Integer.valueOf(i);
        return i.format();
    }

    // Returns true if string is valid integer, either zero, positive or negative.
    public static Boolean isInteger(String str) {
        Pattern isnumbers = Pattern.Compile('^[-]?[0-9]+$');
        Matcher integerMatch = isnumbers.matcher(str);
        return integerMatch.Matches();
    }

    // Return string join capped at given char count.  That is, keep joining strings until the limit is passed.
    public static String stringJoinWithCharLimit(
        String[] strs,
        String separator,
        Integer charLimit
    ) {
        String[] partialList = new List<String>();
        Integer charCount = 0;
        if (strs != null) {
            for (String str : strs) {
                if (str == null)
                    continue;
                // Added # chars is string length plus separator (unless it's the first string).
                Integer len =
                    str.length() + (charCount == 0 ? 0 : separator.length());
                if (charCount + len <= charLimit) {
                    partialList.add(str);
                    charCount += len;
                } else
                    break;
            }
        }
        return String.join(partialList, separator);
    }

    // Remove nulls from a list of strings.
    public static String[] removeNulls(String[] lst) {
        Integer j = 0;
        if (lst != null) {
            while (j < lst.size()) {
                if (lst.get(j) == null)
                    lst.remove(j);
                else
                    j++;
            }
        }
        return lst;
    }

    // Return string in lower case, or null if string is null.
    public static String lower(String str) {
        return str == null ? null : str.toLowerCase();
    }

    /*******************
     * EMAILS
     *******************/

    // Send an email to IM following an exception
    public static void ExceptionAlertEmailToIM(Exception e, String errorMess) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new List<String>{ EmailAddressIM };
        mail.setToAddresses(toAddresses);
        mail.setReplyTo(EmailAddressIM);
        mail.setSenderDisplayName('Apex error message');
        mail.setSubject(
            errorMess +
            ' (' +
            UserInfo.getOrganizationName() +
            ')'
        );
        List<String> bodyLines = new List<String>();
        bodyLines.add(errorMess);
        if (e != null) {
            bodyLines.add('Message: ' + e.getMessage());
            bodyLines.add('Cause: ' + e.getCause());
            bodyLines.add('Line number: ' + e.getLineNumber());
            bodyLines.add('Stack trace: ' + e.getStackTraceString());
        }
        mail.setPlainTextBody(string.join(bodyLines, '\n'));
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }

    // Send an email to IM following an exception
    public static void BatchErrorEmail(String jobName, AsyncApexJob a) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new List<String>{
            a.CreatedBy.Email,
            EmailAddressIM
        };
        mail.setToAddresses(toAddresses);
        mail.setSubject('Salesforce ' + jobName + ' ' + a.Status);
        mail.setPlainTextBody(
            'The batch Apex job processed ' +
            a.TotalJobItems +
            ' batches with ' +
            a.NumberOfErrors +
            ' failures.'
        );
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }

    // Return emails for given accounts.  Dish off to code in AccountController.
    public static Map<Id, List<String>> emailsForAccounts(Set<Id> aIds) {
        return AccountController.emailsForAccounts(aids); 
    }

    /*******************
     * METADATA-BASED METHODS
     *******************/

    // Build a new record with the type passed in as an argument at run time.
    public static sObject newRecord(String typeName) {
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(typeName);
        return targetType != null ? targetType.newSObject() : null; 
    }

    // Returns map of field name with ability to get describe.
    public static Map<String, Schema.SObjectField> fieldMapForObject(String objName) {
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map<String, Schema.SObjectField> fieldMap = schemaMap.get(objName)
            .getDescribe()
            .fields.getMap();
        return fieldMap;
    }
    
    // Returns map of record type DeveloperName to record type Id.
    public static Map<String, Id> recTypeMapForObject(String objName) {
        // Example used as reference: String gsRecordTypeID = Schema.getGlobalDescribe().get('Case').getDescribe().getRecordTypeInfosByName().get('Record Type Label').getRecordTypeId();
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map<String, Schema.RecordTypeInfo> recTypeMap = schemaMap.get(objName)
            .getDescribe()
            .getRecordTypeInfosByDeveloperName();
        Map<String, Id> recTypeMapNameId = new Map<String,Id>();
        for (String name : recTypeMap.keyset()) {
            recTypeMapNameId.put(name, recTypeMap.get(name).getRecordTypeId());
        }
        return recTypeMapNameId;
    }

    // Package Ids for WHERE IN query clause.
    public static String packageIdsForQuery(Set<Id> Ids) {
        // Ids in quotes, separated by commas, and encased as a whole in parentheses: '(\'a0D1Y000017aM9WUAU\',\'a0D1Y000017aMAYUA2\')'
        String inIDsStr = '(';
        for (Id thisId : Ids) {
            inIDsStr = inIDsStr + '\'' + thisId + '\',';
        }
        inIDsStr = inIDsStr.removeEnd(',') + ')';
        return inIDsStr;
    }

    // Return record for given object with given id.  Fetch all local fields plus any given related ones.
    public static sObject fetchRecord(
        String objName,
        Id recId,
        String[] relatedFieldNames
    ) {
        if (objName == null || recId == null)
            return null;
        String[] fieldNames = fieldNamesForObject(objName);
        if (relatedFieldNames != null)
            fieldNames.addAll(relatedFieldNames);
        String q =
            'SELECT ' +
            String.join(fieldNames, ', ') +
            ' FROM ' +
            objName +
            ' WHERE Id = : recId';
        system.debug('fetchRecord: q = ' + q);
        return Database.query(q);
    }

    // Build a child relationship sub-query, to be used in fetchRecord calls.
    public static String buildChildSubQuery(
        String objName,
        String relName,
        String whereClause
    ) {
        return '(SELECT ' +
            String.join(Utilities.fieldNamesForObject(objName), ', ') +
            ' FROM ' +
            relName +
            (whereClause != null ? ' ' + whereClause : '') +
            ')';
    }

    // Return records for given object using given where clause.  Fetch all local fields plus any given related ones.
    public static sObject[] fetchRecords(
        String objName,
        String whereClause,
        String[] relatedFieldNames
    ) {
        if (objName == null)
            return null;
        whereClause = whereClause != null ? ' ' + whereClause : ''; 
        String[] fieldNames = fieldNamesForObject(objName);
        if (relatedFieldNames != null)
            fieldNames.addAll(relatedFieldNames);
        String q =
            'SELECT ' +
            String.join(fieldNames, ', ') +
            ' FROM ' +
            objName +
            whereClause;
        system.debug('fetchRecords: q = ' + q);
        return Database.query(q);
    }

    // Return record for given object with given id.
    // Fetch all local fields plus specified related fields, plus all local fields of related records identified by list of relationship names.
    public static sObject fetchRecordAndRelatedRecords(
        String objName,
        Id recId,
        String[] relatedFieldNames,
        String[] relationshipNames
    ) {
        if (objName == null || recId == null)
            return null;
        // Build mapping of relationship names to object names.
        Schema.sObjectType obj = recId.getsobjecttype();
        Map<String, String> relObjNames = new Map<String, String>();
        for (
            Schema.SobjectField fld : obj.getDescribe().fields.getMap().Values()
        ) {
            if (fld.getDescribe().getType() == Schema.DisplayType.REFERENCE) {
                String relationshipName = fld.getDescribe()
                    .getRelationshipName();
                String relObjectName = fld.getDescribe().getReferenceTo()[0]
                    .getDescribe()
                    .getName();
                relObjNames.put(relationshipName, relObjectName);
            }
        }
        // Combine local fields with fields from related records.
        Set<String> fieldNames = new Set<String>();
        for (String fName : fieldNamesForObject(objName))
            fieldNames.add(fName.toLowerCase());
        for (String fName : relatedFieldNames)
            fieldNames.add(fName.toLowerCase());
        for (String relName : relationshipNames) {
            String oName = relObjNames.get(relName);
            if (oName != null) {
                for (String fName : fieldNamesForObject(oName))
                    fieldNames.add((relName + '.' + fName).toLowerCase());
            }
        }
        //for (String fName : new List<String> (fieldNames)) system.debug('fetchRecord: fName = ' +fName);
        // Build and run query.
        String q =
            'SELECT ' +
            String.join(new List<String>(fieldNames), ', ') +
            ' FROM ' +
            objName +
            ' WHERE Id = : recId';
        system.debug('fetchRecord: q = ' + q);
        return Database.query(q);
    }

    // Return child records for given object with given parent id and given lookup field name.  Fetch all local fields plus any given related ones.
    public static sObject[] fetchChildRecords(
        String objName,
        Id parentId,
        String lookupFieldName,
        String[] relatedFieldNames
    ) {
        if (objName == null || parentId == null || lookupFieldName == null)
            return null;
        String[] fieldNames = fieldNamesForObject(objName);
        if (relatedFieldNames != null)
            fieldNames.addAll(relatedFieldNames);
        String q =
            'SELECT ' +
            String.join(fieldNames, ', ') +
            ' FROM ' +
            objName +
            ' WHERE ' +
            lookupFieldName +
            ' = : parentId';
        system.debug('fetchChildRecords: q = ' + q);
        return Database.query(q);
    }

    // Return list of the names of all fields in given object (for use in dynamic queries).
    public static String[] fieldNamesForObject(String objName) {
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map<String, Schema.SObjectField> fieldMap = schemaMap.get(objName)
            .getDescribe()
            .fields.getMap();
        return new List<String>(fieldMap.keySet());
    }

    // Return a mapping from field name to picklist values for all picklist fields in given object.
    public static Map<String, List<String>> getPicklists(String objName) {
        Map<String, List<String>> plMap = new Map<String, List<String>>();
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
            .get(objName)
            .getDescribe()
            .fields.getMap();
        for (String fName : fieldMap.keySet()) {
            if (
                fieldMap.get(fName).getDescribe().getType() ==
                Schema.DisplayType.Picklist
            )
                plMap.put(fName, picklistValues(objName, fName));
        }
        return plMap;
    }

    // Lookup picklist values for given field of given object.
    public static String[] picklistValues(String objName, String fieldName) {
        Schema.DescribeSobjectResult objMetadata = Schema.describeSObjects(
            new List<String>{ objName }
        )[0];
        Schema.SObjectField fieldMetadata = objMetadata.fields.getMap()
            .get(fieldName);
        List<Schema.PicklistEntry> picklistMetadataList = fieldMetadata.getDescribe()
            .getPicklistValues();
        List<String> pickvals = new List<String>();
        for (Schema.PicklistEntry a : picklistMetadataList)
            pickvals.add(a.getValue());
        return pickvals;
    }

    // Reparent child records of the source record to the target record.  Source and target must be same object type.
    // Only child records with "updateable" lookup fields are reparented.
    // If one of the child's other reference fields appears in grandparentFieldNamesToReparent,
    // then set that to the value of the target's field of the same name.
    public static void reparentChildren(
        Id sourceId,
        Id targetId,
        String[] grandparentFieldNamesToReparent
    ) {
        String q;
        SObject target;
        // Ensure that source and target are from same object.
        if (sourceId.getsobjecttype() != targetId.getsobjecttype())
            return;
        SObject[] childrenToUpdate = new List<SObject>();
        Schema.sObjectType parentObj = sourceId.getsobjecttype();
        String parentObjName = parentObj.getDescribe().getName();
        // Constrain grandparent field names to those actually present on the parent object.
        Set<String> grandparentFNames = refFieldNames(parentObj);
        grandparentFNames.retainAll(grandparentFieldNamesToReparent);
        // Fetch target record including all reference fields.
        if (grandparentFNames.size() > 0) {
            q =
                'SELECT Id, ' +
                String.join(new List<String>(grandparentFNames), ', ') +
                ' FROM ' +
                parentObjName +
                ' WHERE Id = : targetId';
            target = database.query(q);
        }
        // Loop through child relationships of the parent object.
        for (
            Schema.ChildRelationship cr : parentObj.getDescribe()
                .getChildRelationships()
        ) {
            Schema.sObjectType childObj = cr.getChildSObject();
            Schema.SObjectField relField = cr.getField();
            if (relField.getDescribe().isUpdateable()) {
                // Process child object if rel field is updateable.
                String childObjName = childObj.getDescribe().getName();
                String relFieldName = relField.getDescribe().getName();
                system.debug(
                    'reparentChildren: childObjName = ' +
                    childObjName +
                    '; relFieldName = ' +
                    relFieldName
                );
                Set<String> refFieldNames = refFieldNames(childObj);
                system.debug(
                    'reparentChildren: refFieldNames = ' +
                    JSON.serialize(refFieldNames)
                );
                // Get source record's children of given object type.
                q =
                    'SELECT Id FROM ' +
                    childObjName +
                    ' WHERE ' +
                    relFieldName +
                    ' = : sourceId';
                SObject[] childRecs = database.query(q);
                // Reparent the child recs.
                for (SObject rec : childRecs) {
                    rec.put(relFieldName, targetId);
                    // Assign other ref fields that are on the grandparent field list.
                    for (String fName : grandparentFNames) {
                        system.debug(
                            'reparentChildren, grandparent field loop: fName = ' +
                            fName +
                            '; target.get(fName) = ' +
                            target.get(fName)
                        );
                        if (refFieldNames.contains(fName))
                            rec.put(fName, target.get(fName));
                        childrenToUpdate.add(rec);
                    }
                }
            }
            system.debug('');
        }
        if (childrenToUpdate.size() > 0) {
            // Update using batch processing to avoid governor limits from processes/flows.
            // Use small batch size except when testing where we're allowed only one executeBatch call.
            Integer batchSize = Test.isRunningTest() ? 100 : 1;
            Database.executeBatch(
                new GenericUpdateRecordsBatch(childrenToUpdate),
                batchSize
            );
        }
    }

    // Return the names of reference fields in the given object.
    public static Set<String> refFieldNames(Schema.sObjectType obj) {
        Set<String> fNames = new Set<String>();
        for (
            Schema.SobjectField fld : obj.getDescribe().fields.getMap().Values()
        ) {
            if (fld.getDescribe().getType() == Schema.DisplayType.REFERENCE)
                fNames.add(fld.getDescribe().getName());
        }
        return fNames;
    }

    // Return the names of editable fields of given type in given object.
    public static List<String> updateableFieldNamesOfType(
        String objName,
        String typeName
    ) {
        // Build map to convert type names to type enums.
        Map<String, Schema.DisplayType> typeMap = new Map<String, Schema.DisplayType>();
        for (Schema.DisplayType type : Schema.DisplayType.values())
            typeMap.put(type.name(), type);
        Schema.sObjectType obj = Schema.getGlobalDescribe().get(objName);
        String[] fNames = new List<String>();
        for (
            Schema.SobjectField fld : obj.getDescribe().fields.getMap().Values()
        ) {
            if (
                fld.getDescribe().getType() ==
                typeMap.get(typeName.toUpperCase()) &&
                fld.getDescribe().isUpdateable()
            )
                fNames.add(fld.getDescribe().getName());
        }
        return fNames;
    }

    // Return a "clone" of given record skipping the given fields.
    // Note that we're not calling the sobject clone method so that skipped fields (in particular, parent lookup) never get values.
    // Otherwise, the external id trick doesn't work when inserting the "cloned" record.
    @AuraEnabled
    public static sObject cloneSkippingFields(
        sObject rec,
        List<String> fieldsToSkip
    ) {
        Set<String> fieldsToSkipLower = new Set<String>();
        system.debug(
            'cloneSkippingFields: fieldsToSkip = ' +
            JSON.serialize(fieldsToSkip)
        );
        for (String s : fieldsToSkip)
            fieldsToSkipLower.add(s.toLowerCase());
        SObjectType obj = rec.getsObjectType();
        sObject newRec = obj.newSObject();
        Map<String, Schema.SObjectField> fMap = obj.getDescribe()
            .fields.getMap();
        for (String fName : fMap.keySet()) {
            Boolean updateable = fMap.get(fName).getDescribe().isUpdateable();
            //system.debug('cloneSkippingFields in loop: fName = ' +fName+ '; updateable = ' +updateable);
            // Copy field value if field is updateable and not on skip list.
            if (
                updateable && !fieldsToSkipLower.contains(fName.toLowerCase())
            ) {
                system.debug(
                    'cloneSkippingFields in loop: field to copy = ' +
                    fName +
                    '; updateable = ' +
                    updateable
                );
                newRec.put(fName, rec.get(fName));
            }
        }
        system.debug('cloneSkippingFields: newRec = ' + JSON.serialize(newRec));
        return newRec;
    }

    // Return the value of the specified field from the record having the given Id.
    // JSON for parameters and returned values in order to communicate with lightning components.
    @AuraEnabled
    public static String fieldValueFromRecordId(String jsonString) {
        strike_responseData responseData = new strike_responseData();
        try {
            system.debug('fieldValueFromRecordId: jsonString = ' + jsonString);
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(
                jsonString
            );
            system.debug(
                'fieldValueFromRecordId: jsonMap = ' + JSON.serialize(jsonMap)
            );
            Id recordId = (Id) jsonMap.get('recordId');
            String fName = (String) jsonMap.get('fieldName');
            String objName = objectNameFromRecordId(recordId);
            if (objName.endsWith('__c'))
                fName = massageFieldName(fName); // For custom objects, ensure related fields have "-r" format.
            // Fetch field from record.
            String q =
                'SELECT Id, ' +
                fName +
                ' FROM ' +
                objName +
                ' WHERE Id = : recordId';
            sObject target = database.query(q);
            // Calculate the field's value stepping through successive related records if necessary.
            Object fieldValue;
            String[] parts = fName.split('\\.');
            Integer numParts = parts.size();
            sObject curRecord = target;
            for (Integer i = 0; i < numParts; i++) {
                if (i == numParts - 1)
                    fieldValue = (Object) curRecord.get(parts[i]);
                else
                    curRecord = curRecord.getSObject(parts[i]);
            }
            responseData.results = new Map<String, Object>{
                'fieldValue' => fieldValue
            };
        } catch (Exception e) {
            responseData.addError(e.getMessage());
        }
        system.debug(
            'fieldValueFromRecordId: responseData = ' +
            JSON.serialize(responseData)
        );
        return responseData.getJsonString();
    }

    // Get object name from record Id.
    public static String objectNameFromRecordId(Id recId) {
        Schema.sObjectType objType = recId.getsobjecttype();
        return objType.getDescribe().getName();
    }

    // Update record if field value is different from current value.
    public static void updateIfFieldChanged(
        sObject record,
        String fieldName,
        Object fieldValue
    ) {
        if (
            record != null &&
            fieldName != null &&
            record.get(fieldName) != fieldValue
        ) {
            record.put(fieldName, fieldValue);
            update record;
        }
    }

    /*******************
     * PROCESSING MERGE FIELDS
     *******************/

    // Return the value of given field within given record.
    public static Object getValue(sObject context, String fName) {
        Object fValue;
        if (fName.toLowerCase() == 'null')
            return null;
        fName = massageFieldName(fName); // Ensure that related field names have __r syntax.
        List<String> parts = fName.split('\\.', 5);
        String lastPart = parts[parts.size() - 1];
        // Build parent (related) record for the field
        sObject record = context;
        for (Integer i = 0; i < parts.size() - 1; i++) {
            record = record.getSObject(parts[i]);
        }
        // If last part ends in __r, then return as a list of records. Else, just fetch value.
        return lastPart.right(3) == '__r'
            ? (Object) record.getSObjects(lastPart)
            : (Object) record.get(lastPart);
    }

    // Return set of merge fields in given string.  Merge fields are enclosed in double angle brackets (<<...>>).
    public static Set<String> getMergeFields(String text) {
        Set<String> fNames = new Set<String>();
        Integer pos = 0;
        if (text != null) {
            while (pos < text.length()) {
                Integer angleStart = text.indexOf('<<', pos);
                Integer angleEnd = text.indexOf('>>', Math.max(angleStart, 0));
                if (angleStart < 0 || angleEnd < angleStart)
                    break; // Bail if no more merge fields found in string.
                fNames.add(text.substring(angleStart + 2, angleEnd));
                pos = angleEnd;
            }
        }
        return fNames;
    }

    // Replace merge fields with their values in the given string.  Merge fields are enclosed in double angle brackets (<<...>>).
    public static String evalMergeFields(String text, sObject context) {
        Integer pos = 0;
        while (pos < text.length()) {
            Integer startFieldName = text.indexOf('<<', pos);
            Integer endFieldName = text.indexOf(
                '>>',
                Math.max(startFieldName, 0)
            );
            if (startFieldName < pos || endFieldName < startFieldName)
                break; // Bail if no merge field found in text.
            Object val = getValue(
                context,
                text.substring(startFieldName + 2, endFieldName)
            );
            text = text.replace(
                text.substring(startFieldName, endFieldName + 2),
                (val == null) ? '' : String.valueof(val)
            );
            pos = startFieldName;
        }
        return text;
    }

    // Add __r notation to related field names as appropriate.
    public static List<String> massageFieldNames(List<String> fNames) {
        List<String> massagedFNames = new List<String>();
        for (String fName : fNames)
            massagedFNames.add(massageFieldName(fName));
        return massagedFNames;
    }

    // Ensure that related field names have __r notation.
    // Also replace link to owner fields in account, with cached lookup relationship in letters (Account_owner).
    public static String massageFieldName(String fName) {
        return fName.replace('.', '__r.')
            .replace('__c__r.', '__r.')
            .replace('__r__r.', '__r.')
            .replace('Account__r.Owner__r.', 'Account_owner__r.')
            .replace('Owner__r.', 'Letter_owner__r.')
            .replace('RecordType__r', 'RecordType');
    }

    /*******************
     * MISCELLANEOUS
     *******************/

    // Build menu (select options) consisting of all available templates appropriate for given object.
    // The "start" entry is disabled.
    public static List<selectOption> templatesForObject(
        String objectName,
        String start
    ) {
        Template__c[] templates = [
            SELECT Name, Allowed_statuses__c
            FROM Template__c
            WHERE Source_object__c = :objectName AND Active__c = true
            ORDER BY Name
        ];
        return templatesMenu(templates, start, null, null);
    }

    // Build menu (select options) consisting of given templates with "start" entry disabled.
    // Fetches active templates for given object name, and calls the "workhorse" implementation to build the menu, optionally filtering for statuses.
    // There are two implementations of this method so that callers can optionally pre-filter the templates.
    public static List<selectOption> templatesMenu(
        String objectName,
        String start,
        List<sObject> recs,
        String statusFieldName
    ) {
        Template__c[] templates = [
            SELECT Name, Allowed_statuses__c
            FROM Template__c
            WHERE Source_object__c = :objectName AND Active__c = true
            ORDER BY Name
        ];
        return templatesMenu(templates, start, recs, statusFieldName);
    }

    // Build menu (select options) consisting of given templates with "start" entry disabled. Called with list of templates.
    // If statusFieldName is non-null, filter for templates whose allowed statuses cover the recs.
    public static List<selectOption> templatesMenu(
        List<Template__c> ts,
        String start,
        List<sObject> recs,
        String statusFieldName
    ) {
        List<selectOption> templates = new List<selectOption>();
        templates.add(new selectOption(start, start, true)); // Disable the START option
        // Gather statuses if statusFieldName is non-blank.
        Set<Decimal> statuses = new Set<Decimal>();
        if (!String.isBlank(statusFieldName) && recs != null) {
            for (sObject rec : recs) {
                Decimal status = (Decimal) getValue(rec, statusFieldName);
                if (status != null)
                    statuses.add(status.stripTrailingZeros());
            }
        }
        // Gather templates into a menu, filtering for those that cover the records' statuses.
        for (Template__c t : ts) {
            Set<Decimal> allowedStatuses = commaSepStringToDecimalSet(
                t.Allowed_statuses__c
            );
            system.debug(
                'fetchTemplates: allowedStatuses = ' +
                JSON.serialize(allowedStatuses)
            );
            // If the template specifies a list of statuses, then it needs to include all statuses that appear in the records.
            if (
                t.Allowed_statuses__c == null ||
                allowedStatuses.containsAll(statuses)
            )
                templates.add(new selectOption(t.name, t.name));
        }
        return templates;
    }

    // Build tasks for given record based on task specs in the given task spec group.
    public static void instantiateTaskSpecs(
        Id recId,
        Id taskSpecGroupId,
        Id reportTaskAssignedToOverrideId,
        Date baseDate
    ) {
        system.debug(
            'instantiateTaskSpecs: recId = ' +
            recId +
            '; taskSpecGroupId = ' +
            taskSpecGroupId
        );
        List<Task_Spec__c> tSpecs = [
            SELECT
                Id,
                Subject__c,
                Type__c,
                Comments__c,
                Assigned_to__c,
                Due_date__c,
                Days_after__c
            FROM Task_Spec__c
            WHERE Task_Spec_Group__c = :taskSpecGroupId AND Active__c = true
        ];
        system.debug(
            'instantiateTaskSpecs: tSpecs = ' + JSON.serialize(tSpecs)
        );
        List<Task> tasksToInsert = new List<Task>();
        for (Task_Spec__c ts : tSpecs)
            tasksToInsert.add(
                instantiateTaskSpec(
                    recId,
                    ts,
                    reportTaskAssignedToOverrideId,
                    baseDate
                )
            );
        system.debug(
            'instantiateTaskSpecs: tasksToInsert = ' +
            JSON.serialize(tasksToInsert)
        );
        if (tasksToInsert.size() > 0)
            insert tasksToInsert;
    }

    // Build task for given record based on given task spec.  Fetch task spec and call second version.
    public static Task instantiateTaskSpec(
        Id recId,
        Id taskSpecId,
        Id reportTaskAssignedToOverrideId,
        Date baseDate
    ) {
        system.debug(
            'instantiateTaskSpec: recId = ' +
            recId +
            '; taskSpecId = ' +
            taskSpecId
        );
        Task_Spec__c tSpec = (Task_Spec__c) fetchRecord(
            'Task_Spec__c',
            taskSpecId,
            null
        );
        return instantiateTaskSpec(
            recId,
            tSpec,
            reportTaskAssignedToOverrideId,
            baseDate
        );
    }
    // In this version, task spec has been fetched.  Caller needs to do the insert.
    public static Task instantiateTaskSpec(
        Id recId,
        Task_Spec__c ts,
        Id reportTaskAssignedToOverrideId,
        Date baseDate
    ) {
        system.debug('instantiateTaskSpec: ts = ' + JSON.serialize(ts));
        if (baseDate == null)
            baseDate = Date.today();
        Task t;
        if (ts != null) {
            Date dueDate = ts.Due_date__c;
            if (dueDate == null && ts.Days_after__c != null)
                dueDate = baseDate.addDays((Integer) ts.Days_after__c);
            Boolean overrideAssignedTo =
                reportTaskAssignedToOverrideId != null &&
                (ts.Type__c == 'Report' ||
                ts.Type__c == 'Report/interim');
            t = new Task(
                WhatId = recId,
                ActivityDate = dueDate,
                OwnerId = overrideAssignedTo
                    ? reportTaskAssignedToOverrideId
                    : ts.Assigned_to__c,
                Subject = ts.Subject__c,
                Type = ts.Type__c,
                Description = ts.Comments__c,
                Priority = 'Normal',
                Status = 'Not Started'
            );
        }
        system.debug('instantiateTaskSpec: t = ' + JSON.serialize(t));
        return t;
    }

    // Return list of the names of permission sets that are assigned to the current user.
    public static List<String> currentUserPermissionSetNames() {
        List<String> permSetNames = new List<String>();
        List<PermissionSetAssignment> permSets = [
            SELECT Id, PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE AssigneeId = :Userinfo.getUserId()
        ];
        for (PermissionSetAssignment p : permSets)
            permSetNames.add(p.PermissionSet.Name);
        return permSetNames;
    }

    // Assign the FFDB permission set to given user after checking that the assignment hasn't already been made.
    public static void assignPermissionSetToCurrentUser() {
        if (!currentUserPermissionSetNames().contains(ffdbPermissionSetName)) {
            insert new PermissionSetAssignment(
                PermissionSetId = Utilities.getPermSetId(),
                AssigneeId = UserInfo.getUserId()
            );
        }
    }

    // Return name of current user's profile.
    public static String currentUserProfileName() {
        Id profileId = UserInfo.getProfileId();
        return [SELECT Name FROM Profile WHERE Id = :profileId].Name;
    }

    // Return default record owner Id for FSGroup of given user.
    public static Id fsDefaultRecordOwnerIdByUser(Id usrId) {
        FS_Group_Settings__mdt fsGroup = fsGroupOfUser(usrId);
        Id ownerId;
        if (fsGroup!=null) {
            ownerId = [SELECT Id, UserRoleId, UserRole.DeveloperName 
                FROM User
                WHERE UserRole.DeveloperName =:fsGroup.Designated_Role_for_Ownership__c
                AND IsActive = true][0].Id;
        }
        return ownerId;
    }

    // Return public group name of FSGroup for given user.
    public static String fsGroupNameByUser(Id usrId) {
        FS_Group_Settings__mdt fsGroup = fsGroupOfUser(usrId);
        if (fsGroup!=null) return fsGroup.Public_Group_Name__c;
        return '';
    }

    // Return public group name of FS Group for given user.
    public static FS_Group_Settings__mdt fsGroupOfUser(Id usrId) {
        // If Customer Community user, retrieve FS Group by SF Profile and custom metadata type records.
        // Else, go upstream in hierarchy from user's role to identify FS Group, if any.
        FS_Group_Settings__mdt[] fsGroups = fetchRecords(
            'FS_Group_Settings__mdt',
            'WHERE Active__c = true',
            null
        );
        User usr = [SELECT Id, Profile.Name, Profile.UserLicense.Name, UserRoleId FROM User WHERE Id=:usrId];
        Boolean isCommunityUsr = (usr.Profile.UserLicense.Name == 'Customer Community Login');
        Map<String, FS_Group_Settings__mdt> groupRole = new Map<String, FS_Group_Settings__mdt>();
        for (FS_Group_Settings__mdt fsGrp : fsGroups) {
            if (isCommunityUsr && usr.Profile.Name.contains(fsGrp.DeveloperName)) {
                return fsGrp;
            } else {
                groupRole.put(fsGrp.Designated_Role_for_Ownership__c, fsGrp);
            }
        }
        Map<Id, UserRole> usrRoles = new Map<Id, UserRole>([
            SELECT Id, DeveloperName, ParentRoleId 
            FROM UserRole]);
        UserRole thisRole = new UserRole();
        thisRole = usrRoles.get(usr.UserRoleId);
        // Cycle through parent roles to find relevant FS Group
        while (thisRole != null) {
            if (groupRole.containsKey(thisRole.DeveloperName)) return groupRole.get(thisRole.DeveloperName);
            thisRole = usrRoles.get(thisRole.ParentRoleId);
        }
        return null;
    }

    // Return new page reference for given record.
    public static PageReference pageReferenceForRecord(sObject rec) {
        PageReference pr = new ApexPages.StandardController(rec).view();
        pr.setRedirect(true);
        return pr;
    }

    // Return the language specified in Company Information
    public static String defaultLanguage() {
        Organization orgDetails = [
            SELECT Id, LanguageLocaleKey
            FROM Organization
        ];
        // Build table mapping language code to language name.
        Map<String, String> languageCodes = new Map<String, String>();
        for (
            PicklistEntry entry : User.LanguageLocaleKey.getDescribe()
                .getPicklistValues()
        ) {
            languageCodes.put(entry.getValue(), entry.getLabel());
        }
        String lang = languageCodes.get(orgDetails.LanguageLocaleKey);
        // Peel off possible parenthetical from the end of the language value.
        Integer parenIndex = lang.indexOf('(');
        return parenIndex > 0 ? lang.left(parenIndex - 1) : lang;
    }
}