({
    init : function(cmp) {
        console.log('InputSelectHelper init');
        this.displayAttributes(cmp);
    },
    getValue : function(cmp, event) {
        return event.target.value;
    }
})