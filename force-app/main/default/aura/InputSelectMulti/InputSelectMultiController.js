({
	doInit : function(component, event, helper) {
        helper.init(component);		
	},
    errorMessageChange : function(component, event, helper) {
        helper.errorMessageChange(component, event);
    },
    // User selected an option among the unselected list (presumably to select it).
    setUnselectedsChosen : function(component, event, helper) {
        component.set("v.unselectedsChosen", event.target.textContent);
        console.log('setUnselectedsChosen: v.unselectedsChosen = ' +component.get("v.unselectedsChosen"));
    },
    // User selected an option among the selected list (presumably to unselect it).
    setSelectedsChosen : function(component, event, helper) {
        //console.log('setSelectedsChosen: event.target.textContent = ' +event.target.textContent);
        component.set("v.selectedsChosen", event.target.textContent);
    },
    selectChosen : function(component, event, helper) {
        console.log('selectChosen in controller');
        helper.doSelectChosen(component);
    },
    unselectChosen : function(component, event, helper) {
        helper.doUnselectChosen(component);
    },
})