// This fairly empty class just provides a harness
// for you to implement your own custom validation
// on your components

function IFValidator(validationFn) {
	if (validationFn) { this.hasValidValues = validationFn }
};

IFValidator.prototype = {
	
	// this is what you'll need to override
	hasValidValues: function(object) {
		if (object.isRequired() && !object.value()) {
			return false;
		}
		return true;
	},

	// Another light implementation... your component
	// or your validator will most probably override this.
	indicateValidationFailure: function(c) {
		c.indicateValidationFailure(c);
	}
	
};

// useful static methods
IFValidator.isValidEmailAddress = function(v) {
	var re = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/;
//	var re = /^[\w-]+(\.[\w-]+)*\+?(\.[\w-]+)?@([\w-]+\.)+[a-zA-Z]{2,7}$/;
	return v.match(re);
};

IFValidator.isNumber = function(v) {
	var re = /^\d+(\.\d+)?$/;
	return n.match(re);
};
