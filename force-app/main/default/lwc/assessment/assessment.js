import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getAssessmentData from '@salesforce/apex/SiteController.getAssessmentData';
import getTranslations from '@salesforce/apex/SiteController.getTranslations';
import { buildTransByName } from 'c/formsUtilities';
import { handleError, buildError, showUIError } from 'c/lwcUtilities';

export default class Assessment extends NavigationMixin ( LightningElement ) {

    @api recordId; 
    assessedRecordId;
    @api language = 'English';
    support;
    logout;
    formInstanceId;
    dataLoaded = false;
    transByNameObj;
    groupName;
    propName;
    propType;


    connectedCallback() {
        //console.log('connectedCallback: this.recordId', this.recordid);
        //if (!this.recordId) this.recordId = 'a248c0000007z9iAAA';
        if (this.recordId) {
            this.loadData();
        }
    }
 
    // Get parameters from current URL (e.g. lang)
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        //console.log('wire currentPageReference', currentPageReference);
        if (currentPageReference) {
            let urlStateParameters = currentPageReference.state;
            console.log('wire CurrentPageReference: urlStateParameters', urlStateParameters);
            this.language = urlStateParameters.lang || 'English';
            if(!this.recordId) this.recordId = urlStateParameters.recordId || null;
            console.log('wire CurrentPageReference: this.recordId', this.recordId);
        }
    }

    async loadData() {
        console.log('assessment loadData');
        let [assessmentData, translations ] = await Promise.all ([
            getAssessmentData ({ assessmentId: this.recordId }),
            getTranslations ()
        ]);
        let assessment = JSON.parse(assessmentData);
        let assessRec = assessment.assessRec;
        console.log('assessment');
        console.log(assessment);
        translations = JSON.parse(translations);
        let transByName = buildTransByName(translations, this.language);
        this.transByNameObj = Object.fromEntries(transByName);
        this.support = transByName.get('Support');
        this.logout = transByName.get('Logout');
        this.assessedRecordId = assessment.assessedRecordId;
        if (assessment.formName) {
            this.formInstanceId = assessment.formInstanceId;
        } else if (assessment.reviewFormName) {
            // Set things up for the right side to be a review form...
        } else {
            // Throw an error 
        }
        this.groupName = assessment.groupName;
        this.propName = assessment.propName;
        this.propType = assessment.propType;
        this.dateSubmitted = assessRec.Date_submitted__c;
        this.dataLoaded = true;
    }
}