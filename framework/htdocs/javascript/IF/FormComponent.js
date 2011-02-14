// This is NOT a "FORM" component in the
// sense you might think: that is Form.js.
// This is a component that >belongs< to a
// form (eg. TextField, Text, SubmitButton, etc.)
// but since it can be arbitrarily complex,
// I can't call it FormElement, because that
// would be misleading too.

function IFFormComponent() {
    
};
        
IFFormComponent.prototype.register = function(uniqueId, bindingName) {
    this.uniqueId = uniqueId;
    this.bindingName = bindingName;
    this.errorMessages = {};
    this.element = jQuery('#'+uniqueId)[0];
    if (! this.element) { return false; }
    this.element.controller = this;
    IFForm.registerFormComponent(this);
    return true;
};        
        
IFFormComponent.prototype.requiredErrorMessage = function() {
    return this.errorMessageForKey("IS_REQUIRED");
};
        
IFFormComponent.prototype.setRequiredErrorMessage = function(msg) {
    this.setErrorMessageForKey(msg, "IS_REQUIRED");
};
        
        // the default implementation of this will just check for a simple
        // value and if the field is required, it will return false.
        // Note that this default implementation won't work with complex
        // FormComponent subclasses that return objects.
IFFormComponent.prototype.hasValidValues = function() {
    if (this.isRequired() && !this.value()) {
        return false;
    }
    return true;
};
        
        // Another light implementation:
        // TODO: fix this to work with >different< validation failures
IFFormComponent.prototype.indicateValidationFailure = function() {
    if (!this._backupStyle) {
        this._backupStyle = {
            //backgroundColor: c.element.style.backgroundColor,
            border: jQuery(this.element).css('border')
        };
    }
    if (! this._backupStyle['border']) { this._backupStyle['border'] = '' };
    jQuery(this.element).css('border', "1px solid red");
    
    // special case that should work with most components:
    if (this.isRequired() && !this.value() && this.requiredErrorMessage()) {
        this.displayErrorMessage(this.requiredErrorMessage());
    }
    var _backupStyle = this._backupStyle;
    jQuery(this.element).one('change', function() { 
        jQuery(this).css(_backupStyle);    
        jQuery('#'+this.controller.uniqueId + "-error").html('').hide();
     });
    jQuery(this.element).one('keypress', function() { 
        jQuery(this).css(_backupStyle);    
        jQuery('#'+this.controller.uniqueId + "-error").html('').hide();    
    });
};

IFFormComponent.prototype.removeValidationFailure = function(c) {
    c.removeValidationFailureMessage();
    jQuery(c.element).css(c._backupStyle);
};
        
IFFormComponent.prototype.bindChangeEvents = function() {
//    jQuery(this.element).once('change', this, this.removeValidationFailure);
//    jQuery(this.element).once('keydown', this, this.removeValidationFailure);
};
        
IFFormComponent.prototype.displayValidationFailureMessage = function(msg) {
    this.displayErrorMessage(msg);
};
        
IFFormComponent.prototype.removeValidationFailureMessage = function() {
    jQuery('#'+this.uniqueId + "-error").html('').hide('normal');
};
        
IFFormComponent.prototype.displayErrorMessage = function(msg) {
    jQuery('#'+this.uniqueId + "-error").html(msg).show('normal').css("error");
};
        
IFFormComponent.prototype.displayErrorMessageForKey = function(key) {
    this.displayErrorMessage(this.errorMessageForKey(key));
};
        
IFFormComponent.prototype.errorMessageForKey = function(key) {
    var em = this.errorMessages[key];
    if (!em) {
        em = this.form.controller.errorMessageForKey(key);
        if (!em) { return key; }
    }
    return em;
};
        
IFFormComponent.prototype.setErrorMessageForKey = function(msg, key) {
    this.errorMessages[key] = msg;
};

IFFormComponent.prototype.isRequired = function() {
    return this._isRequired;
};

IFFormComponent.prototype.setIsRequired = function(value) {
    this._isRequired = value;
};

IFFormComponent.prototype.validator = function() {
    if (this._validator) { return this._validator; }
    return this;
};

IFFormComponent.prototype.setValidator = function(value) {
    this._validator = value;
};
