({
    afterRender : function(cmp, helper) {
        this.superAfterRender (cmp, helper);
        // Set checked property of checkbox appropriately.
        var elem = cmp.find("inputTag").getElement();
        elem.checked = cmp.get("v.value");
        //console.log('afterRender override after setting checkbox to ' +cmp.get("v.value"));
    },
})