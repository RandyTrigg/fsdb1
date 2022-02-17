({
    init : function(cmp, event) {
        console.log('InputIndicatorHelper init...');
        // Set the value attribute in the component.
        this.saveChange(cmp, event);
        //this.hideSubComponents(cmp);
    },
    // Hide the quantity/comment sub-components if necessary.
    hideSubComponents : function(cmp) {
        console.log('InputIndicatorHelper hideSubComponents...');
        if (!cmp.get("v.requiresQuantity")) $A.util.addClass(cmp.find("Quantity"), 'hidden');
        if (!cmp.get("v.requiresComment")) $A.util.addClass(cmp.find("Comment"), 'hidden');
    },
    getValue : function(cmp, event) {
        // Lookup the current values of the three components: checkbox, quantity, and comment
        var checked = cmp.find("Selected").get("v.value");
        var qVal = cmp.find("Quantity").get("v.value");
        var cVal = cmp.find("Comment").get("v.value");
        var quantity = cmp.get("v.requiresQuantity") && qVal ? qVal : '';
        var comment = cmp.get("v.requiresComment") && cVal ? cVal : '';
        // Update attributes if necessary.
        if (cmp.get("v.valueQuantity") != quantity) cmp.set("v.valueQuantity", quantity);
        if (cmp.get("v.valueComment") != comment) cmp.set("v.valueComment", comment);
        console.log('InputIndicatorHelper getValue: cmp.get("v.fieldName") = ' +cmp.get("v.fieldName")+ '; checked = ' +checked+ '; quantity = ' +quantity+ '; comment = ' +comment);
        // Return empty string if not checked, else combine quantity with comment, capping comment at 255 chars.
        return checked ? quantity +";"+ comment.substring(0, 255) : '';
    },
})