import { LightningElement, api } from 'lwc';

import getFormTree from '@salesforce/apex/FormViewerController.getFormTree';
import getDataForFormViewer from '@salesforce/apex/FormViewerController.getDataForFormViewer';
import getFieldReferenceData from '@salesforce/apex/FormViewerController.getFieldReferenceData';

import { updateItemType, updateRecordInternals } from 'c/formsUtilities';
import { handleError } from 'c/lwcUtilities';

export default class FormInstance extends LightningElement {
    //Will have the form instance ID from parent, query for:
    @api instanceId;
    @api isEditable = false;
    @api isMultiView = false; // Determines whether we're in a single-form view or multi-form view.  Defaults to
    dataLoaded = false;
    intro;
    completeSections = [];
    connectorList;
    connectorIdsSet = new Set(); // a set of the ids for all items and components that are a source or target
    @api useTranslations = false;
    picklistPhrasesMap;
    language;


    //The form Instance with all its fields, the form and form data, form sections, form items, form components and form data.
    connectedCallback() {
        if (this.instanceId) {
            this.loadData();
        }
    }

    renderedCallback() {
        if (this.language=='Arabic') {
            this.template.querySelector('[data-id="intro"]').classList.add('gfw-arabic-body');
        }
    }

    async loadData() {
        console.log('loadData');
        let [tree, data ] = await Promise.all ([
            getFormTree ({ formInstanceId: this.instanceId }),
            getDataForFormViewer ({ formInstanceId: this.instanceId })
        ]);

        let formTree = JSON.parse(tree);
        let formData = JSON.parse(data);

        console.log('formTree',formTree);

        this.language = formTree.language;

        let numberingMap = new Map(Object.entries(formTree.itemNumberingMap));
        let translationMap = new Map(Object.entries(formTree.translations));

        this.picklistPhrasesMap = new Map(Object.entries(formTree.formPicklistMap));       

        // TODO: Likely want to only load these when in edit mode
        this.connectorList = formTree.connectorList;
        this.buildConnectorSet();

        // put connectors into a map indexed by target, for data attaching further down
        let connectorsByTargetMap = new Map();
        for (let connector of this.connectorList) {
            if (connector.Target_component__c) {
                connectorsByTargetMap.set(connector.Target_component__c, connector);
            } else if (connector.Target_item__c) {
                connectorsByTargetMap.set(connector.Target_item__c, connector);
            }
        }
        
        //We need the data in a format we can get to
        let formDataMap = new Map();  //indexed my Form Component ID, value is an array of data for that component
        if (formData) {
            for (let data of formData.data ) {
                formDataMap.set(data.Form_Component__c, data);
            }
        }

        // fill in the section intro/titles with translations
        if (this.useTranslations) {
            let introTranslation = translationMap.get(formTree.introPhraseId);
            if (introTranslation) {
                this.intro = introTranslation.Text__c;
            }
            for (let sec of formTree.sections) {
                if (sec.Form_Phrase_Intro__c) {
                    let sectionIntroTranslation = translationMap.get(sec.Form_Phrase_Intro__c);
                    if (sectionIntroTranslation) {
                        sec.introText = sectionIntroTranslation.Text__c;
                    }
                }
            }
            for (let itm of formTree.items) {
                if (itm.Form_Phrase__c && translationMap.has(itm.Form_Phrase__c)) {
                    itm.translatedFormPhrase = translationMap.get(itm.Form_Phrase__c).Text__c;
                } else if (itm.Form_Phrase__c) {
                    itm.translatedFormPhrase = itm.Form_Phrase__r.Phrase_in_English__c;
                }
                
            } 
        } else {
            this.intro = formTree.intro;
            for (let itm of formTree.items) {
                if (itm.Form_Phrase__c) {
                    itm.translatedFormPhrase = itm.Form_Phrase__r.Phrase_in_English__c;
                }
            } 
        }

        for (let sec of formTree.sections) {
            //get data referenced if needed
            //TODO: are there specific fields where this can be the case? Just section intro text?????
            if (sec.Form_Phrase_Intro__r && sec.Form_Phrase_Intro__r.Phrase_in_English__c && sec.Form_Phrase_Intro__r.Phrase_in_English__c.includes("<<")) {
                try {
                    let fieldRef = await getFieldReferenceData({ formInstanceId: this.instanceId, fieldReference: sec.Form_Phrase_Intro__r.Phrase_in_English__c});
                    sec.introText = fieldRef;
                } catch (error) {
                    handleError(error);
                }
                
            } else if (sec.Form_Phrase_Intro__r && sec.Form_Phrase_Intro__r.Phrase_in_English__c) {
                sec.introText = sec.Form_Phrase_Intro__r.Phrase_in_English__c;
            }            
        }

        //Build a map of form Items indexed by section
        let topLevelItems = [];
        let childItems = new Map(); //Index is parent item, value is a list of child items

        // TODO: Items and components that are targets of Component Connectors, need to have the data for the source component available, so that they can initially render in the correct state

        for (let itm of formTree.items ) {
            //fill in the numbering
            itm.displayNumber = numberingMap.get(itm.Id);

            // Add in source connector component data           
            if (connectorsByTargetMap.has(itm.Id)) {
                let sourceComponentConnector = connectorsByTargetMap.get(itm.Id);
                itm.sourceConnectorData = formDataMap.get(sourceComponentConnector.Source_component__c);
            }

            // Update item type, connectors etc.c
            itm = updateItemType(itm);
            itm = this.updateItemWithConnectors(itm);
            itm.formInstanceId = this.instanceId;

            if (itm.Form_Components__r && itm.Form_Components__r.records) {
                //attach each item's components with corresponding data
                for (let cmp of itm.Form_Components__r.records) {
                    if (formDataMap.has(cmp.Id)) {
                        cmp.data = formDataMap.get(cmp.Id);
                    } else {
                        cmp.data = this.getEmptyFormData(cmp);
                    }
                    // Add translation if needed 
                    if (this.useTranslations) {
                        if (cmp.Form_Phrase__c && translationMap.has(cmp.Form_Phrase__c)) {
                            cmp.translatedFormPhrase = translationMap.get(cmp.Form_Phrase__c).Text__c;
                        } else if (cmp.Form_Phrase__c) {
                            cmp.translatedFormPhrase = cmp.Form_Phrase__r.Phrase_in_English__c;
                        }
                    } else if (cmp.Form_Phrase__c) {
                        cmp.translatedFormPhrase = cmp.Form_Phrase__r.Phrase_in_English__c;
                    }
                    

                    cmp = updateRecordInternals(cmp, this.picklistPhrasesMap, translationMap, this.useTranslations);
                    //Add in connector records
                    cmp = this.updateCmpWithConnectors(cmp);

                    // Add in source connector component data
                    if (connectorsByTargetMap.has(cmp.Id)) {
                        let sourceComponentConnector = connectorsByTargetMap.get(cmp.Id);
                        cmp.sourceConnectorData = formDataMap.get(sourceComponentConnector.Source_component__c);
                    }
                    
                }
                
            }

            if (itm.Form_Item_Parent__c) {
                //see if there is a list going yet of child itmes
                if (childItems.get(itm.Form_Item_Parent__c)) {
                    let children = childItems.get(itm.Form_Item_Parent__c);
                    children.push(itm);
                    childItems.set(itm.Form_Item_Parent__c, children);
                } else {
                    let children = [];
                    children.push(itm);
                    childItems.set(itm.Form_Item_Parent__c, children);
                }
            }

            //Add Ordering
            if (itm.Form_Components__r && itm.Form_Components__r.records) {
                itm.Form_Components__r.records.forEach(function (cmp, i) {
                    cmp.level = parseInt(cmp.Hierarchical_level_num__c);
                });
            }

            // If this Form Item has a type of table, we have special setup to do
            if (itm.Type__c.includes("Table")) {
                let numColumns = itm.Number_of_columns__c;

                //create a list of the components that are not grouped
                let nonGroupedCmps;
                if (itm.Form_Components__r) {
                    nonGroupedCmps = itm.Form_Components__r.records.filter(cmp => !cmp.Group_Component__c);
                }  

                itm.hasHeaderRow = this.hasHeaderRow(nonGroupedCmps, numColumns);

                //now I need to append the components that correspond with the data, to their group
                let groupedComponentsByParent = new Map(); //index is group component id, value is an array of components
                if (itm.Form_Components__r) {
                    for (let cmp of itm.Form_Components__r.records) {
                        if (cmp.Group_Component__c) {
                            //get the list if it exists
                            if (groupedComponentsByParent.get(cmp.Group_Component__c)) {
                                let groupedComponents = groupedComponentsByParent.get(cmp.Group_Component__c);
                                groupedComponents.push(cmp);
                                groupedComponentsByParent.set(cmp.Group_Component__c, groupedComponents);
                            } else {
                                let groupedComponents = [];
                                groupedComponents.push(cmp);
                                groupedComponentsByParent.set(cmp.Group_Component__c, groupedComponents);
                            }
                        }
                    }
                }

                //now go back through all the components, pulling out the groups and putting them in the correct column, and filling in their child components

                if (nonGroupedCmps) {
                    nonGroupedCmps.forEach(function (cmp, index) {
                        cmp.colNum = index % numColumns;
                        cmp.rowNum = Math.floor(index / numColumns);
                        if (cmp.Type__c=='group') {
                            //attach child components of the group
                            cmp.cellFields = groupedComponentsByParent.get(cmp.Id);
                        }
                    });
                    
                    
                    
                    itm.tableComponents = nonGroupedCmps;

                }
                

            }
        }

        //Attach children
        for (let itm of formTree.items) {
            // see if it has children, if so append them
            if (childItems.get(itm.Id)) {
                itm.children = childItems.get(itm.Id);
            } 
        }

        

        //fill the array of top level items which now have their children appended
        for (let itm of formTree.items) {
            if (itm.Hierarchical_level_num__c===0) {
                topLevelItems.push(itm);
            } 
        }

        // need to put the items in the sections
        let itemsBySection = new Map();  //key is section id, value is list of Items

        for (let itm of topLevelItems) {
            if (itemsBySection.get(itm.Form_Section__c)) {
                let itemArray = itemsBySection.get(itm.Form_Section__c);
                itemArray.push(itm);
                itemsBySection.set(itm.Form_Section__c, itemArray);
            } else {
                let itemArray = [];
                itemArray.push(itm);
                itemsBySection.set(itm.Form_Section__c, itemArray);
            }
        }

        for (let section of formTree.sections ) {
            let itemArray = itemsBySection.get(section.Id);
            section.items = itemArray;
            section.formInstanceId = this.instanceId;
            if (!section.Form_Phrase_Title__r) {
                section.Form_Phrase_Title__r = {Phrase_in_English__c:""};
            }
        }

        console.log('formTree');
        console.log(formTree);
        console.log('formData');
        console.log(formData);

        this.completeSections = formTree.sections;
        this.dataLoaded = true;

    }
    

