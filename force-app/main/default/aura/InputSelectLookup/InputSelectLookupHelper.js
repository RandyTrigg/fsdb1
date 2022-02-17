({
    init : function(cmp) {
        console.log('InputSelectLookupHelper init');
        this.displayAttributes(cmp);
    },
    getValue : function(cmp, event) {
        // Lookup Id for selected option
        var sel = event.target.value;
        var map = cmp.get("v.idNameMap");
        cmp.set("v.selected", sel);
        for (i in map) {
            if (map[i] == sel) return i;
        }
        return null;
    }
})