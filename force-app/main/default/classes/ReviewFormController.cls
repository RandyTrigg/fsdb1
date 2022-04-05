public with sharing class ReviewFormController {
    
    @AuraEnabled //Do not cache
    public static String getInternalReview(String recordId) {
        InternalReview rev = new InternalReview(recordId);
        return JSON.serialize(rev);
    }    

    @AuraEnabled
    public static void updateNumber (String objectType, String objectId, String fieldName, Decimal value){

        try {
            sObject sObj = Schema.getGlobalDescribe().get(objectType).newSObject() ;
            sobj.Id = objectId;
            sobj.put(fieldName, value);
            update sobj;
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.updateNumber', 'Could not update field value, please refresh and try again.', e);
        }
    }
    
    @AuraEnabled
    public static void updateTextPickOrLookup(String objectType, String objectId, String fieldName, String value){

        try {
            sObject sObj = Schema.getGlobalDescribe().get(objectType).newSObject() ;
            sobj.Id = objectId;
            sobj.put(fieldName, value);
            update sobj;
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.updateTextPickOrLookup', 'Could not update field value, please refresh and try again.', e);
        }
    }

    @AuraEnabled
    public static void updateBoolean(String objectType, String objectId, String fieldName, Boolean value){
        try {
            sObject sObj = Schema.getGlobalDescribe().get(objectType).newSObject() ;
            sobj.Id = objectId;
            sobj.put(fieldName, value);
            update sobj;
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.updateBoolean', 'Could not update field value, please refresh and try again.', e);
        }
    }

    @AuraEnabled
    public static void addClassificationJoin(String objectName, String recordId, List < String > classificationIds){
        try {
            if (objectName=='Proposal') {
                List < Classification_Assign__c > newAssigns = new List < Classification_Assign__c >();
                for (String cId: classificationIds) {
                    Classification_Assign__c ca = new Classification_Assign__c(
                        Proposal__c = recordId,
                        Classification__c = cId
                    );
                    newAssigns.add(ca);
                }
                insert newAssigns;
            } else if (objectName=='Profile') {
                List < Classification_Profile_Assign__c > newAssigns = new List < Classification_Profile_Assign__c >();
                for (String cId: classificationIds) {
                    Classification_Profile_Assign__c ca = new Classification_Profile_Assign__c(
                        Profile__c = recordId,
                        Classification__c = cId
                    );
                    newAssigns.add(ca);
                }
                insert newAssigns;
            }
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.addClassificationJoin', 'Could not update classifications, please refresh and try again.', e);
        }
    }

    @AuraEnabled
    public static void removeClassificationJoin(String objectName, String recordId, List < String > classificationIds){
        try {
            if (objectName=='Proposal') {
                List < Classification_Assign__c > cAssigns = [SELECT ID FROM Classification_Assign__c WHERE Proposal__c=:recordId AND Classification__c in:classificationIds];
                delete cAssigns;
            } else if (objectName=='Profile') {
                List < Classification_Profile_Assign__c > cAssigns = [SELECT ID FROM Classification_Profile_Assign__c WHERE Profile__c=:recordId AND Classification__c in:classificationIds];
                delete cAssigns;
            }
            
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.removeClassificationJoin', 'Could not remove classifications, please refresh and try again.', e);
        }
    }

    @AuraEnabled
    public static void addPortfolioAssign(String objectName, String recordId, List < String > portfolioIds){
        try {
            if (objectName=='Proposal') {
                List < Portfolio_Assignment__c > newAssigns = new List < Portfolio_Assignment__c >();
                for (String pId: portfolioIds) {
                    Portfolio_Assignment__c pa = new Portfolio_Assignment__c(
                        Proposal__c = recordId,
                        Portfolio__c = pId
                    );
                    newAssigns.add(pa);
                }
                insert newAssigns;
            } else if (objectName=='Profile') {
                List < Portfolio_Profile_Assign__c > newAssigns = new List < Portfolio_Profile_Assign__c >();
                for (String pId: portfolioIds) {
                    Portfolio_Profile_Assign__c pa = new Portfolio_Profile_Assign__c(
                        Profile__c = recordId,
                        Portfolio__c = pId
                    );
                    newAssigns.add(pa);
                }
                insert newAssigns;
            }
            
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.addPortfolioAssign', 'Could not update portfolio assignments, please refresh and try again.', e);
        }
    }

    @AuraEnabled
    public static void removePortfolioAssign(String objectName, String recordId, List < String > portfolioIds){
        try {
            if (objectName=='Proposal') {
                List < Portfolio_Assignment__c > pAssigns = [SELECT ID FROM Portfolio_Assignment__c WHERE Proposal__c=:recordId AND Portfolio__c in:portfolioIds];
                delete pAssigns;
            } else if (objectName=='Profile') {
                List < Portfolio_Profile_Assign__c > pAssigns = [SELECT ID FROM Portfolio_Profile_Assign__c WHERE Profile__c=:recordId AND Portfolio__c in:portfolioIds];
                delete pAssigns;
            }
            
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.removePortfolioAssign', 'Could not remove portfolio assignments, please refresh and try again.', e);
        }
    }
    
    @AuraEnabled
    public static void addIndicatorAssign (String gmDataId, String indicatorId, Integer quantity, String comments){
        try {
            Indicator_Assign__c indAssign = new Indicator_Assign__c (
                GM_Data__c = gmDataId,
                Indicator__c = indicatorId,
                Quantity__c = quantity,
                Comment__c = comments
            );
            insert indAssign;
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.addIndicatorAssign', 'Could not add indicator, please refresh and try again.', e);
        }
    }

    @AuraEnabled
    public static void updateIndicatorComment (String gmDataId, String indicatorId, String comment){
        try {
            Indicator_Assign__c indicator = [SELECT ID, GM_Data__c, Indicator__c, Comment__c FROM Indicator_Assign__c WHERE GM_Data__c=:gmDataId AND Indicator__c=:indicatorId LIMIT 1];
            indicator.Comment__c = comment;
            update indicator;
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.addIndicatorAssign', 'Could not update indicator, please refresh and try again.', e);
        }
    }

    @AuraEnabled
    public static void updateIndicatorQuantity (String gmDataId, String indicatorId, Integer quantity){
        try {
            Indicator_Assign__c indicator = [SELECT ID, GM_Data__c, Indicator__c, Quantity__c FROM Indicator_Assign__c WHERE GM_Data__c=:gmDataId AND Indicator__c=:indicatorId LIMIT 1];
            indicator.Quantity__c = quantity;
            update indicator;
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.addIndicatorAssign', 'Could not update indicator, please refresh and try again.', e);
        }
    }

    @AuraEnabled
    public static void removeIndicatorAssign (String gmDataId, String indicatorId){
        try {
            List < Indicator_Assign__c > indicators = [SELECT ID, GM_Data__c, Indicator__c FROM Indicator_Assign__c WHERE GM_Data__c=:gmDataId AND Indicator__c=:indicatorId];
            delete indicators;
        } catch (Exception e) {
            throw new GFW_Exception('ReviewFormController.removeIndicatorAssign', 'Could not remove indicator, please refresh and try again.', e);
        }
    }

    @AuraEnabled
    public static boolean submitInternalReview(String recordId){
        InternalReview rev = new InternalReview(recordId);
        rev.submit();
        return true;
    }

    @AuraEnabled(cacheable = true)
    public static string getInternalReviewVFPageName() {
        Application_Setting__mdt pageName = Application_Setting__mdt.getInstance('Internal_Review_Mode');
        return pageName.String_Value__c;
    }
    
}