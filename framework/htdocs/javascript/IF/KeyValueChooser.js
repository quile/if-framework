// KeyValueChooser

KeyValueChooser = IF.extend(IFFormComponent, function(uniqueId, bindingName) {
    this.uniqueId = uniqueId;
    this.bindingName = bindingName;
    this.element = jQuery('#'+uniqueId)[0];
    if (!this.element) {
        console.log("No textfield found with id "+uniqueId);
    }
    this.element.controller = this;
    
    // grab the popUpMenu component and remember its element
    var els = IFForm.formElementsBelowElement(this.element);
    this._select = els[0];
    
    IFForm.registerFormComponent(this);
});

KeyValueChooser.prototype.value = function() {
    return IFForm.valueOfFormElement(this._select); // just return the value of the actual text box
};
    
KeyValueChooser.prototype.setValue = function(value) {
    IFForm.setValueOfFormElement(this._select, value);
};
