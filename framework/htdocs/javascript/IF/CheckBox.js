// IFCheckBox
// This componentises the behaviour of a checkbox single checkbox.
// Note that checkbox components are NOT used by the checkbox
// group component; it renders its own checkboxes.

IFCheckBox = IF.extend(IFFormComponent, function(uniqueId, bindingName) {
	if (! uniqueId) return;
	if (! this.register(uniqueId, bindingName)) {
		console.log("No checkbox found with id " + uniqueId);
	}	
});

IFCheckBox.prototype.indicateValidationFailure = function() {
	jQuery(this.element).wrap("<span style='border: 2px solid red'></span>");
	jQuery(this.element).one('change', function() { 
		this.controller.removeValidationFailure();
	 });
	this.displayErrorMessage(this.requiredErrorMessage());	
}

IFCheckBox.prototype.removeValidationFailure = function() {
	jQuery(this.element).parent().css({ 'border': '0px' });	
	this.removeValidationFailureMessage();
}

IFCheckBox.prototype.value = function() {
	return jQuery(this.element).is(':checked'); 
};
	
IFCheckBox.prototype.setValue = function(value) {
	jQuery(this.element).attr('checked',value);
};
