IFEmailField = IF.extend(IFFormComponent, function(uniqueId, bindingName) {
    if (! this.register(uniqueId, bindingName)) {
        console.log("No email field found with id "+uniqueId);
    }
},
{        
    hasValidValues: function(c) {
        console.log("Validating email field with value " + c.value());
        // If the value is empty, then it doesn't validate the email. (isRequired function instead) -lg i-1446
        if (c.value() && !IFValidator.isValidEmailAddress(c.value())) {
            c.indicateValidationFailure();
            c.displayErrorMessageForKey("VALID_EMAIL_REQUIRED");
            return false;
        }
           if (c.isRequired() && !c.value()) {
               return false;
           }
        return true;
    },
    
    // these accessors are mandatory for any component that wants to interact
    // with its form.
    value: function() {
        return this.element.value; // just return the value of the actual text box
    },

    setValue: function(value) {
        this.element.value = value;
    }
});
