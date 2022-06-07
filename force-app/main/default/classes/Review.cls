//Wrapper class that defines the contents and logic for a review of a Proposal or Milestone
public virtual with sharing class Review {

    public String type;  //Either Milestone or Proposal (not implementing Profile)
    public Id reviewFormId;
    public String reviewGuideURL;
    public String reviewerName;
    public Boolean isComplete = false;
    public List < FormComponent > formComponents;
    public GM_Data__c linkedGMData;
    public Proposal__c linkedProposal;
    public Milestone__c linkedMilestone;
    public Profile__c linkedProfile;
    public Map < String, Map < String, IndicatorAssign > > indicatorAssignMap; //Outer map is of the outcome Type, inner map is indicator ID to indicator wrapper
    public Map < String, List < ClassificationAssign > > classificationAssignMap;  //Gotta have a wrapper class for Classification Adding so i can pull through the classification name
    public List < PortfolioAssign > portfolioAssignments;  //Wrapper to pull in Portfolio Join info


    public with sharing class FormComponent {
        public Id id;
        public Boolean isActive;
        public Boolean enableBeforeSubmission;
        public String fieldName;
        public String helpText;
        public String indicatorOutcomeType;
        public String joinObjectName;
        public String joinObjectType;
        public String label;
        public String dataType;
        public String jsonSelectOptions; //stringified JSON with the picklist values for InputSelect data types
        public String objectName;
        public String placeholderText;
        public Boolean isRequired;
        public Id reviewFormId;
        public Decimal sortNumber;

        // Values
        public Id recordId;
        public String stringValue;
        public Boolean booleanValue;
        public Decimal numberValue;
        public Id lookupValue;

    }

    public with sharing class ClassificationAssign {
        public ID id;
        public ID classificationId;
        public String classificationName;
        public String categoryName;
        public ID proposalId;
        public ID profileId;
        public ID categoryId;
        public Integer rank;

        public ClassificationAssign (ID id, ID classID, String classification, String categoryName, ID proposal, ID profile, ID category, Integer rank) {
            this.id = id;
            this.classificationId = classID;
            this.classificationName = classification;
            this.categoryName = categoryName;
            this.profileId = profile;
            this.proposalId = proposal;
            this.categoryId = category;
            this.rank = rank;
        }

    }

    public with sharing class PortfolioAssign {
        public ID id;
        public ID portfolioId;
        public String portfolioName;
        public ID proposalId;
        public ID profileId;
        public Boolean isAssigned = false;

        public PortfolioAssign (ID id, ID portfolio, ID proposal, ID profile, String name) {
            this.id = id;
            this.portfolioId = portfolio;
            this.proposalId = proposal;
            this.profileId = profile;
            this.portfolioName = name;
            if (this.id!=null) {
                this.isAssigned = true;
            }
        }
    }

    public with sharing class IndicatorAssign {
        public ID id;
        public ID indicatorId;
        public String indicatorName;
        public ID gmDataId;
        public String outcomeType;
        public String code;
        public String description;
        public String impactArea;
        public String notes;
        public String comment;
        public Integer quantity;
        public Boolean requiresNumber;
        public Boolean requiresComment;

        public IndicatorAssign (ID id, Indicator__c indicator, ID gmDataId, String comment, Integer quantity) {
            this.id = id;
            this.indicatorId = indicator.Id;
            this.gmDataId = gmDataId;
            this.outcomeType = indicator.Outcome_type__c;
            this.code = indicator.Code__c;
            this.description = indicator.Description__c;
            this.notes = indicator.Notes__c;
            this.comment = comment;
            this.quantity = quantity;
            this.requiresNumber = indicator.Requires_number__c;
            this.requiresComment = indicator.Requires_comment__c;
        }
    }

    // Empty constructor; construction is handled in classes that extend review (Assessment.cls)
    public Review() {

    }

    protected void loadMilestone(Id milestoneId) {
        List < String > fieldNames = getAllMilestoneFields();

        String query =
        ' SELECT ' +
            String.join( fieldNames, ',' ) + ', Proposal__r.Name, Proposal__r.Profile__r.Name, Proposal__r.Profile__c' +
        ' FROM ' +
            ' Milestone__c ' +
        ' WHERE ' +
            ' Id =:milestoneId'
        ;

        List < Milestone__c > reportList = Database.query( query );

        if (reportList.size()>0) {
            this.linkedMilestone = reportList[0];
            if (this.linkedMilestone.Date_reviewed__c!=null) {
                this.isComplete = true;
            }
            loadMilestoneGMData(reportList[0].Id);
        }
    }

    protected void loadProposal(Id proposalId) {
        List < String > fieldNames = getAllProposalFields();

        String query =
        ' SELECT ' +
            String.join( fieldNames, ',' ) + ', Decline_reason__r.Name, Profile__r.Name' +
        ' FROM ' +
            ' Proposal__c ' +
        ' WHERE ' +
            ' Id =:proposalId'
        ;

        List < Proposal__c > propList = Database.query( query );

        System.debug('propList.size(): '+propList.size());
        if (propList.size()>0) {
            this.linkedProposal = propList[0];
            System.debug('this.linkedProposal.Date_review_completed__c: '+this.linkedProposal.Date_review_completed__c);
            if (this.linkedProposal.Date_review_completed__c!=null) {
                this.isComplete = true;
                System.debug('this.isComplete: '+this.isComplete);
            }
            this.loadProposalGMData(propList[0].Id);
        }
    }

    protected void loadProposalGMData(Id proposalId) {
        List < String > fieldNames = getAllGMDataFields();

        // Logic for GM Record ID: IF there is a direct lookup on Proposal__c, use it.  Otherwise find the GM Data based on a lookup from the GMData to the Proposal AND the absence of a Milestone

        String query;
        if (this.linkedProposal.GM_Data__c!=null) {
            String gmDataId = this.linkedProposal.GM_Data__c;
            query = 
            ' SELECT ' +
                String.join( fieldNames, ',' ) + 
            ' FROM ' +
                ' GM_Data__c ' +
            ' WHERE ' +
                ' Id =:gmDataId' + 
            ' LIMIT 1 '
            ;
        } else {
            query =
            ' SELECT ' +
                String.join( fieldNames, ',' ) + 
            ' FROM ' +
                ' GM_Data__c ' +
            ' WHERE ' +
                ' Proposal__c =:proposalId' + 
            ' AND ' +
                ' Milestone__c = null ' +
            ' LIMIT 1 '
            ;
        }

        List < GM_Data__c > gmDataList = Database.query( query );

        if (gmDataList.size()>0) {
            this.linkedGMData = gmDataList[0];
        }

    }

    protected void loadProfile(Id profileId) {
        List < String > fieldNames = getAllProfileFields();

        String query =
        ' SELECT ' +
            String.join( fieldNames, ',' ) + ', Account__r.Name ' + 
        ' FROM ' +
            ' Profile__c ' +
        ' WHERE ' +
            ' Id =:profileId'
        ;

        List < Profile__c > profList = Database.query( query );

        System.debug('profList.size(): '+profList.size());
        if (profList.size()>0) {
            this.linkedProfile = profList[0];
            if (this.linkedProfile.Date_review_completed__c!=null) {
                this.isComplete = true;
            }
        }
    }

    protected void loadReviewFormComponents () {
        Review_Form__c form = [
            SELECT Id, Name, Num_components__c, Review_guide_URL__c, 
                (SELECT ID, Active__c, Enable_before_form_submitted__c, Field_name__c, Help_text__c, Indicator_outcome_type__c, Join_object_name__c, Join_object_type__c, Label__c, Lightning_component_name__c, Object_name__c, Placeholder__c, Required__c, Review_Form__c, Sort_number__c 
                    FROM Review_Form_Components__r 
                    WHERE Active__c=true 
                    ORDER BY Sort_number__c ASC) 
                FROM Review_Form__c WHERE ID=:this.reviewFormId];

                this.reviewGuideURL = form.Review_guide_URL__c;

                System.debug('review form: '+this.reviewFormId);

        for (Review_Form_Component__c rfc: form.Review_Form_Components__r) {
            FormComponent cmp = new FormComponent();
            cmp.id = rfc.Id;
            cmp.isActive = rfc.Active__c;
            cmp.enableBeforeSubmission = rfc.Enable_before_form_submitted__c;
            cmp.fieldName = rfc.Field_name__c;
            cmp.helpText = rfc.Help_text__c;
            cmp.indicatorOutcomeType = rfc.Indicator_outcome_type__c;
            cmp.joinObjectName = rfc.Join_object_name__c;
            cmp.joinObjectType = rfc.Join_object_type__c;
            cmp.label = rfc.Label__c;
            cmp.dataType = rfc.Lightning_component_name__c;
            cmp.objectName = rfc.Object_name__c;
            cmp.placeholderText = rfc.Placeholder__c;
            cmp.isRequired = rfc.Required__c;
            cmp.reviewFormId = rfc.Review_Form__c;
            cmp.sortNumber = rfc.Sort_number__c;
            this.formComponents.add(cmp);
        }
    }



    protected void loadIndicatorAssigns() {
        if (this.linkedGMData!=null && this.linkedGMData.Id!=null) {
            // Load existing Indicator Assigns
            List < Indicator_Assign__c > existingIndAssigns = [SELECT ID, Indicator__c, GM_Data__c, Quantity__c, Comment__c FROM Indicator_Assign__c WHERE GM_Data__c=:this.linkedGMData.Id];
            // convert to a map for easy referencing
            Map < String, Indicator_Assign__c > existingAssignsMap = new Map < String, Indicator_Assign__c >();
            for (Indicator_Assign__c ind: existingIndAssigns) {
                existingAssignsMap.put(ind.Indicator__c, ind);
            }

            // Query for all Indicators WHERE Type == Indicator_outcome_type__c given on any of the form components
            List < String > indicatorTypes = new List < String >();
            for (FormComponent rfc: this.formComponents) {
                if (rfc.dataType=='IndicatorGroup' && rfc.indicatorOutcomeType!=null) {
                    indicatorTypes.add(rfc.indicatorOutcomeType);
                }
            }

            // Get a list of all relevant Indicator Records
            List < Indicator__c > allRelevantIndicators = [SELECT ID, Name, Outcome_type__c, Code__c, Description__c, Notes__c, Requires_number__c, Requires_comment__c FROM Indicator__c WHERE Active__c=true AND Outcome_type__c in:indicatorTypes];

            // create the full map of existing and empty Indicator Assigns
            for (String outcomeType : indicatorTypes) {
                // create the map of indicator assigns for this outcome type
                Map < String, IndicatorAssign > indAssignMap = new Map < String, IndicatorAssign >();
                for (Indicator__c ind: allRelevantIndicators) {
                    if (ind.Outcome_type__c==outcomeType) {
                        if (existingAssignsMap.containsKey(ind.Id)) {
                            Indicator_Assign__c existingInd = existingAssignsMap.get(ind.Id);
                            IndicatorAssign indicatorWrapper = new IndicatorAssign (existingInd.Id, ind, existingInd.GM_Data__c, existingInd.Comment__c, Integer.valueOf(existingInd.Quantity__c));
                            indAssignMap.put(ind.Id, indicatorWrapper);
                        } else {
                            IndicatorAssign indicatorWrapper = new IndicatorAssign (null, ind, this.linkedGMData.Id, null, null);
                            indAssignMap.put(ind.Id, indicatorWrapper);
                        }
                    }
                }

                this.indicatorAssignMap.put(outcomeType, indAssignMap);
            }
        }
    }

    protected void loadClassificationAssigns() {

        // Get all active Classifications
        List < Classification__c > allClassifications = [SELECT ID, Classification_Category__c, Name, Definition__c,GM_ExternalID__c, Name_with_prefix__c, Notes__c, Type__c, Classification_Category__r.Initials__c FROM Classification__c WHERE Active__c=true ORDER BY Name_with_prefix__c];

        if (this.type== 'Proposal' && this.linkedProposal!=null && this.linkedProposal.Id!=null) {
            // Get all existing Classification Assigns for this proposal
            List < Classification_Assign__c > assigns = [SELECT ID, Classification__c, Classification_category__c, Proposal__c, Rank__c FROM Classification_Assign__c WHERE Proposal__c=:this.linkedProposal.Id];
            // Convert to a map indexed by the Classification ID for easy reference
            Map < String, Classification_Assign__c > assignedClassificationsMap = new Map < String, Classification_Assign__c >();
            for (Classification_Assign__c ca: assigns) {
                assignedClassificationsMap.put(ca.Classification__c, ca);
            }
            
            // Now create the full map of classification wrapper classes with assigned and unassigned
            for (Classification__c c: allClassifications) {
                List < ClassificationAssign > currentList;
                if (this.classificationAssignMap.containsKey(c.Type__c)) {
                    currentList = this.classificationAssignMap.get(c.Type__c);
                } else {
                    currentList = new List < ClassificationAssign >();
                }

                if (assignedClassificationsMap.containsKey(c.Id)) {
                    Classification_Assign__c cSobj = assignedClassificationsMap.get(c.Id);
                    ClassificationAssign classAssign = new ClassificationAssign(cSobj.Id, c.Id, c.Name_with_prefix__c, c.Classification_Category__r.Initials__c, cSobj.Proposal__c, null,  c.Classification_Category__c, Integer.valueOf(cSobj.Rank__c));
                    currentList.add(classAssign);
                } else {
                    ClassificationAssign classAssign = new ClassificationAssign(null, c.Id, c.Name_with_prefix__c, c.Classification_Category__r.Initials__c, this.linkedProposal.Id, null, c.Classification_Category__c, null);
                    currentList.add(classAssign);
                }
                this.classificationAssignMap.put(c.Type__c, currentList);
            }
        } else if (this.type=='Profile' && this.linkedProfile!=null && this.linkedProfile.Id!=null) {
            //Get all existing Classification Assigns for this profile
            List < Classification_Profile_Assign__c > assigns = [SELECT ID, Classification__c, Classification_category__c, Profile__c, Rank__c FROM Classification_Profile_Assign__c WHERE Profile__c=:this.linkedProfile.Id];
            // Convert to a map indexed by the Classification ID for easy reference
            Map < String, Classification_Profile_Assign__c > assignedClassificationsMap = new Map < String, Classification_Profile_Assign__c >();
            for (Classification_Profile_Assign__c ca: assigns) {
                assignedClassificationsMap.put(ca.Classification__c, ca);
            }
            
            // Now create the full map of classification wrapper classes with assigned and unassigned
            for (Classification__c c: allClassifications) {
                List < ClassificationAssign > currentList;
                if (this.classificationAssignMap.containsKey(c.Type__c)) {
                    currentList = this.classificationAssignMap.get(c.Type__c);
                } else {
                    currentList = new List < ClassificationAssign >();
                }

                if (assignedClassificationsMap.containsKey(c.Id)) {
                    Classification_Profile_Assign__c cSobj = assignedClassificationsMap.get(c.Id);
                    ClassificationAssign classAssign = new ClassificationAssign(cSobj.Id, c.Id, c.Name_with_prefix__c, c.Classification_Category__r.Initials__c, null, cSobj.Profile__c,  c.Classification_Category__c, Integer.valueOf(cSobj.Rank__c));
                    currentList.add(classAssign);
                } else {
                    ClassificationAssign classAssign = new ClassificationAssign(null, c.Id, c.Name_with_prefix__c, c.Classification_Category__r.Initials__c, null, this.linkedProfile.Id, c.Classification_Category__c, null);
                    currentList.add(classAssign);
                }
                this.classificationAssignMap.put(c.Type__c, currentList);
            }
        }
    }

    protected void loadPortfolioAssigns() {
        System.debug('loadPortfolioAssigns');

        // Only loaded if this is a proposal
        if (this.type == 'Proposal') {
            // get all the possible portfolios  
            List < Portfolio__c > priorityPortfolios = [
                SELECT Id, Type__c, Name 
                FROM Portfolio__c 
                WHERE (Type__c = 'Priority' OR Type__c = 'Advisor assignments')
                AND Active__c = true
                ORDER BY Name
            ];

            // get existing assigns
            List < Portfolio_Assignment__c > assignedPortfolios = [
                SELECT Id, Portfolio__c, Proposal__c
                FROM Portfolio_Assignment__c
                WHERE Portfolio__c IN :priorityPortfolios
                AND Proposal__c =:this.linkedProposal.Id
            ];
            // put into a map indexed by Portfolio ID
            Map < ID, Portfolio_Assignment__c > assignmentsByPortfolioId = new Map < ID, Portfolio_Assignment__c >();
            for (Portfolio_Assignment__c pa: assignedPortfolios) {
                assignmentsByPortfolioId.put(pa.Portfolio__c, pa);
            }

            // make a final list of the wrapper object
            for (Portfolio__c p: priorityPortfolios) {
                if (assignmentsByPortfolioId.containsKey(p.Id)) {
                    Portfolio_Assignment__c pa = assignmentsByPortfolioId.get(p.Id);
                    PortfolioAssign paWrapper = new PortfolioAssign(pa.Id, p.Id, this.linkedProposal.Id, null, p.Name);
                    this.portfolioAssignments.add(paWrapper);
                } else {
                    System.debug('add this :'+p);
                    PortfolioAssign paWrapper = new PortfolioAssign(null, p.Id, this.linkedProposal.Id, null, p.Name);
                    this.portfolioAssignments.add(paWrapper);
                    System.debug('paWrapper :'+paWrapper);
                }
            }
        }
        
    }

    protected void loadProfilePortfolioAssigns() {
        System.debug('loadProfilePortfolioAssigns');

        // Only loaded if this is a profile
        if (this.type == 'Profile') {
            // get all the possible portfolios  
            List < Portfolio__c > priorityPortfolios = [
                SELECT Id, Type__c, Name 
                FROM Portfolio__c 
                WHERE Type__c = 'Priority'
                AND Active__c = true
                ORDER BY Name
            ];

            // get existing assigns
            List < Portfolio_Profile_Assign__c > assignedPortfolios = [
                SELECT Id, Portfolio__c, Profile__c
                FROM Portfolio_Profile_Assign__c
                WHERE Portfolio__c IN :priorityPortfolios
                AND Profile__c =:this.linkedProfile.Id
            ];
            // put into a map indexed by Portfolio ID
            Map < ID, Portfolio_Profile_Assign__c > assignmentsByPortfolioId = new Map < ID, Portfolio_Profile_Assign__c >();
            for (Portfolio_Profile_Assign__c pa: assignedPortfolios) {
                assignmentsByPortfolioId.put(pa.Portfolio__c, pa);
            }

            // make a final list of the wrapper object
            for (Portfolio__c p: priorityPortfolios) {
                if (assignmentsByPortfolioId.containsKey(p.Id)) {
                    Portfolio_Profile_Assign__c pa = assignmentsByPortfolioId.get(p.Id);
                    PortfolioAssign paWrapper = new PortfolioAssign(pa.Id, p.Id, null, this.linkedProfile.Id, p.Name);
                    this.portfolioAssignments.add(paWrapper);
                } else {
                    System.debug('add this :'+p);
                    PortfolioAssign paWrapper = new PortfolioAssign(null, p.Id, null, this.linkedProfile.Id, p.Name);
                    this.portfolioAssignments.add(paWrapper);
                    System.debug('paWrapper :'+paWrapper);
                }
            }
        }
        
    }

    protected void loadMilestoneGMData(Id milestoneId) {
        List < String > fieldNames = getAllGMDataFields();

        // Logic for GM Record ID: IF there is a direct lookup on Milestone__c, use it.  Otherwise find the GM Data based on a lookup from the GM Data record to the Milestone. 
        String query;
        if (this.linkedMilestone.GM_Data__c!=null) {
            System.debug('In direct lookup');
            String gmDataId = this.linkedMilestone.GM_Data__c;
            query = 
            ' SELECT ' +
                String.join( fieldNames, ',' ) + 
            ' FROM ' +
                ' GM_Data__c ' +
            ' WHERE ' +
                ' Id =:gmDataId' + 
            ' LIMIT 1 '
            ;
        } else {
            System.debug('In related lookup');
            query =
            ' SELECT ' +
                String.join( fieldNames, ',' ) + 
            ' FROM ' +
                ' GM_Data__c ' +
            ' WHERE ' +
                ' Milestone__c =:milestoneId' + 
            ' LIMIT 1 '
            ;
        }

        List < GM_Data__c > gmDataList = Database.query( query );

        if (gmDataList.size()>0) {
            this.linkedGMData = gmDataList[0];
        }

    }

    // TODO: refactor/simplify if possible
    protected void finishFormComponentBuild() {

        // Outer Map is indexed by object, inner map is indexed by field, with values that are stringified JSON representing the picklist values in a SelectOption format
        Map < String, Map < String, String > > picklistValuesByObjAndField = getPickListValsByObjectAndField();

        // now that all the data is loaded, we can fill in the form components with the specific object ID they'll be updating
        for (FormComponent fc: this.formComponents) {
            // Is it a linked object field, or a join object field -- linked objects are handled with the indicator/classsification maps
            if (fc.joinObjectName==null && fc.fieldName!=null) {
                // fill in related object info
                if (fc.objectName=='GM_Data__c' && this.linkedGMData!=null) {
                    fc.recordId = this.linkedGMData.Id;
                    Map < String, String > picklistValsByField = picklistValuesByObjAndField.get(fc.objectName);
                    // get existing value, if any
                    if (fc.dataType=='InputSelect' || fc.dataType=='InputTextarea' || fc.dataType=='InputText') {
                        fc.stringValue = (String)this.linkedGMData.get(fc.fieldName);
                        if (fc.dataType=='InputSelect') {
                            fc.jsonSelectOptions = picklistValsByField.get(fc.fieldName.toLowerCase());
                        }
                    } else if (fc.dataType=='InputSelectLookup') {
                        fc.lookupValue = (Id)this.linkedGMData.get(fc.fieldName);
                    } else if (fc.dataType=='InputNumber') {
                        fc.numberValue = (Decimal)this.linkedGMData.get(fc.fieldName);
                    } else if (fc.dataType=='InputCheckbox') {
                        fc.booleanValue = (Boolean)this.linkedGMData.get(fc.fieldName);
                    }
                } else if (fc.objectName=='Milestone__c') {
                    fc.recordId = this.linkedMilestone.Id;
                    Map < String, String > picklistValsByField = picklistValuesByObjAndField.get(fc.objectName);
                    if (fc.dataType=='InputSelect' || fc.dataType=='InputTextarea' || fc.dataType=='InputText') {
                        fc.stringValue = (String)this.linkedMilestone.get(fc.fieldName);
                        if (fc.dataType=='InputSelect') {
                            fc.jsonSelectOptions = picklistValsByField.get(fc.fieldName.toLowerCase());
                        }
                    } else if (fc.dataType=='InputSelectLookup') {
                        fc.lookupValue = (Id)this.linkedMilestone.get(fc.fieldName);
                    }  else if (fc.dataType=='InputNumber') {
                        fc.numberValue = (Decimal)this.linkedMilestone.get(fc.fieldName);
                    } else if (fc.dataType=='InputCheckbox') {
                        fc.booleanValue = (Boolean)this.linkedMilestone.get(fc.fieldName);
                    }
                } else if (fc.objectName=='Proposal__c') {
                    Map < String, String > picklistValsByField = picklistValuesByObjAndField.get(fc.objectName);
                    fc.recordId = this.linkedProposal.Id;
                    if (fc.dataType=='InputSelect' || fc.dataType=='InputTextarea' || fc.dataType=='InputText') {
                        fc.stringValue = (String)this.linkedProposal.get(fc.fieldName);
                        if (fc.dataType=='InputSelect') {
                            fc.jsonSelectOptions = picklistValsByField.get(fc.fieldName.toLowerCase());
                        }
                    } else if (fc.dataType=='InputNumber') {
                        fc.numberValue = (Decimal)this.linkedProposal.get(fc.fieldName);
                    } else if (fc.dataType=='InputCheckbox') {
                        fc.booleanValue = (Boolean)this.linkedProposal.get(fc.fieldName);
                    } else if (fc.dataType=='InputSelectLookup' && fc.fieldName=='Decline_reason__c') { // Decline Reason is a lookup, but we present it as a picklist, since it's not clear to all users what they would search for
                        List < Decline_reason__c > proposalDeclineReasons = [SELECT Id, Name, For_proposal__c FROM Decline_reason__c WHERE Active__c = true AND For_proposal__c = true ORDER BY Name Asc];
                        List < Map<String, String> > picklistSelectOptions = new List < Map<String, String> >();
                        for (Decline_reason__c dr: proposalDeclineReasons) {
                            Map<String, String> selectOptions = new Map<String, String>{
                                'value' => dr.Id,
                                'label' => dr.Name
                            };
                            picklistSelectOptions.add(selectOptions);
                        }
                        String jsonPickListValues = JSON.serialize(picklistSelectOptions);
                        fc.jsonSelectOptions = jsonPickListValues;
                        // fill in the selected value, if any
                        fc.lookupValue = (Id)this.linkedProposal.get(fc.fieldName);
                        fc.stringValue = (Id)this.linkedProposal.get(fc.fieldName);
                    }
                } else if (fc.objectName=='Profile__c') {
                    Map < String, String > picklistValsByField = picklistValuesByObjAndField.get(fc.objectName);
                    fc.recordId = this.linkedProfile.Id;
                    if (fc.dataType=='InputSelect' || fc.dataType=='InputTextarea' || fc.dataType=='InputText') {
                        fc.stringValue = (String)this.linkedProfile.get(fc.fieldName);
                        if (fc.dataType=='InputSelect') {
                            fc.jsonSelectOptions = picklistValsByField.get(fc.fieldName.toLowerCase());
                        }
                    } else if (fc.dataType=='InputNumber') {
                        fc.numberValue = (Decimal)this.linkedProfile.get(fc.fieldName);
                    } else if (fc.dataType=='InputCheckbox') {
                        fc.booleanValue = (Boolean)this.linkedProfile.get(fc.fieldName);
                    } else if (fc.dataType=='InputSelectLookup' && fc.fieldName=='Decline_reason__c') { // Decline Reason is a lookup, but we present it as a picklist, since it's not clear to all users what they would search for
                        List < Decline_reason__c > profileDeclineReasons = [SELECT Id, Name, For_profile__c FROM Decline_reason__c WHERE Active__c = true AND For_profile__c = true ORDER BY Name Asc];
                        List < Map<String, String> > picklistSelectOptions = new List < Map<String, String> >();
                        for (Decline_reason__c dr: profileDeclineReasons) {
                            Map<String, String> selectOptions = new Map<String, String>{
                                'value' => dr.Id,
                                'label' => dr.Name
                            };
                            picklistSelectOptions.add(selectOptions);
                        }
                        String jsonPickListValues = JSON.serialize(picklistSelectOptions);
                        fc.jsonSelectOptions = jsonPickListValues;
                        // fill in the selected value, if any
                        fc.lookupValue = (Id)this.linkedProfile.get(fc.fieldName);
                        fc.stringValue = (Id)this.linkedProfile.get(fc.fieldName);
                    }
                }              
            }

        }
    }


    private Map < String, Map < String, String > >  getPickListValsByObjectAndField () {
        // Get a list of all the picklist fields and get the picklist values
        Set < String > sObjectsList = new Set < String >();
        for (FormComponent fc: this.formComponents) {
            if (fc.objectName!=null) {
                sObjectsList.add(fc.objectName);
            }
        }
        Map < String, Map < String, String > > picklistValuesByObjAndField = new Map < String, Map < String, String > >();
        for (String sobj: sObjectsList) {
            Map < String, String > stringifiedPicklistValsByField = new Map < String, String >(); //map to hold results for this object
            System.debug('the sobj we are getting picklists for: '+sobj);
            Map<String, List<String>> picklistVals = Utilities.getPicklists(sobj);
            // Loop through each field and convert picklist values into a JSON selectlist format
            for (String fieldName : picklistVals.keySet()) {
                List < String > picklistvalues = picklistVals.get(fieldName);
                List < Map<String, String> > picklistSelectOptions = new List < Map<String, String> >();
                for (String pickVal: picklistvalues) {
                    Map<String, String> selectOptions = new Map<String, String>{
                        'value' => pickVal,
                        'label' => pickVal
                    };
                    picklistSelectOptions.add(selectOptions);
                }
                String jsonPickListValues = JSON.serialize(picklistSelectOptions);
                stringifiedPicklistValsByField.put(fieldName, jsonPickListValues);
            }
            picklistValuesByObjAndField.put(sobj, stringifiedPicklistValsByField);
        }
        System.debug('picklistValuesByObjAndField: '+picklistValuesByObjAndField);
        return picklistValuesByObjAndField;
    }

    public static List < String > getAllMilestoneFields () {
		DescribeSObjectResult describeResult = Milestone__c.getSObjectType().getDescribe();
		List<String> fieldNames = new List<String>( describeResult.fields.getMap().keySet() );
		return fieldNames;
	}

    public static List < String > getAllProposalFields () {
		DescribeSObjectResult describeResult = Proposal__c.getSObjectType().getDescribe();
		List<String> fieldNames = new List<String>( describeResult.fields.getMap().keySet() );
        System.debug('proposal fields: '+fieldNames);
        fieldNames.add('Account__r.Name');
		return fieldNames;
    }

    public static List < String > getAllGMDataFields () {
		DescribeSObjectResult describeResult = GM_Data__c.getSObjectType().getDescribe();
		List<String> fieldNames = new List<String>( describeResult.fields.getMap().keySet() );
		return fieldNames;
	}

    public static List < String > getAllProfileFields () {
		DescribeSObjectResult describeResult = Profile__c.getSObjectType().getDescribe();
		List<String> fieldNames = new List<String>( describeResult.fields.getMap().keySet() );
		return fieldNames;
	}

}