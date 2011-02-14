// IFSubmitButton
// ---- constructor ----

IFSubmitButton = IF.extend(IFFormComponent, function(uniqueId, bindingName) {
    if (! this.register(uniqueId, bindingName)) {
        console.log("No submitbutton found with id "+uniqueId);
    }
    if (! this.element) {
        return false;
    }
    this._wasClicked = false;
    this._shouldValidateForm = 1;
    this._clientOnClickHandler = false;
    
    jQuery(this.element).click(function() { return this.controller.onClick(); });
});

IFSubmitButton.prototype.onClick = function() {
    if (this._wasClicked && this.canOnlyBeClickedOnce()) {
        // we need some kind off error here, but what's the
        // best way to do it?

        return false;
    }
    if (this._clientOnClickHandler) {
        if (! this._clientOnClickHandler()) {
            return false;
        }
    }
    // we should let the form do this
    //this.setValue(this._alternateValue);
    this.setWasClicked(true);
    this.form.controller._whoSubmitted = this;
    return true;
};
        
IFSubmitButton.prototype.canOnlyBeClickedOnce = function() {
    return this._canOnlyBeClickedOnce;
};
        
IFSubmitButton.prototype.setCanOnlyBeClickedOnce = function(value) {
    this._canOnlyBeClickedOnce = value;
};
        
IFSubmitButton.prototype.wasClicked = function() {
    return this._wasClicked;
};
        
IFSubmitButton.prototype.setWasClicked = function(v) {
    this._wasClicked = v;
};
        
IFSubmitButton.prototype.updateButtonText = function() {
    this.setValue(this._alternateValue);
}
        
IFSubmitButton.prototype.updateButtonStatusForValidSubmission = function() {
    this.updateButtonText();
    if (this.canOnlyBeClickedOnce() ||
        this.form.controller.canOnlyBeSubmittedOnce()) {
        
        jQuery(this.element).hide();
        if (this._alternateValue) {
            //jQuery(this.element).before("<span>" + this._alternateValue + "</span>");
            jQuery(this.element).innerHtml = "<span>" + this._alternateValue + "</span>";
        }
        //alert("Hid button");
    }
};
        
IFSubmitButton.prototype.value = function() {
    return jQuery(this.element).val(); // just return the value of the label
};
    
IFSubmitButton.prototype.setValue = function(value) {
    jQuery(this.element).val(value);
};
        
IFSubmitButton.prototype.shouldValidateForm = function() {
    return this._shouldValidateForm;
};
        
IFSubmitButton.prototype.setShouldValidateForm = function(value) {
    this._shouldValidateForm = value;
}
        
IFSubmitButton.prototype.onClickHandler = function() {
    return this._clientOnClickHandler;
}
        
IFSubmitButton.prototype.setOnClickHandler = function(value) {
    this._clientOnClickHandler = value;
};
        
IFSubmitButton.prototype.alternateValue = function() {
    return this._alternateValue; 
};
    
IFSubmitButton.prototype.setAlternateValue = function(value) {
    this._alternateValue = value;
};

