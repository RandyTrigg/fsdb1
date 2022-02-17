({
	afterRender : function(cmp, helper) {
    	var ret = this.superAfterRender();
        console.log('ProfileEdit afterRender start');
        // Add more components after rendering.
        //helper.insertExtraQuestions(cmp);
        console.log('ProfileEdit afterRender end');
    	return ret;
	}
})