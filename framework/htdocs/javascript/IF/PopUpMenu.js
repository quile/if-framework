// IFPopUpMenu
// This componentises the behaviour of a pop up menu

// ---- constructor ----


IFPopUpMenu = IF.extend(IFFormComponent, function(uniqueId, bindingName) {
    if (! this.register(uniqueId, bindingName)) {
        console.log("No popup menu found with id "+uniqueId);
    }

    // grab the popUpMenu component and remember its element
    var els = IFForm.formElementsBelowElement(this.element);
    this._selection = els[0];
});

IFPopUpMenu.prototype.value = function() {
    return IFForm.valueOfFormElement(this._selection); // just return the value of the actual text box
};
    
IFPopUpMenu.prototype.setValue = function(value) {
    IFForm.setValueOfFormElement(value, this._selection);
};
        
IFPopUpMenu.prototype.otherValue = function () {
    return this._otherValue;
};
        
IFPopUpMenu.prototype.setOtherValue = function (value) {
    this._otherValue = value;
};
        
IFPopUpMenu.prototype.otherTextField = function() {
    return this._otherTextField;
};
        
IFPopUpMenu.prototype.setOtherTextField = function(value) {
    this._otherTextField = value;
};
        
IFPopUpMenu.prototype.initializeOtherHandlingWithValueAndOtherValue = function(value, otherValue) {
    this.setOtherValue(otherValue);
    this._otherElement = jQuery('#OTHER_' + this.uniqueId)[0];
    this.setOtherTextField(IFForm.formElementsBelowElement(this._otherElement)[0]);
    Event.observe(this.uniqueId, 'change', this.toggleOtherBasedOnSelection.bindAsEventListener(this));
    // Check to see if selection value is found in the list        
    if (value != '') {
        var isFound = false;
        for (var i=0; i < this._selection.options.length; i++) {
            if (this._selection.options[i].value == value) {
                isFound = true;
                break;
            }
        }
        if (! isFound) {
            // Set the selection box to Other...
            this.setValue(otherValue);
            // ...and set the text box value 
            IFForm.setValueOfFormElement(value, this.otherTextField())
        } 
    }
    //Call this in case of the page being called using the back button
    this.toggleOtherBasedOnSelection();
};
        
IFPopUpMenu.prototype.toggleOtherBasedOnSelection = function(event) {
    if (this.otherValue() == this.value()) {
        this._otherElement.show();
        this.otherTextField().focus();
    } else {
        this._otherElement.hide();
    }
    
};