({
    init : function(cmp) {
        console.log('InputSelectMultiHelper init: unselecteds = ' +JSON.stringify(cmp.get("v.unselecteds")));
        this.displayAttributes(cmp);
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
    // If there's a chosen unselected option, then move it from unselected to selected.
	doSelectChosen : function(cmp) {
		var chosen = cmp.get("v.unselectedsChosen");
        console.log('selectChosen: chosen = ' +chosen);
        if (chosen) {
            cmp.set("v.unselecteds", this.removeFromArray(cmp.get("v.unselecteds"), chosen));
            cmp.set("v.selecteds", this.addToArray(cmp.get("v.selecteds"), chosen));
            console.log('doSelectChosen before cmp.set of v.unselectedsChosen');
            cmp.set("v.unselectedsChosen", null);
            console.log('doSelectChosen after cmp.set of v.unselectedsChosen');
            this.saveChange(cmp);
        }
        console.log('selectChosen: v.unselecteds = ' +JSON.stringify(cmp.get("v.unselecteds")));
        console.log('selectChosen: v.selecteds = ' +JSON.stringify(cmp.get("v.selecteds")));
        //alert('doSelectChosen exit');
	},
    // If there's a chosen selected option, then move it from selected to unselected.
	doUnselectChosen : function(cmp) {
		var chosen = cmp.get("v.selectedsChosen");
        if (chosen) {
            cmp.set("v.selecteds", this.removeFromArray(cmp.get("v.selecteds"), chosen));
            cmp.set("v.unselecteds", this.addToArray(cmp.get("v.unselecteds"), chosen));
            cmp.set("v.selectedsChosen", null);
            this.saveChange(cmp);
        }
	},
    addToArray : function(arr, element) {
        console.log('addToArray: element = ' +element+ '; arr = ' +JSON.stringify(arr));
        arr.push(element);
        return arr;
    },
    removeFromArray : function(arr, element) {
        console.log('removeFromArray: element = ' +element+ '; arr = ' +JSON.stringify(arr));
        var result = [];
        arr.forEach(function (elm, index){
            if (elm != element) result.push(elm);
        });
        console.log('removeFromArray: result = ' +JSON.stringify(result));
        return result;
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