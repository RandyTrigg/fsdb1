({
    init : function(cmp) {
        console.log('InputTextHelper init');
        this.displayAttributes(cmp);
    },
    getValue : function(cmp, event) {
        // Remove non-digits from value before returning.
        return cmp.find("inputTag").get("v.value").replace( /^\D+/g, '');
    },
})