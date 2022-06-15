import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import getFormInstanceData from '@salesforce/apex/SiteController.getFormInstanceData';
import submitForm from '@salesforce/apex/SiteController.submitForm';

import { buildTransByName, buildTransById, updateRecordInternals } from 'c/formsUtilities';
import { handleError, buildError, showUIError } from 'c/lwcUtilities';

export default class FormInstance extends NavigationMixin ( LightningElement ) {
    //Will have the form instance ID from parent, query for:
    //recordId = 'a248c0000007z9iAAA'; // Hard-wiring in desperation...
    //@api recordId; 
    @api recordId; 
    @api isNonEditable = false; // External flag set once by caller or in app config
    @api isReadOnly; // Internal flag set and unset during processing at community
    @api isMultiView = false; // Determines whether we're in a single-form view or multi-form view.
    dataLoaded = false;
    showSpinner = true;
    hasSections;
    @track sections = [];
    @track components = [];
    topLevelCmps = [];
    @api language = 'English';
    transByNameObj;
    @track frm = {};
    @track fi = {};
    submitLabel = 'Submit';
    submitDisabled = true;
    logout;
    support;
    numErrors;

    
    connectedCallback() {
        //console.log('connectedCallback: this.recordId', this.recordid);
        //if (!this.recordId) this.recordId = 'a248c0000007z9iAAA';
        if (this.recordId) {
            //console.log('connectedCallback: this.recordId', this.recordid);
            //console.log('connectedCallback: this.language', this.language);
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
        //console.log('wire currentPageReference', currentPageReference);
        if (currentPageReference) {
            let urlStateParameters = currentPageReference.state;
            console.log('wire CurrentPageReference: urlStateParameters', urlStateParameters);
            this.language = urlStateParameters.language || 'English';
            if(!this.recordId) this.recordId = urlStateParameters.recordId || null;
            console.log('wire CurrentPageReference: this.recordId', this.recordId);
        }
    }

    async loadData() {
        console.log('formInstance loadData');
        console.log('formInstance loadData', this.recordId);
        this.isReadOnly = this.isNonEditable; // At the start, internal flag is equal to external flag
        let [data, translations ] = await Promise.all ([
            getFormInstanceData ({ formInstanceId: this.recordId }),
            getTranslations ()
        ]);

        let fiInfo = JSON.parse(data);
        translations = JSON.parse(translations);
        let transById = buildTransById(translations, this.language);
        let transByName = buildTransByName(translations, this.language);
        this.transByNameObj = Object.fromEntries(transByName);

        this.logout = transByName.get('Logout');
        this.support = transByName.get('Support');

        this.fi = fiInfo.frmInst;
        this.frm = fiInfo.frm;
        this.frm.title = transById.get(fiInfo.frm.Form_Phrase_Title__c)
        this.frm.intro = transById.get(fiInfo.frm.Form_Phrase_Intro__c)
        this.frm.footer = transById.get(fiInfo.frm.Form_Phrase_Footer__c)

        // Handle case when form instance has been submitted
        if (fiInfo.frmInst.Date_submitted__c && !this.frm.Resubmittable__c) {
            this.submitLabel = 'Submitted';
            this.submitDisabled = true;
            this.isReadOnly = true;
        }

        let formDataInfo = fiInfo.frmInst.Form_Data__r;
        let formData;
        let formDataMap = new Map();  //indexed my Form Component ID, value is an array of data for that component
        if (formDataInfo) {
            formData = formDataInfo.records;
            for (let data of formData ) formDataMap.set(data.Form_Component__c, data);
        }
        //console.log('formDataMap',formDataMap);

        let cmpsInfo = fiInfo.frm.Form_Components__r;
        let cmps;
        let cmpMap = new Map();
        if (cmpsInfo) {
            cmps = cmpsInfo.records;
            for (let cmp of cmps) cmpMap.set(cmp.Id, cmp);
        }
        //console.log('cmpMap',cmpMap);

        //console.log('fiInfo.orderingMap',fiInfo.orderingMap);
        const numberingMap = new Map(Object.entries(fiInfo.orderingMap));

        //console.log('fiInfo.countryNames', fiInfo.countryNames);
        let picklistMap = new Map();
        for (let picklist of fiInfo.frmPicklists) picklistMap.set(picklist.Id, picklist);

        // Process each form component
        let topCmps = [];
        for (let cmp of cmps) {
            cmp.formInstanceId = this.recordId;
            // Fill in the numbering
            cmp.displayNumber = numberingMap.get(cmp.Id);
            cmp.level = parseInt(cmp.Hierarchical_level_num__c);
            // fill in the form components' phrase translations
            // Note that any form component can have an intro phrase, not just section components
            if (cmp.Form_Phrase__c) cmp.translatedFormPhrase = transById.get(cmp.Form_Phrase__c);
            // Attach question number if any
            cmp.title = ((cmp.displayNumber && cmp.Numbered__c) ? cmp.displayNumber + '. ' : '') + (cmp.translatedFormPhrase || '');
            if (cmp.Form_Phrase_Intro__c) cmp.translatedIntro = transById.get(cmp.Form_Phrase_Intro__c);
            // Use parent component link to gather lists of child components - note that child ordering should reflect hierarchical ordering of entire form
            if (cmp.Group_Component__c) {
                let parentCmp = cmpMap.get(cmp.Group_Component__c);
                if (!parentCmp.childCmps) parentCmp.childCmps = [];
                parentCmp.childCmps.push(cmp);
            } else topCmps.push(cmp);
            // Fill in type - in future, might tweak/add types to support rendering
            cmp.type = cmp.Type__c;
            if (cmp.type == 'section') {
                cmp.isSection = true;
                this.sections.push(cmp);
            }
            // Fill in form component's data, or build new data if none present
            cmp.data = formDataMap.has(cmp.Id) ? formDataMap.get(cmp.Id) : this.getEmptyFormData(cmp);
            // Other tweaks to cmp
            cmp.isRequired = cmp.Required__c;
            // Tweak form components that link to picklists
            updateRecordInternals(cmp, picklistMap, transById, fiInfo.countryNames);
            //console.log('cmp', cmp);
        }
        //console.log('topCmps', topCmps);
        this.topLevelCmps = topCmps;
        this.hasSections = this.sections.length > 0;
        this.components = cmps;
        this.dataLoaded = true;
        this.showSpinner = false;
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

    // formFieldEditor notification of data change
    handleDataChange(event) {
        let cmpId = event.detail.cmpId;
        let newData = event.detail.dataText;
        //console.log('formInstance handleDataChange: cmpId/newData', cmpId, newData);
        // Write @api function in formComponent to determine whether components dependent on the changed field need to be hidden/shown.
        // ...
        this.handleReady();
    }

    handleReady() {
        //console.log('formInstance handleReady (before): this.isReadOnly = ' +this.isReadOnly+ '; this.submitDisabled = ' +this.submitDisabled+ '; this.numErrors = ' +this.numErrors);
        this.numErrors = this.countErrors();
        if (!this.isReadOnly && this.isValid()) {
            this.submitDisabled = false;
            this.dataLoaded = true;
        } else {
            this.submitDisabled = true;
            this.dataLoaded = true;
        }
        //console.log('formInstance handleReady (after): this.isReadOnly = ' +this.isReadOnly+ '; this.submitDisabled = ' +this.submitDisabled+ '; this.numErrors = ' +this.numErrors);
        this.showSpinner = false;
    }

    @api countErrors() {
        const countChildCmpsErrs = [...this.template.querySelectorAll('c-form-component')]
            .reduce((countSoFar, formCmp) => {
                return countSoFar + formCmp.countErrors();
            }, 0);
        return countChildCmpsErrs;
    }

    @api highlightErrors() {
        [...this.template.querySelectorAll('c-form-component')]
            .forEach((formCmp) => {
                formCmp.highlightErrors();
            });
    }

    // Validity of form instance bubbled up from formComponent 
    @api isValid() {
        let allValid = true;
        this.template.querySelectorAll('c-form-component').forEach(element => {
            if (element.isValid()!=true) allValid = false;
        });
        //console.log('formInstance isValid: allValid = ' +allValid);
        return allValid;
    }

    async handleSubmit() {
        try {
            let submitted = await submitForm({formInstanceId:this.recordId});
            if (submitted) {
                dispatchEvent(
                    new ShowToastEvent({
                        title: this.transByNameObj.FormSubmitted,
                        message: this.transByNameObj.FormSubmittedMsg,
                        variant: 'success'
                    })
                )
                this[NavigationMixin.Navigate]({type: 'comm__namedPage', attributes: {name: 'Home'}});
            } else showUIError(buildError('Submit form unsuccessful', 'Your form could not be submitted - please contact your administrator'));
        } catch (error) {
            console.log('handleSubmit catch with recordId = ' +this.recordId+ ' with error', error);
            showUIError(buildError('Submit form unsuccessful', 'Your form could not be submitted - please contact your administrator', 'error'));
            handleError(error);
        }
    }

}