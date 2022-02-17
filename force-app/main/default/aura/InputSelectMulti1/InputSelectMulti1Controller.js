({
	doInit : function(cmp, event, helper) {
        helper.init(cmp);		
	},
    errorMessageChange : function(cmp, event, helper) {
        helper.errorMessageChange(cmp, event);
    },
    // User selected an option among the unselected list (presumably to select it).
    setUnselectedsChosen : function(component, event, helper) {
        component.set("v.unselectedsChosen", component.find("mUnselecteds").get("v.value"));
        console.log('setUnselectedsChosen: v.unselectedsChosen = ' +component.get("v.unselectedsChosen"));
    },
    // User selected an option among the selected list (presumably to unselect it).
    setSelectedsChosen : function(component, event, helper) {
        component.set("v.selectedsChosen", component.find("mSelecteds").get("v.value"));
        console.log('setSelectedsChosen: v.selectedsChosen = ' +component.get("v.selectedsChosen"));
    },
    selectChosen : function(component, event, helper) {
        console.log('selectChosen in controller');
        helper.selectChosen(component);
    },
    unselectChosen : function(component, event, helper) {
        console.log('unselectChosen in controller');
        helper.unselectChosen(component);
    },
})