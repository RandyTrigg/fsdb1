import MailingPostalCode from '@salesforce/schema/Contact.MailingPostalCode';
import { LightningElement } from 'lwc';

export default class FormsUtilities extends LightningElement {}

// Mapping from form phrase names to translations in given language
function buildTransByName (translations, language) {
    let transByName = new Map();
    // Build map of maps by phrase name and by language
    const nameLangMap = new Map();
    for (let trans of translations) {
        let pName = trans.Form_Phrase__r.Name;
        //console.log('buildTransByName: pName = ' +pName);
        if (!nameLangMap.has(pName)) nameLangMap.set(pName, new Map());
        nameLangMap.get(pName).set(trans.Language__c, trans.Text__c);
        //console.log(nameLangMap.get(pName));
    }
    for (const [pName, langMap] of nameLangMap) {
        transByName.set(pName, langMap.get(language) || langMap.get('English'));
    }
    //console.log(transByName);
    return transByName;
}

// Mapping from form phrase ids to translations in given language
function buildTransById (translations, language) {
    let transById = new Map();
    // Build map of maps by phrase id and by language
    const idLangMap = new Map();
    for (let trans of translations) {
        let pId = trans.Form_Phrase__c;
        if (!idLangMap.has(pId)) idLangMap.set(pId, new Map());
        idLangMap.get(pId).set(trans.Language__c, trans.Text__c);
    }
    for (const [pId, langMap] of idLangMap) {
        transById.set(pId, langMap.get(language) || langMap.get('English'));
    }
    return transById;
}

 // Handle checkboxes and radios
 function updateRecordInternals(rec, picklistPhrases, translationMap) {
    if (rec.Type__c=='text' || rec.Type__c=='text latin chars' ) {
        rec.isText = true;
        if (!rec.Character_limit__c) {
            rec.Character_limit__c = 255; //default max chars in salesforce Form Data Data_text__c
        }
    } else if (rec.Type__c=='textarea' || rec.Type__c=='textarea latin chars') {
        rec.isTextArea = true;
        if (!rec.Character_limit__c) {
            rec.Character_limit__c = 32768; //default max chars in salesforce Form Data Data_textarea__c
        }
    } else if (rec.Type__c=='select' && rec.Form_Picklist__r) { 
        rec.isSelect = true;
        // get options, and build select options
        if (picklistPhrasesMap) {
            let picklistOptions = picklistPhrases.get(rec.Form_Picklist__c);
            rec.options = getCheckboxOrRadioOptions(picklistOptions, translationMap);
        }
    } else if ((rec.Type__c=='radio' || rec.Type__c=='radio in-line') && rec.Form_Picklist__r) { //TODO: are all checkboxes single-select
        rec.isRadio = true;
        if (rec.Type__c=='radio in-line') rec.isInlineRadio = true;
        // get options, and build radio component
        if (picklistPhrasesMap) {
            let picklistOptions = picklistPhrases.get(rec.Form_Picklist__c);
            rec.options = getCheckboxOrRadioOptions(picklistOptions, translationMap);
        }
    } else if (rec.Type__c=='checkbox group') {
        if (rec.Form_Picklist__r) {
            rec.isCheckboxGroup = true;
            if (picklistPhrasesMap) {
                let picklistOptions = picklistPhrases.get(rec.Form_Picklist__c);
                rec.options = getCheckboxOrRadioOptions(picklistOptions, translationMap);
            }
            // Stored values are separated by |, replace with comma
            if (rec.data && rec.data.Data_text__c) rec.data.Data_text__c.replace("|",",");
            // If blank data, assign "none"
            if (rec.data && !rec.data.Data_text__c) rec.data.Data_text__c = 'none';
        }
    } else if (rec.Type__c=='checkbox') {
        //single option checkbox
        rec.isCheckbox = true;
        if (rec.data && rec.data.Data_text__c == 'true') rec.checked = true;
        else rec.checked = false;        
    }
    console.log('updateRecordInternals: rec', rec);
    return rec;
}

function getCheckboxOrRadioOptions(picklistOptions, translationMap, useTranslations) {
    let options = [];
    // build options
    if (picklistOptions && picklistOptions.Type__c=='Phrases' && picklistOptions.Form_Picklist_Phrases__r) {
        for (let opt of picklistOptions.Form_Picklist_Phrases__r) {
            let translatedPhrase = translationMap.get(opt.Form_Phrase__c);
            options.push({'label': translatedPhrase.Text__c, 'value': opt.Name});
        }
    } else if (picklistOptions && picklistOptions.Type__c=='Constants' && picklistOptions.Constant_values__c) {
        let optionsArray = picklistOptions.Constant_values__c.split('\r\n');
        for (let opt of optionsArray) {
            options.push({'label': opt, 'value': opt});
        }
    }
    return options;
}

export { buildTransByName, buildTransById, updateRecordInternals }