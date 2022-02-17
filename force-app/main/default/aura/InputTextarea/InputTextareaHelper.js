({
    init : function(cmp) {
        console.log('InputTextareaHelper init');
        this.displayAttributes(cmp);
    },
    getValue : function(cmp, event) {
        return cmp.find("inputTag").get("v.value");
    },
})