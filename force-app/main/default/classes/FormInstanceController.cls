public inherited sharing class FormInstanceController {

    /**********************************
     * For use in Lightning components
     *********************************/
    
    // Fetch all local fields of a form instance record, plus a few specified related fields. 
    @AuraEnabled
    public static Form_Instance__c getFormInstance(Id fiId) {
        String[] relatedFieldNames = new List<String>{'Profile__r.Name', 'Profile__r.Account__c', 'Profile__r.Account__r.Name'};
        return (Form_Instance__c) Utilities.fetchRecord('Form_Instance__c', fiId, relatedFieldNames);
    }
    
    // Fetch the form's form components, plus a few specified related fields. 
    @AuraEnabled
    public static Form_Component__c[] getComponents(Id formId) {
        String[] relatedFieldNames = new List<String>{
            'Form_Phrase__r.Phrase_in_English__c'
			};
        String whereClause = 
            ' WHERE Form__c = \'' +formId+ '\'' +
            ' ORDER BY Hierarchical_sort_num__c';
        return (List<Form_Component__c>) Utilities.fetchRecords('Form_Component__c', whereClause, relatedFieldNames);
    }
    
    // Fetch all local fields of the form instance's form data, plus a few specified related fields. 
    @AuraEnabled
    public static Form_Data__c[] getFormData(Id fiId) {
        String[] relatedFieldNames = new List<String>{
            'Form_Component__r.Form__c', 'Form_Component__r.Form__r.Name',
            'Form_Component__r.Name', 'Form_Component__r.NoFormDataClone__c'
			};
        String whereClause = 
            ' WHERE Form_Instance__c = \'' +fiId+ '\'' +
            ' ORDER BY Form_Component__c, Index__c, LastModifiedDate DESC';
        return (List<Form_Data__c>) Utilities.fetchRecords('Form_Data__c', whereClause, relatedFieldNames);
    }

    // Return a mapping of form component id to its appropriate number string based on hierarchical sort order.
    public static Map<Id, String> buildCmpNumberMap (Form_Component__c[] cmps) {
        Map<Id, Form_Component__c> cmpsMap = new Map<Id, Form_Component__c> (cmps);
        Map<Id, String> cmpsNumberMap = new Map<Id, String> ();
        // Build mapping of id to count of its numbered descendant form components.
        Map<Id, Integer> descendantCmpsCount = new Map<Id, Integer> ();
        for (Form_Component__c cmp : cmps) {
            if (cmp.Numbered__c) {
                Id cId = cmp.Group_component__c;
                while (cId != null) { // Walk up the hierarchy to parent, grandparent, etc.
                    Boolean hasCount = descendantCmpsCount.containsKey(cId);
                    descendantCmpsCount.put(cId, hasCount ? descendantCmpsCount.get(cId) + 1 : 1);
                    cId = cmpsMap.get(cId).Group_component__c;
                }
            }
        }
        // Track which components need to trim away their top numbering level, e.g. 4.3 (or 4c) becomes 3, namely,
        // top level unnumbered components and all their descendants. 
        Set<Id> trimTopLevelNumbering = new Set<Id>();
        for (Form_Component__c cmp : cmps) {
            Id parentId = cmp.Group_component__c;
            if (parentId == null && cmp.Hierarchical_level_num__c == 0 && !cmp.Numbered__c) trimTopLevelNumbering.add(cmp.Id); 
            else if (parentId != null && trimTopLevelNumbering.contains(parentId)) trimTopLevelNumbering.add(cmp.Id);
        }
        // Build mapping of id to form component number based on hierarchical position.
        Integer level;
        Integer priorLevel = 0;
        String num;
        String priorNum = '0';
        Boolean numbering = true;
        for (Form_Component__c cmp : cmps) {
            level = Integer.valueOf(cmp.Hierarchical_level_num__c);
            // If numbering is off, leave it off until we bounce back to the level where it was turned off.
            if (!numbering && level <= priorLevel) numbering = true;
            // Turn numbering off if this component isn't numbered nor are any of its descendants.
            if (!cmp.Numbered__c && !descendantCmpsCount.containsKey(cmp.Id)) numbering = false;
            else if (cmp.Numbered__c) numbering = true;
            if (numbering) { // The next cmp needs numbering.
                // Increment the number at the (possibly new) level.
                system.debug('buildCmpNumberMap: num = ' +num+ '; priorNum = ' +priorNum+ '; level = ' +level);
                num = incCmpNum(priorNum, level);
                // If cmp is supposed to be sub-numbered, then start it at the next level down.
                if (cmp.Sub_numbered__c) {
                    level = level+1;
                    system.debug('buildCmpNumberMap: num = ' +num+ '; priorNum = ' +priorNum+ '; level = ' +level);
                    num = incCmpNum(num, level);
                }
                priorLevel = level;
                priorNum = num;
            } else num = null;
            if (num != null) cmpsNumberMap.put(cmp.Id, cmpNumDisplay(num, trimTopLevelNumbering.contains(cmp.Id)));
        }
        system.debug('buildCmpNumberMap: cmpsNumberMap.size() = ' +cmpsNumberMap.size());
        return cmpsNumberMap;
    }
    
    // Increment a form component number to the next one at the given zero-based level, possibly popping higher levels.
    // A cmp number is a period-delimited sequence of numbers, ala 1.3.2.
    // For level=1, the result is 1.4; for level=0, the result is 2.
    private static String incCmpNum (String numStr, Integer level) {
        String[] numStrList = numStr.split('\\.'); // Break up string using '.' as delimiter.
        // Compute a "slice" of the first level+1 elements of the num list. 
        String[] numArr = new List<String> ();
        for(Integer a = 0; a < Math.min(numStrList.size(), level+1); a++) numArr.add(numStrList[a]);
        system.debug('incCmpNum: level = ' +level+ '; numStrList = ' +JSON.serialize(numStrList));
        system.debug('incCmpNum: numArr = ' +JSON.serialize(numArr));
        if (numArr.size() < level+1) numArr.add('1');
        else numArr.add(String.valueOf(Integer.valueOf(numArr.remove(numArr.size()-1)) + 1));
        return String.join(numArr, '.');
    }

    // Reformat a cmp number for display in cmp labels.  For example, 1.3.2 becomes 1c.2.
    // If trimTopLevel is true, then first remove the 0th level of numbering (1.3.2 becomes 3.2).
    private static String cmpNumDisplay (String numStr, Boolean trimTopLevel) {
        Integer firstDotPosition = numStr.indexOf('.');
        // Drop the leftmost level of numbering if we're trimming top level.
        if (trimTopLevel && firstDotPosition > 0) numStr = numStr.right(numStr.length()-firstDotPosition-1);
        String[] numArr = numStr.split('\\.');
        if (numArr.size() <= 1) return numStr;
        String prefix = numArr[0] + String.fromCharArray(new List<Integer> {'a'.charAt(0) + Integer.valueOf(numArr[1]) - 1});
        // Attach prefix to rest of the item number.
        String[] numArrResult = new List<String> {prefix};
        for (Integer i = 2; i < numArr.size(); i++) numArrResult.add(numArr[i-1]);
        return String.join(numArrResult, '.');
    }

     /**********************************
     * Invoked from LWCs via SiteController class
     *********************************/
    
    // Return a list of form instances to be displayed in form viewer for the given record (normally a profile, proposal, or milestone).
    public static List<Form_Instance__c> getFormInstances(Id id) {
        List<Form_Instance__c> fis = new List<Form_Instance__c>();
        String objName = Utilities.objectNameFromRecordId(id);
        Id profId, propId;
        // Grab parent ids
        if (objName == 'Profile__c') {
            profId = id;
        } else if (objName == 'Proposal__c') {
            Proposal__c prop = [SELECT Id, Profile__c FROM Proposal__c WHERE Id =: id];
            profId = prop.Profile__c;
            propId = prop.Id;            
        } else if (objName == 'Milestone__c') {
            Milestone__c m = [SELECT Proposal__c, Proposal__r.Profile__c FROM Milestone__c WHERE Id =: id];
            profId = m.Proposal__r.Profile__c;
            propId = m.Proposal__c;   
        } else throw new GFW_Exception ('Unexpected object in getFormInstances: ' +objName);
        // Pull all form instances for the profile 
        List<Form_Instance__c> profFIs = [
            SELECT Id, Proposal__c, Form__r.Form_Phrase_Title__r.Phrase_in_English__c, Date_submitted__c, Form__r.Sort_number__c, Language__c
            FROM Form_Instance__c
            WHERE Date_submitted__c != null
            AND (Profile__c = : profId OR Proposal__c = :propId)
            //AND Form__r.Type__c in:formTypes
            ORDER BY Proposal__r.Name, Form__r.Sort_number__c
        ];
        // Gather the appropriate form instances (include all FIs for profile review)
        for (Form_Instance__c fi : profFIs) {
            if (fi.Proposal__c == null || fi.Proposal__c == propId) fis.add(fi);
        }
        system.debug('getFormInstances: fis = ' +fis);
        return fis;
    }

    // Builds collection of form instance plus child form data, form plus child form components, and form picklists and form picklist phrases.
    public inherited sharing class FormInstanceData {
        public Form_Instance__c frmInst; // Includes child form data
        public Form__c frm; // Includes child form components
        public Form_Picklist__c[] frmPicklists; // Includes child form picklist phrases
        public Map<Id, String> orderingMap;
        public List<String> countryNames = new List<String>();

        public FormInstanceData (Id formInstanceId) {
            // Get form instance and form data
            String fdSubQuery = Utilities.buildChildSubQuery('Form_Data__c', 'Form_Data__r', null);
            frmInst = (Form_Instance__c)Utilities.fetchRecord('Form_Instance__c', formInstanceId, new List<String>{fdSubQuery});
            // Get form and form components
            String fcSubQuery = Utilities.buildChildSubQuery('Form_Component__c', 'Form_Components__r', 'ORDER BY Hierarchical_sort_num__c');
            frm = (Form__c)Utilities.fetchRecord('Form__c', frmInst.Form__c, new List<String>{fcSubQuery});
            // Get ALL form picklists and child form picklist phrases
            String fpSubQuery = Utilities.buildChildSubQuery('Form_Picklist_Phrase__c', 'Form_Picklist_Phrases__r', 'ORDER BY Sort_number__c');
            frmPicklists = (List<Form_Picklist__c>)Utilities.fetchRecords('Form_Picklist__c', null, new List<String>{fpSubQuery});
            // Fetch countries, filtering for current user's FS group
            String fsGroupName = Utilities.fsGroupNameByUser(UserInfo.getUserId());
            Country__c[] countries = [SELECT Name FROM Country__c WHERE Region__r.FS_Group__c = :fsGroupName ORDER BY Name];
            for (Country__c c : countries) countryNames.add(c.Name);

            // Form component numbering map
            orderingMap = buildCmpNumberMap(frm.Form_Components__r);
        }
    }

    // Structure representing a form data record, including value, form component id, and whether it's textarea
    public inherited sharing class FormDataInfo {
        public Id formComponentId;
        public String value;
        public Boolean isTextArea;
        public FormDataInfo (Id formComponentId, String value, Boolean isTextArea) {
            this.formComponentId = formComponentId;
            this.value = value;
            this.isTextArea = isTextArea;
        }
    }
    public inherited sharing class FormDataInfoList {
        public List<FormDataInfo> formDataInfos;
    }

    // Process form data in bulk using given list of form data info instances. 
    // Update records whose values have changed, and create new ones if necessary.
    // Delete "dupe" form data records, i.e. multiple form data on the same form component.
    public static Boolean updateFormDataBulk(String frmInstanceId, String fdInfosStr){
        try {
            system.debug('updateFormDataBulk: fdInfosStr = ' +fdInfosStr);
            FormDataInfoList fdiList = (FormDataInfoList)JSON.deserialize('{"formDataInfos":' +fdInfosStr+ '}', FormDataInfoList.class);
            FormDataInfo[] fdInfos = fdiList.formDataInfos;
            Form_Data__c[] toUpsert = new List<Form_Data__c> ();
            Form_Data__c[] toDelete = new List<Form_Data__c> ();
            //Load all form data for the form instance.
            system.debug('updateFormDataBulk: frmInstanceId = ' +frmInstanceId+ '; fdInfos = ' +fdInfos);
            String whereClause = 
                'WHERE Form_Instance__c=\'' +frmInstanceId+ '\'' +
                ' ORDER BY LastModifiedDate DESC';
            Form_Data__c[] existingFormData = (List<Form_Data__c>) Utilities.fetchRecords('Form_Data__c', whereClause, null);
            system.debug('updateFormDataBulk: existingFormData = ' +existingFormData);
            Map<Id, Form_Data__c> existingFDMap = new Map<Id, Form_Data__c>();
            // Note that if there are multiple form data for the same form component, we stash the one most recently modified and delete the others.
            for (Form_Data__c fd : existingFormData) {
                Form_Data__c fdStashed = existingFDMap.get(fd.Form_Component__c);
                // The sort order in the fetchRecords call means that we'll only delete form data for the same form component w/ earlier mod date.
                if(fdStashed == null) existingFDMap.put(fd.Form_Component__c, fd);
                else toDelete.add(fd);
            }
            system.debug('updateFormDataBulk: toDelete.size() = ' +toDelete.size());
            for (FormDataInfo fdi : fdInfos) {
                Form_Data__c fd = existingFDMap.get(fdi.formComponentId);
                Object origText = fd != null ? fd.Data_text__c : null;
                Object origTextarea = fd != null ? fd.Data_textarea__c : null;
                Form_Data__c fdPrepped = prepFormDataForUpsert(frmInstanceId, fdi.formComponentId, fdi.value, fdi.isTextarea, fd);
                if (fdi.isTextArea && fdPrepped.Data_textarea__c != origTextarea) toUpsert.add(fdPrepped);
                if (!fdi.isTextArea && fdPrepped.Data_text__c != origText) toUpsert.add(fdPrepped);
            }
            if (toUpsert.size() > 0) upsert toUpsert;
            if (toDelete.size() > 0) delete toDelete;
            return true;
        } catch (Exception e) {
            system.debug('updateFormDataBulk: ' +e);
            return false;
        }
    }

    // Update form data if existing, else build new one.
    // NOTE 5/11/2022: we're no longer updating the form data's Type__c field. When dust settles, delete that field?
    public static Boolean updateFormData(String frmInstanceId, String componentId, String value, Boolean isTextarea){
        try {
            //Load existing form data record if it exists.
            system.debug('updateFormData: value = ' +value+ '; isTextarea = ' +isTextarea);
            String whereClause = 
                'WHERE Form_Instance__c=\'' +frmInstanceId+ '\'' +
                ' AND Form_Component__c=\'' +componentId+ '\'' +
                ' ORDER BY LastModifiedDate DESC';
            Form_Data__c[] existingFormData = (List<Form_Data__c>) Utilities.fetchRecords('Form_Data__c', whereClause, null);
            system.debug('updateFormData: existingFormData = ' +existingFormData);
            // Note that if there are multiple form data for the same form component, we pick the most recently modified
            Form_Data__c frmData = prepFormDataForUpsert(
                frmInstanceId, componentId, value, isTextarea, 
                existingFormData.size()>0 ? existingFormData[0] : null
                );
            system.debug('updateFormData: frmData = ' +frmData);
            upsert frmData;
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // If form data (fd) non-null, then update with value, else build a new one
    private static Form_Data__c prepFormDataForUpsert(Id frmInstanceId, Id formCompId, Object value, Boolean isTextArea, Form_Data__c fd) {
        Form_Data__c frmData = new Form_Data__c ();
        if (fd != null) frmData = fd;
        else {
            frmData.Form_Instance__c = frmInstanceId;
            frmData.Form_Component__c = formCompId;
            Id defOwnerId = Utilities.fsDefaultRecordOwnerIdByUser(UserInfo.getUserId());
            system.debug('prepFormDataForUpsert: defOwnerId = ' +defOwnerId);
            if (defOwnerId != null) frmData.OwnerId = defOwnerId;
        }
        system.debug('prepFormDataForUpsert: frmData = ' +frmData);
        //Set the value on either the new object, or existing
        if (isTextarea) frmData.Data_textarea__c = String.valueOf(value);
        else frmData.Data_text__c = String.valueOf(value);
        return frmData;
    }

    public static boolean submitForm(String formInstanceId){
        try {
            // TODO: do we want a data-level validation here or is the UI check enough?
            Form_Instance__c fi = new Form_Instance__c(Id=formInstanceID);
            fi.Date_submitted__c = Date.today();
            update fi;       
        } catch (Exception e) {
            throw new GFW_Exception('FormInstanceController.submitForm', 'Could not submit form, please refresh and try again.', e);
        }
        return sendAckEmail(formInstanceId);
    }

    // Send ack email following submit of a form instance
    public static boolean sendAckEmail(String formInstanceId) {
        // Names of email form components in profile forms that should be included in correspondence with group
        Set<String> emailFormComponentNames = new Set<String> {'GroupEmail', 'PrimaryEmail', 'SecondaryEmail', 'Email'};
        Form_Instance__c fi = [
            SELECT Form__c, Form__r.Form_Phrase_ack_email_subject__c, Form__r.Form_Phrase_ack_email_body__c, Form__r.Type__c, 
            OwnerId, Profile__r.Community_contact_email__c, Profile__r.Language__c, Profile__r.Profile_emails__c,
            Proposal__r.Name, Advisor__r.Community_contact_email__c, Advisor__r.Contact_emails__c, Advisor__r.Language__c,
            (SELECT Form_Component__r.Name, Data_text__c FROM Form_Data__r)
            FROM Form_Instance__c
            WHERE Id = :formInstanceId
        ];
        // Only proceed if the form has non-blank ack subject/body form phrases
        Id subjectPhraseId = fi.Form__r.Form_Phrase_ack_email_subject__c;
        Id bodyPhraseId = fi.Form__r.Form_Phrase_ack_email_body__c;
        if (subjectPhraseId != null && bodyPhraseId != null) {
            // For form instances of type profile, look up emails and language in form data. Else, find them in fields in linked profile/advisor record.
            String language, emailsStr;
            if (fi.Form__r.Type__c != 'Profile') {
                language = fi.Advisor__r != null ? fi.Advisor__r.Language__c : fi.Profile__r.Language__c;
                emailsStr = fi.Advisor__r != null ? fi.Advisor__r.Contact_emails__c : fi.Profile__r.Profile_emails__c;
            } else { // Profile form
                Set<String> emails = new Set<String>();
                for (Form_Data__c fd : fi.Form_Data__r) {
                    String fcName = fd.Form_Component__r.Name;
                    if (fcName == 'PreferredLanguage' || fcName == 'Language') language = fd.Data_text__c;
                    if (emailFormComponentNames.contains(fcName) && fd.Data_text__c != null) emails.add(fd.Data_text__c);
                }
                // Include community contact email
                String ccEmail = fi.Advisor__r != null ? fi.Advisor__r.Community_contact_email__c : fi.Profile__r.Community_contact_email__c;
                if (ccEmail != null) emails.add(ccEmail);
                emailsStr = String.join(new List<String> (emails), ',');
            }
            // Default language to English
            if (language == null) language = 'English';
            // Fetch body and subject phrase translations
            Set<Id> phraseIds = new Set<Id> {subjectPhraseId, bodyPhraseId};
            Form_Phrase_Translation__c[] translations = [
                SELECT Text__c, Language__c, Form_Phrase__c
                FROM Form_Phrase_Translation__c
                WHERE Form_Phrase__c IN : phraseIds
            ];
            String subjectInEnglish, subjectInLang, bodyInEnglish, bodyInLang;
            Map<String, String> bodyTransByLanguage = new Map<String, String>();
            Map<String, String> subjTransByLanguage = new Map<String, String>();
            for (Form_Phrase_Translation__c trans : translations) {
                if (trans.Form_Phrase__c == subjectPhraseId) {
                    if (trans.Language__c == language) subjectInLang = trans.Text__c;
                    if (trans.Language__c == 'English') subjectInEnglish = trans.Text__c;
                }
                if (trans.Form_Phrase__c == bodyPhraseId) {
                    if (trans.Language__c == language) bodyInLang = trans.Text__c;
                    if (trans.Language__c == 'English') bodyInEnglish = trans.Text__c;
                }
            }
            String subject = subjectInLang != null ? subjectInLang : subjectInEnglish;
            // Include prop # (if any) in email subject
            if (fi.Proposal__r.Name != null) subject = fi.Proposal__r.Name +': '+ subject;
            String body = bodyInLang != null ? bodyInLang : bodyInEnglish;
            // Get from address for ack email
            FS_Group_Settings__mdt fsGroup = Utilities.fsGroupOfUser(fi.OwnerId);
            String fromEmail = fsGroup != null ? fsGroup.From_email_address__c : null;
            // Alert im@ if fi owner not in a group
            if (fromEmail == null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ Utilities.EmailAddressIM });
                mail.setReplyTo(Utilities.EmailAddressIM);
                mail.setSenderDisplayName('FSDB Community form instance submit error');
                mail.setSubject('FSDB error: Form instance owner\'s FS group blank or blank \'from\' email');
                mail.setPlainTextBody('Form Instance id: ' +formInstanceId);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
                return false;
            }
            List < OrgWideEmailAddress > owea = [SELECT ID FROM OrgWideEmailAddress WHERE Address =:fromEmail]; 
            Id fromEmailId = owea.size() > 0 ? owea[0].Id : null;
            // Send email
            if (emailsStr != null && subject != null && body != null && fromEmailId != null) {
                system.debug('sendAckEmail: emailsStr = ' +emailsStr+ '; subject = ' +subject+ '; body = ' +body);
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setOrgWideEmailAddressId(fromEmailId);
                mail.setCharset('utf-8');
                mail.setReplyTo(fromEmail);
                mail.setToAddresses(emailsStr.split(','));
                mail.setSubject(subject);
                mail.setHtmlBody(body);
                system.debug('sendAckEmail: mail: ');
                system.debug(mail);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                return true;
            }
        } 
        return false;
    }
    
}