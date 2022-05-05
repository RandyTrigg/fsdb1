import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import getFormInstanceData from '@salesforce/apex/FormInstanceController.getFormInstanceData';
import getTranslations from '@salesforce/apex/FormPhraseController.getTranslations';

import { buildTransByName, buildTransById, updateRecordInternals } from 'c/formsUtilities';
import { handleError } from 'c/lwcUtilities';

export default class FormInstance extends LightningElement {
    //Will have the form instance ID from parent, query for:
    @api recordId;
    @api isEditable;
    @api isMultiView; // Determines whether we're in a single-form view or multi-form view.
    dataLoaded = false;
    intro;
    sections = [];
    components = [];
    topLevelCmps = [];
    picklistPhrasesMap;
    language = 'English';
    transByName;
    transById;
    frm = {};

    //The form Instance with all its fields, the form and form data, form sections, form items, form components and form data.
    connectedCallback() {
        if (this.recordId) {
            this.loadData();
        }
    }

    renderedCallback() {
        if (this.language=='Arabic') {
            this.template.querySelector('[data-id="intro"]').classList.add('gfw-arabic-body');
        }
    }
 
    // Get parameters from current URL (e.g. language)
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
       if (currentPageReference) {
          let urlStateParameters = currentPageReference.state;
          this.language = urlStateParameters.language || null;
       }
    }

    async loadData() {
        console.log('loadData');
        let [data, translations ] = await Promise.all ([
            getFormInstanceData ({ formInstanceId: this.recordId }),
            getTranslations ()
        ]);
        // Default values of @api fields here in case they weren't set by caller. Or am I allowed to default in the @api field declaration?
        // Note attempt to test for null/undefined - we don't want to override "false" values for boolean fields
        if(this.isEditable === '') this.isEditable = true;
        if(this.isMultiView === '') this.isMultiView = false;

        let fiInfo = JSON.parse(data);
        translations = JSON.parse(translations);
        this.transByName = buildTransByName(translations, language);
        this.transById = buildTransById(translations, language);

        this.frm.title = this.transById.get(fiInfo.frm.Form_Phrase_Title__c)
        this.frm.intro = this.transById.get(fiInfo.frm.Form_Phrase_Intro__c)

        let formData = fiInfo.frmInst.Form_Data__r;
        let formDataMap = new Map();  //indexed my Form Component ID, value is an array of data for that component
        if (formData) {
            for (let data of formData ) {
                formDataMap.set(data.Form_Component__c, data);
            }
        }
        console.log('formDataMap',formDataMap);
        let cmps = fiInfo.frm.Form_Components__r;
        let cmpMap = new Map();
        for (let cmp of cmps) cmpMap.set(cmp.Id, cmp);

        let picklistPhrasesMap = new Map(Object.entries(fiInfo.frmPicklists));   
        let numberingMap = fiInfo.orderingMap;

        // Process each form component
        for (let cmp of cmps) {
            cmp.formInstanceId = this.recordId;
            // Fill in the numbering
            cmp.displayNumber = numberingMap.get(cmp.Id);
            cmp.level = parseInt(cmp.Hierarchical_level_num__c);
            // fill in the form components' phrase translations
            // Note that any form component can have an intro phrase, not just section components
            if (cmp.Form_Phrase__c) cmp.translatedFormPhrase = this.transById.get(cmp.Form_Phrase__c);
            // Attach question number if any
            cmp.title = (cmp.displayNumber ? cmp.displayNumber + '. ' : '') + (cmp.translatedFormPhrase || '');
            if (cmp.Form_Phrase_Intro__c) cmp.translatedIntro = this.transById.get(cmp.Form_Phrase_Intro__c);
            // Use parent component link to gather lists of child components - note that child ordering should reflect hierarchical ordering of entire form
            if (cmp.Group_Component__c) {
                let parentCmp = cmpMap.get(cmp.Group_Component__c);
                if (!parentCmp.childCmps) parentCmp.childCmps = [];
                parentCmp.childCmps.push(cmp);
            } else topLevelCmps.push(cmp);
            // Fill in type - in future, might tweak/add types to support rendering
            cmp.type = cmp.Type__c;
            if (cmp.type == 'section') {
                this.sections.push(cmp);
                if (this.isMultiView) cmp.accordion = true;
            }
            // Fill in form component's data, or build new data if none present
            if (formDataMap.has(cmp.Id)) cmp.data = formDataMap.get(cmp.Id);
            else cmp.data = this.getEmptyFormData(cmp);
            // Other tweaks to cmp
            cmp.isRequired = cmp.Required__c;
            updateRecordInternals(cmp, fiInfo.frmPicklists, this.transById);
        }
        this.components = cmps;
        this.dataLoaded = true;
    }

    getEmptyFormData(cmp) {
        let data = {};
        data.Data_numeric__c = null;
        data.Data_text__c = null;
        data.Data_textarea__c = null;
        data.Form_Component__c = cmp.Id;
        data.Form_Instance__c = this.recordId;
        data.Type__c = cmp.Type__c; // Do we need to do this? If so, is it correct?
        return data;
    }

    // Validity of form instance bubbled up from formComponent 
    @api isValid() {
        let allValid = true;
        this.template.querySelectorAll('c-form-component').forEach(element => {
            if (element.isValid()!=true) allValid = false;
        });
        return allValid;
    }

}