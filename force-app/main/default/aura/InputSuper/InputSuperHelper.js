({
    displayAttributes : function(cmp) {
        console.log('InputSuperHelper init: label = ' +cmp.get("v.label")+ '; type = ' +cmp.get("v.type")+ '; value = ' +cmp.get("v.value"));
    },
    saveChange : function(cmp, event) {
        console.log('InputSuperHelper saveChange before: cmp.get("v.value") = ' +cmp.get("v.value"));
        var val = this.getValue(cmp, event);
        // The non-null test is meant to preserve empty string values in val.
        var valString = val != null ? val.toString() : null;
        console.log('InputSuperHelper saveChange before: cmp.get("v.value") = ' +cmp.get("v.value")+'; valString = ' +valString);
        console.log('InputSuperHelper saveChange before: typeof(cmp.get("v.value")) = ' +typeof(cmp.get("v.value"))+'; typeof(valString) = ' +typeof(valString));
        // Update the 'value' attribute of the enclosing component if necessary.
        var curCmpValueAsString = cmp.get("v.value") ? cmp.get("v.value").toString() : null;
        if(curCmpValueAsString != valString) cmp.set("v.value", valString);
        console.log('InputSuperHelper saveChange after: cmp.get("v.value") = ' +cmp.get("v.value"));
    },
    // Overwrite this function in sub-component as necessary.
    getValue : function(cmp, event) {
        return cmp.get("v.value");
    },
})