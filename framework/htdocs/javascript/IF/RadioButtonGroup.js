// IFRadioButtonGroup
// This componentises the behaviour of a radio button group.
// This is a complicated one because HTML doesn't bind radio buttons very well together
// so many rb's in different forms could have the same name.
// ---- constructor ----


IFRadioButtonGroup = IF.extend(IFFormComponent,function(uniqueId, bindingName, name) {
	if (! this.register(uniqueId, bindingName)) {
		console.log("No checkbox group found with id "+uniqueId);
	}	
});

IFRadioButtonGroup.prototype.value = function() {
	return jQuery(this.element).find(':radio:checked').val();
};
	
IFRadioButtonGroup.prototype.setValue = function(value) {
	jQuery(this.element).find(':radio').val([value]).size() 
};
