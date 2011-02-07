// IFClientSideConditional
if (! IF._registeredConditionals) {
	IF._registeredConditionalsByBindingName = Object();
}
// ---- constructor ----

IFClientSideConditional = IF.extend(IFComponent, function(uniqueId, bindingName, expressionFunction) {
	this.expressionFunction = expressionFunction;
	this.uniqueId = uniqueId;
	this.bindingName = bindingName;
	this.element = jQuery('#'+uniqueId)[0];
	if (!this.element) {
		console.log("No ClientSideConditional found with id "+uniqueId);
		return;
	}          
	this.element.controller = this;
},
{
	evaluate: function() {
		return this.expressionFunction.call(window);
	},
	
	refresh: function() {
		var val = this.evaluate();
		if (val) {
			jQuery(this.element).show();
		} /* else {
			jQuery(this.element).hide();
		} */
		// not sure why this had two parts... seems that it should only show things that
		// are pre-hidden.
	}
});

IFClientSideConditional.registerConditional = function(c) {
	IF._registeredConditionalsByBindingName[c.bindingName] = c;
}

IFClientSideConditional.conditionalWithName = function(name) {
	// A bit dopey...finds the first that matches
	for (key in IF._registeredConditionalsByBindingName) {
		if (key.indexOf(name) >= 0) {
			return IF._registeredConditionalsByBindingName[key];
		}
	}
	console.log('Conditional with name (' + name + ') was not found');
}

