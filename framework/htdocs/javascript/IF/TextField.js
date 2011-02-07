// IFTextField
// This componentises the behaviour of a simple text field, so
// that the field can be manipulated by the client-side framework
// if needed.

// ---- constructor ----


IFTextField = IF.extend(IFFormComponent, function(uniqueId, bindingName) {
	if (! this.register(uniqueId, bindingName)) {
		console.log("No textfield found with id "+uniqueId);
	}
});

IFTextField.prototype.value = function() {
    return jQuery(this.element).val(); 
};

IFTextField.prototype.setValue = function(value) {
    jQuery(this.element).val(value);
};

