import MailingPostalCode from '@salesforce/schema/Contact.MailingPostalCode';
import { LightningElement } from 'lwc';

export default class FormsUtilities extends LightningElement {}

// Mapping from form phrase names to translations in given language
function buildTransByName (translations, language) {
    let transByName = new Object();
    // Build map of maps by phrase name and by language
    const nameLangMap = new Map();
    for (let trans of translations) {
        let pName = trans.Form_Phrase__r.Name;
        if (!nameLangMap.get(pName)) nameLangMap.put(pName, new Map());
        nameLangMap.get(pName).put(trans.Language__c, trans.Text__c);
    }
    for (let pName of nameLangMap) {
        transByName[pName] = nameLangMap.get(pName).get(language) || nameLangMap.get(pName).get('English');
    }
    return transByName;
}

// Mapping from form phrase ids to translations in given language
function buildTransById (translations, language) {
    let transById = new Object();
    // Build map of maps by phrase id and by language
    const idLangMap = new Map();
    for (let trans of translations) {
        let pId = trans.Form_Phrase__c;
        if (!idLangMap.get(pId)) idLangMap.put(pId, new Map());
        idLangMap.get(pId).put(trans.Language__c, trans.Text__c);
    }
    for (let pId of idLangMap) {
        transById[pId] = idLangMap.get(pId).get(language) || idLangMap.get(pId).get('English');
    }
    return transById;
}

// update item internals
function updateItemType(item) {
    //if the item has a form phrase, and child components, it's regular
    if (item.Form_Components__r && item.Form_Phrase__r) {
        item.isStandard = true;
    } else if (item.isCheckbox) {
        item.isStandard = true;

    //No Components, but has a phrase means intro text
    } else if (item.Form_Phrase__r && item.Form_Phrase__r.Phrase_in_English__c) {
        item.isIntroText = true;
        if (item.displayNumber) {
            item.Form_Phrase__r.Phrase_in_English__c = item.displayNumber + ". " + item.Form_Phrase__r.Phrase_in_English__c;
        }

    //If it has child components but no Phrase    
    } else if (item.Form_Components__r) {
        //no phrase itself, but has child phrases
        item.isNoPhraseParent = true;
    } else {
        item.isBlank = true;
    }
    if (item.Type__c.includes("Table")) {
        item.isTable = true;
        if (item.Form_Components__r) {
            for (let cmp of item.Form_Components__r.records) {
                cmp.isTableCellPart = true;
            }
        }
    }

    return item;

}

function getCheckboxOrRadioOptions(picklistOptions, translationMap, useTranslations) {
    let options = [];
    // build radio options
    if (picklistOptions && picklistOptions.Type__c=='Phrases' && picklistOptions.Form_Picklist_Phrases__r && picklistOptions.Form_Picklist_Phrases__r.records) {
        for (let opt of picklistOptions.Form_Picklist_Phrases__r.records) {
            if (useTranslations) {
                let translatedPhrase = translationMap.get(opt.Form_Phrase__c);
                options.push({'label': translatedPhrase.Text__c, 'value': opt.Name});
            } else {
                options.push({'label': opt.Form_Phrase__r.Phrase_in_English_trimmed__c, 'value': opt.Name});
            }
        }
    } else if (picklistOptions && picklistOptions.Type__c=='Constants' && picklistOptions.Constant_values__c) {
        let optionsArray = picklistOptions.Constant_values__c.split('\r\n');
        for (let opt of optionsArray) {
            options.push({'label': opt, 'value': opt});
        }
    }
    return options;
}

 //Unclear how much of this is needed:
 function updateRecordInternals(rec, picklistPhrasesMap, translationMap, useTranslations) {
    if (rec.Type__c=='text' || rec.Type__c=='text latin chars' || rec.Type__c=='select' ) {
        rec.isText = true;
        if (!rec.Character_limit__c) {
            rec.Character_limit__c = 255; //default max chars in salesforce Form Data Data_text__c
        }
    } else if (rec.Type__c=='textarea' || rec.Type__c=='textarea latin chars') {
        rec.isTextArea = true;
        if (!rec.Character_limit__c) {
            rec.Character_limit__c = 32768; //default max chars in salesforce Form Data Data_textarea__c
        }
    } else if ((rec.Type__c=='radio' || rec.Type__c=='radio in-line') && rec.Form_Picklist__r) { //TODO: are all checkboxes single-select
        rec.isRadio = true;
        // get options, and build radio component
        if (picklistPhrasesMap) {
            let picklistOptions = picklistPhrasesMap.get(rec.Form_Picklist__r.Name);
            rec.radioOptions = getCheckboxOrRadioOptions(picklistOptions, translationMap, useTranslations);
        }
        
        //if no data, create blank data
        if (!rec.data) {
            rec.data = {};
            rec.data.Data_textarea__c = '';
            rec.data.Data_text__c = '';
        } else if (!rec.data.Data_text__c) {
            rec.data.Data_text__c = '';
        }
    } else if (rec.Type__c=='radio in-line') {
        rec.isInlineRadio = true;
    } else if (rec.Type__c=='checkbox') {
        if (rec.Form_Picklist__r) {
            rec.isCheckboxGroup = true;
            if (picklistPhrasesMap) {
                let picklistOptions = picklistPhrasesMap.get(rec.Form_Picklist__r.Name);
                rec.checkboxOptions = getCheckboxOrRadioOptions(picklistOptions);
            }
            
            // The values will be separated by |, replace with comma
            if (rec.data && rec.data.Data_text__c) {
                rec.data.Data_text__c.replace("|",",");
            }
            //if no data, create blank data
            if (!rec.data) {
                rec.data = {};
                rec.data.Data_textarea__c = 'none';
                rec.data.Data_text__c = 'none';
            } else if (!rec.data.Data_text__c) {
                rec.data.Data_text__c = 'none';
            }
        } else {
            //single option checkbox
            rec.isCheckbox = true;
            if (rec.data) {
                if (rec.data.Data_text__c == 'true') {
                    rec.checked = true;
                } else {
                    rec.checked = false;
                }
            } else {
                rec.checked = false;
            }
            
        }
        
    } else if (rec.Type__c=='checkbox in-line') {
        rec.inlineCheckbox = true; 
    } else if (rec.Type__c=='checkbox 2-col') {
        rec.isCol2Checkbox = true;
    } else if (rec.Type__c=='checkbox 3-col') {
        rec.isCol3Checkbox = true;
    } else if (rec.Type__c=='checkbox 4-col') {
        rec.isCol4Checkbox = true;
    } else if (rec.Type__c=='number') {
        rec.isNumber = true;
    } else if (rec.Type__c=='currency') {
        rec.isCurrency = true;
    } else if (rec.Type__c=='percent') {
        rec.isPercent = true;
    } else if (rec.Type__c=='percent equals 100') {
        rec.isPercent100 = true;
    } else if (rec.Type__c=='date') {
        rec.isDate = true;
    } else if (rec.Type__c=='email' || rec.Type__c=='email non-applicant') {
        rec.isEmail = true;
    } else if (rec.Type__c=='phone') {
        rec.isPhone = true;
    } else if (rec.Type__c=='url') {
        rec.isUrl = true;
    } else if (rec.Type__c=='table heading') {
        rec.isTableHeading = true;
    } else if (rec.Type__c=='group') {
        rec.isGroup = true;
    } else if (rec.Type__c=='indicator') {
        rec.isIndicator = true;
    }

    return rec;
}



export {
    buildTransByName, buildTransById, updateItemType,getCheckboxOrRadioOptions,updateRecordInternals
};