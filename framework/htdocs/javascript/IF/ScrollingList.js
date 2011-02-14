// IFScrollingList
// This componentises the behaviour of a pop up menu

// ---- constructor ----


IFScrollingList = IF.extend(IFFormComponent, function(uniqueId, bindingName) {
    if (! this.register(uniqueId, bindingName)) {
        console.log("No scrolling list found with id "+uniqueId);
    }
    // grab the popUpMenu component and remember its element
    var els = IFForm.formElementsBelowElement(this.element);
    this._selection = els[0];
});

IFScrollingList.prototype.value = function() {
    return IFForm.valuesOfSelect(this._selection); // just return the value of the actual text box
};
    
IFScrollingList.prototype.setValue = function(value) {
    IFForm.setValuesOfSelect(value, this._selection);
};
