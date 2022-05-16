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
 function updateRecordInternals(rec, picklistPhrasesMap, translationMap, countryNames) {
    //console.log('updateRecordInternals... (1)');
    rec.isTextArea = false;
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
    } else if (rec.Type__c=='select' && rec.Form_Picklist__c) { 
        rec.isSelect = true;
        rec.options = getOptions(rec, picklistPhrasesMap, translationMap, countryNames);
    } else if ((rec.Type__c=='radio' || rec.Type__c=='radio in-line') && rec.Form_Picklist__c) { //TODO: are all checkboxes single-select
        rec.isRadio = true;
        if (rec.Type__c=='radio in-line') rec.isInlineRadio = true;
        rec.options = getOptions(rec, picklistPhrasesMap, translationMap, countryNames);
    } else if (rec.Type__c=='checkbox group' && rec.Form_Picklist__c) {
        rec.isCheckboxGroup = true;
        rec.options = getOptions(rec, picklistPhrasesMap, translationMap, countryNames);
        // Stored values are separated by |, replace with comma
        if (rec.data && rec.data.Data_text__c) rec.data.Data_text__c.replace("|",",");
        // If blank data, assign "none"
        if (rec.data && !rec.data.Data_text__c) rec.data.Data_text__c = 'none';
    } else if (rec.Type__c=='checkbox') {
        //single option checkbox
        rec.isCheckbox = true;
        if (rec.data && rec.data.Data_text__c == 'true') rec.checked = true;
        else rec.checked = false;   
        console.log('formsUtilities updateRecordInternals: checkbox', rec);     
    } else if (rec.Type__c == 'phone') {
        rec.isPhone = true;
    } else if (rec.Type__c == 'email') {
        rec.isEmail = true;
    } else if (rec.Type__c == 'url') {
        rec.isURL = true;
    } else if (rec.Type__c == 'label') {
        rec.isLabel = true;
    }

    //console.log('updateRecordInternals: rec', rec);
    return rec;
}

function getOptions(rec, picklistPhrasesMap, translationMap, countryNames) {
    let options = [];
    //console.log('getOptions: picklistPhrasesMap', picklistPhrasesMap);
    if (picklistPhrasesMap) {
        let picklistOptions = picklistPhrasesMap.get(rec.Form_Picklist__c);
        // build options
        if (picklistOptions && picklistOptions.Type__c=='Countries') {
            for (let cName of countryNames) options.push({'label': cName, 'value': cName});
        } else if (picklistOptions && picklistOptions.Type__c=='Constants' && picklistOptions.Constant_values__c) {
            let optionsArray = picklistOptions.Constant_values__c.split('\r\n');
            for (let opt of optionsArray) options.push({'label': opt, 'value': opt});
        } else if (picklistOptions && picklistOptions.Type__c=='Phrases' && picklistOptions.Form_Picklist_Phrases__r) {
            for (let opt of picklistOptions.Form_Picklist_Phrases__r.records) {
                let translatedPhrase = translationMap.get(opt.Form_Phrase__c);
                options.push({'label': translatedPhrase, 'value': opt.Name});
            }
        }
    }
    //console.log('getOptions: options', options);
    return options;
}

export { buildTransByName, buildTransById, updateRecordInternals }