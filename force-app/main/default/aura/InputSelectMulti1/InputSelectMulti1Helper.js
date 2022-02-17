({
    init : function(cmp) {
        console.log('InputSelectMultiHelper init: unselecteds = ' +JSON.stringify(cmp.get("v.unselecteds")));
        this.displayAttributes(cmp);
        // Set the options in the two picklists based on unselected and selected terms.
        this.setOptions(cmp);
    },
	errorMessageChange : function(cmp, event) {
        console.log('InputFieldSuperHelper errorMessageChange');
        if(cmp.get("v.errorMessage")) {
            $A.util.addClass(cmp.find("formElement"), 'slds-has-error');
            $A.util.removeClass(cmp.find("errorSpan"), 'slds-hide');
        } else {
            $A.util.removeClass(cmp.find("formElement"), 'slds-has-error');
            $A.util.addClass(cmp.find("errorSpan"), 'slds-hide'); 
        }
	},
    // Move any chosen unselected options from unselected to selected.
    selectChosen : function(cmp) {
        // Add chosen elements to the selecteds list.
        var chosen = cmp.find("mUnselecteds").get("v.value").split(";");
        if (chosen.length > 0) {
            console.log('selectChosen: chosen = ' +chosen);
            cmp.set("v.selecteds", this.addToArray(cmp.get("v.selecteds"), chosen));
            // Remove chosen elements from the unselecteds list.
            cmp.set("v.unselecteds", this.removeFromArray(cmp.get("v.unselecteds"), chosen));
            // Rebuild the options in the picklists.
            this.setOptions(cmp);
            // User super's help function to compute new value of this component.
            this.saveChange(cmp);
        }
    },
    // Move any chosen selected options from selected to unselected.
    unselectChosen : function(cmp) {
        // Add chosen elements to the unselecteds list.
        var chosen = cmp.find("mSelecteds").get("v.value").split(";");
        if (chosen.length > 0) {
            console.log('unselectChosen: chosen = ' +chosen);
            cmp.set("v.unselecteds", this.addToArray(cmp.get("v.unselecteds"), chosen));
            // Remove chosen elements from the selecteds list.
            cmp.set("v.selecteds", this.removeFromArray(cmp.get("v.selecteds"), chosen));
            // Rebuild the options in the picklists.
            this.setOptions(cmp);
            // User super's help function to compute new value of this component.
            this.saveChange(cmp);
        }
    },
    addToArray : function(arr, elements) {
        console.log('addToArray: elements = ' +JSON.stringify(elements)+ '; arr = ' +JSON.stringify(arr));
        for (var i=0; i<elements.length; i++) 
            if(arr.indexOf(elements[i]) == -1) arr.push(elements[i]);
        return arr;
    },
    removeFromArray : function(arr, elements) {
        console.log('removeFromArray: element = ' +JSON.stringify(elements)+ '; arr = ' +JSON.stringify(arr));
        var result = [];
        for (var i=0; i<arr.length; i++)
            if (elements.indexOf(arr[i]) == -1) result.push(arr[i]);
        console.log('removeFromArray: result = ' +JSON.stringify(result));
        return result;
    },
    // Set the options of the ui:inputSelect picklists based on the current selected and unselected terms.
    setOptions : function(cmp) {
        var unselOpts = [];
		var selOpts = [];
        var unselecteds = cmp.get("v.unselecteds");
        var selecteds = cmp.get("v.selecteds");
        for (var i=0; i<unselecteds.length; i++)
            unselOpts.push({"class": "optionClass", label: unselecteds[i], value: unselecteds[i]});
        for (var i=0; i<selecteds.length; i++)
            selOpts.push({"class": "optionClass", label: selecteds[i], value: selecteds[i]});
        cmp.find("mUnselecteds").set("v.options", unselOpts);
        cmp.find("mSelecteds").set("v.options", selOpts);
        // Reset "chosen" attributes.
        cmp.set("v.unselectedsChosen", cmp.find("mUnselecteds").get("v.value"));
        cmp.set("v.selectedsChosen", cmp.find("mSelecteds").get("v.value"));
        //console.log('setOptions: v.unselectedsChosen = ' +cmp.get("v.unselectedsChosen"));
        //console.log('setOptions: v.selectedsChosen = ' +cmp.get("v.selectedsChosen"));
    },
    // 1/15/16: Haven't found a way to make this run up front, after window refresh.
    // If I could, then I wouldn't have to pass in the initial packed Ids list from the apex.
    getValue : function(cmp, event) {
        // Lookup Ids for selected options, and package as semi-colon separated list.
        var map = cmp.get("v.idNameMap");
        var selecteds = cmp.get("v.selecteds");
        console.log('InputSelectMultiHelper getValue: map = ' +JSON.stringify(map)+ '; selecteds = ' +JSON.stringify(selecteds));
        var ids = [];
        for (i in map) {
            console.log('InputSelectMultiHelper getValue in loop: i = ' +i+ '; ids = ' +JSON.stringify(ids));
            if (selecteds.indexOf(map[i]) > -1) ids.push(i);
        }
        console.log('InputSelectMultiHelper getValue END return value = ' +ids.join(';'));
        return ids.length > 0 ? ids.join(';') : '';
    }
})