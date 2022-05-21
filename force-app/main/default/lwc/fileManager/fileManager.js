import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


import deleteRecordById from'@salesforce/apex/Utilities.deleteRecordById';
import fetchRecords from'@salesforce/apex/Utilities.fetchRecords';

export default class FileManager extends LightningElement {
    @api recordId;
    @api maxNumFiles;
    @api transByNameObj;
    @track files; // List of pairs of file name and doc id
    disabled;
    acceptedFileFormats = ['.pdf', '.png', '.jpg', '.jpeg'];
    showSpinner = true;

    connectedCallback() {
        if (this.recordId) this.loadInfo();
    }

    // Fetch info for files linked to given record
    async loadInfo () {
        const whereClause = 'WHERE LinkedEntityId = \'' +this.recordId+ '\'';
        const relFieldNames = ['ContentDocument.Title'];
        this.showSpinner = true;
        let linkedFiles = await fetchRecords({objName: 'ContentDocumentLink', whereClause: whereClause, relatedFieldNames: relFieldNames});
        this.showSpinner = false;
        console.log('fileManager loadInfo: linkedFiles => ', linkedFiles);
        let fInfo = Array();
        for (let f of linkedFiles) {
            fInfo.push({name: f.ContentDocument.Title, documentId: f.ContentDocumentId});
        }
        console.log('fileManager loadInfo: fInfo => ', fInfo);
        this.files = fInfo;
        this.disabled = fInfo.length >= this.maxNumFiles;
    }

    // Handler for file upload
    handleUploadFinished(event) {
        // Get uploaded file
        const uploadedFiles = event.detail.files;
        const fName = uploadedFiles[0].name;
        this.files.push({name: fName, documentId: uploadedFiles[0].documentId});
        this.disabled = this.files.length >= this.maxNumFiles;
        dispatchEvent(
            new ShowToastEvent({
                title: this.transByNameObj.FileUploaded +': '+ fName,
                variant: 'success'
            })
        );
    }

    // Handler for file delete
    handleRemove (event) {
        let documentId = event.currentTarget.name; // Name attribute of lightning-pill contains document id, not file name
        console.log('fileManager handleRemove documentId = ', documentId);
        // Put up modal confirm to ensure they want to delete the file
        //...
        this.deleteFile(documentId);
    }

    async deleteFile (documentId) {
        this.showSpinner = true;
        await deleteRecordById({id: documentId});
        this.showSpinner = false;
        dispatchEvent(
            new ShowToastEvent({
                title: this.transByNameObj.FileDeleted,
                variant: 'success'
            })
        );
        // Pull down list of linked files again. 
        this.loadInfo();
    }
}