// IFCheckBoxGroup
// This componentises the behaviour of a checkbox group.
// This is a complicated one because HTML doesn't bind checkboxes very well together
// so many checkboxes in different forms could have the same name.
// ---- constructor ----


IFCheckBoxGroup = IF.extend(IFFormComponent, function(uniqueId, bindingName, name) {
    if (! this.register(uniqueId, bindingName)) {
        console.log("No checkbox group found with id "+uniqueId);
    }
});
    
IFCheckBoxGroup.prototype.value = function() {
    return IFForm.valuesOfCheckBoxGroup(this.element);
};
    
IFCheckBoxGroup.prototype.setValue = function(value) {
    IFForm.setValuesOfCheckBoxGroup(value, this.element);
};
