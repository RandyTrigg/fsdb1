({
    init : function(cmp) {
        console.log('InputCheckboxHelper init');
        this.displayAttributes(cmp);
    },
    getValue : function(cmp, event) {
        //return cmp.get("v.checked");
        var inputCmp = cmp.find("inputTag");
        var checkboxVal = inputCmp.getElement().checked;
        console.log('InputCheckbox getValue: checkboxVal = ' +checkboxVal+ '; cmp.get("v.value") = ' +cmp.get("v.value"));
        return checkboxVal;
    },
})