    // Table has a header row only if all comps in the first row have type='table heading'.
    hasHeaderRow(cmps, numColumns) {
        if (numColumns && cmps && cmps.length>0) {
            for (let i = 0; i< numColumns; i++) {
                if (cmps[i].Type__c!= 'table heading') {
                    return false;
                } 
    
                return true;
            }
        } else {
            return false;
        }
        
    }

    getEmptyFormData(cmp) {
        let data = {};
        data.Data_numeric__c = null;
        data.Data_text__c = null;
        data.Data_textarea__c = null;
        data.Form_Component__c = cmp.Id;
        data.Form_Instance__c = this.instanceId;
        data.Type__c = cmp.Type__c;
        return data;
    }

    buildConnectorSet() {
        for (let connector of this.connectorList) {
            //target can be either an item, or a component
            if (connector.Target_item__c) {
                this.connectorIdsSet.add(connector.Target_item__c);
            } else if (connector.Target_component__c) {
                this.connectorIdsSet.add(connector.Target_component__c);
            }
            //Source is always a component
            this.connectorIdsSet.add(connector.Source_component__c);
        }
    }

    updateItemWithConnectors(item) {
        if (this.connectorIdsSet.has(item.Id)) {  //check that this item has a relevant connector before looping through
            item.isTargetConnectors = [];
            for (let connector of this.connectorList) {
                if (connector.Target_item__c==item.Id) {
                    item.isTargetConnectors.push(connector);
                }
            }
        }
        return item;

    }

    updateCmpWithConnectors(cmp) {
        if (this.connectorIdsSet.has(cmp.Id)) {  //check that this item has a relevant connector before looping through
            cmp.isTargetConnectors = [];
            cmp.isSourceConnectors = [];
            for (let connector of this.connectorList) {
                if (connector.Target_component__c===cmp.Id) {
                    cmp.isTargetConnectors.push(connector);
                } else if (connector.Source_component__c===cmp.Id) {
                    cmp.isSourceConnectors.push(connector);
                }
            }
        }
        return cmp;
    }

    @api isValid() {
        let allValid = true;
        this.template.querySelectorAll('c-form-section').forEach(element => {
            if (element.isValid()!=true) {
                allValid = false;
            }
        });
        return allValid;
    
    }

}