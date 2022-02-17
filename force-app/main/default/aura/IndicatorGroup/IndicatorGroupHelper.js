({
	init : function(cmp) {
        console.log('IndicatorGroupHelper init');
		this.insertIndicatorComponents(cmp);
	},
    insertIndicatorComponents : function(cmp) {
        var _this = this;
        console.log('IndicatorGroupHelper insertIndicatorComponents: ...');
        var comps = cmp.get("v.rawComponents");
        console.log('IndicatorGroupHelper insertIndicatorComponents: comps = ' +JSON.stringify(comps));
        if (comps.length > 0) {
            $A.createComponents(comps, function(components, status) {
                if (status == "SUCCESS") {
                    console.log('IndicatorGroupHelper insertIndicatorComponents: status = ' +status+ '; components.length = ' +components.length);
                    cmp.set("v.indicatorComponents", components);
                } else {
                    console.log('IndicatorGroupHelper insertIndicatorComponents: status = ' +status+ '; components.length = ' +components.length);
                }
            });
        }
    },
})