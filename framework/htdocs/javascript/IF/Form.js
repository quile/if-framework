// Form: this js class attempts to model the client-side
// behaviour of HTML forms.  It is bound directly into the
// DOM tree as the "controller" property of the
// FORM tag that it is controlling.  Enclosed Form Components 
// that comply with its basic API will be accessible to it
// and it will be able to perform validation, manipulation, etc
// of the values.

// initialise variables if they haven't been initialised yet
if (! IF._registeredFormsById) {
	IF._registeredFormsByBindingName = new Object();
	IF._registeredFormsById = new Object();
}

// This is the guts of the Form class
// ---- constructor ----

function IFForm(uniqueId, bindingName) {
	this.uniqueId = uniqueId;
	this.bindingName = bindingName;
	this._submitted = 0;
	this._components = new Array();
	this._componentsById = new Object();
	this._componentsByBindingName = new Object();
	this.element = jQuery('#'+uniqueId).get(0);
	if (!this.element) {
		console.log("No form found with id " + uniqueId);
	}
	this.element.controller = this;
	IFForm.registerForm(this);

	jQuery(this.element).submit(function() { 
		return this.controller.onSubmit() 
	});
}

IFForm.prototype = {
		
	// components are the really interesting things:
	registerFormComponent: function(component) {
		if (!component) { return; }

		this._components[this._components.length] = component;
		this._componentsById[component.uniqueId] = component;
		
		if (this._componentsByBindingName[component.bindingName]) {
			var l = this._componentsByBindingName[component.bindingName].length;
			this._componentsByBindingName[component.bindingName][l] = component;		
		} else {
			this._componentsByBindingName[component.bindingName] = [component];
		}
		
		//console.log("--- registering component " + component.bindingName());
	},
	
	bestMatchingFormComponentWithBindingName: function(name) {
		var matches = [];
		for (var i=0; i< this.components().length; i++) {
			var c = this.components()[i];
			var index = c.bindingName.indexOf(name)
			if (index == 0) {
				// exact match
				return c;
			} else if (index > 0) {
				matches[matches.length] = c;
			}
		}
		return matches[0]; // cheesy for now
	},
	
	formComponentWithBindingName: function(name) {
		return this.bestMatchingFormComponentWithBindingName(name);
	},
	
	formComponentWithId: function(id) {
		return this._componentsById[id];
	},
	
	components: function() {
		return this._components;
	},
	
	// components need to written to have
	// controllers associated with them.
	// if they do, then their object is called
	// to get the value of the component.
	valueOfFormComponent: function(component) {
		if (!component) { return null; }
		return component.value();
	},
	
	// these are for callbacks, etc.
	onSubmit: function() {
		if (this._submitted && this.canOnlyBeSubmittedOnce()) {
			// we need some kind of error here, but what's the
			// best way to do it?
			return false;
		}
		
		this._submitted++;
		var isOk;
		if (this._whoSubmitted && (! this._whoSubmitted.shouldValidateForm())) {
			isOk = true;
		} else {
			isOk = this.hasValidValues();
		}
		if(this._whoSubmitted) {
			if (!isOk) {
				this._whoSubmitted.setWasClicked(false);
			} else {
				this._whoSubmitted.updateButtonStatusForValidSubmission();
			}
		}

		// handle a post validation event if there is one 
		// and validation succeeded
		if (isOk && this._postValidationEventListener) {
			isOk = this._postValidationEventListener.call();
		}	
		this._whoSubmitted = null;
		// remember to 'unsubmit' the form if the validation failed. 
		if (!isOk) {
			this._submitted--;
		}
		return isOk;
	},
	
	// TODO: do we only need one validation method?
	hasValidValues: function() {
		console.log("Checking validation on all form components");
		var isOk = true;
		var validationFailedComponents = new Array();
		jQuery.each(this.components(),
			function () {
				if (this.validator().hasValidValues && (jQuery(this.element).is(':visible') || this.validator()._shouldAlwaysValidate)) {
					var cOk = this.validator().hasValidValues(this);
					if (!cOk) { validationFailedComponents.push(this); }
				}
			});
		if (validationFailedComponents.length) { isOk = false; }
		
		jQuery.each(validationFailedComponents,
			function() {
				this.validator().indicateValidationFailure(this);
				console.log("Validation failed on " + this.bindingName + "/" + this.uniqueId);			
			});
		
		if (! isOk) {
			var top = this.getTopElement(validationFailedComponents);
			jQuery('html,body').focus().animate({scrollTop: jQuery(top.element).offset().top - 25}, 700);
		}
		console.log("Validation returned " + isOk);
		return isOk;
	},
	
	getTopElement: function(controllers) {
		var start = jQuery(controllers[0].element).offset();
		var winner = { offset: start, controller: controllers[0]};
		jQuery.each(controllers, function() {
			var ofs = jQuery(this.element).offset();
			if ((ofs.top < winner.offset.top) && (ofs.left < winner.offset.left)) {
				winner.offset = ofs;
				winner.controller = this;
			} 
		});
		return winner.controller;
	},
	
	canOnlyBeSubmittedOnce: function() {
		return this._canOnlyBeSubmittedOnce;
	},
	
	setCanOnlyBeSubmittedOnce: function(value) {
		this._canOnlyBeSubmittedOnce = value;
	},
	
	validationFunction: function() {
		return this._validationFunction;
	},
	
	setValidationFunction: function(f) {
		this._validationFunction = f;
	},

	// so a form can have its own error messages that it can share
	// with its form elements.
	errorMessageForKey: function(key) {
		var em = this.errorMessages()[key];
		if (!em) {
			return key;
		}
		return em;
	},
	
	setErrorMessageForKey: function(msg, key) {
		this.errorMessages()[key] = msg;
	},
	
	errorMessages: function() {
		if (!this._errorMessages) {
			this._errorMessages = new Array();
		}
		return this._errorMessages;
	},
		
	// not sure what this should do... maybe the whole thing serialized?
	//value: function() {
	//	return this.objects;
	//},
	
	registerPostValidationEventListener: function(handler) {
		this._postValidationEventListener = handler;
	}
	//---

};

// class methods

IFForm.parentFormOfElement = function(element) {
	return jQuery(element).parents().filter('form')[0];
}

// These handle registration in a page of form components.
IFForm.registerFormComponent = function(component) {
	if (!component) { return; }
	var element;
	if (component.element) {
		element = component.element;
	}
	if (!element) { console.log("Component doesn't have an element property"); return; }
	
	var form = IFForm.parentFormOfElement(element);
	if (!form) { console.log("Couldn't find parent form for " + element.id); return; }
	var controller = form.controller;
	if (!controller) { 
		console.log("Form has no controller object ("+element.controller.bindingName+"), triggering form enumeration"); 
		IF.buildFormControllers();
		controller = form.controller;
	}
	if (!controller) { 
		console.log("Form still has no controller object ("+element.controller.bindingName+"), giving up"); 
		return; 
	}
	controller.registerFormComponent(element.controller);
	
	component.form = form;
}

// IFForm keeps a registry of all the forms in the page, which can be
// accessed by binding name or uniqueId
IFForm.registerForm = function(f) {
	IF._registeredFormsByBindingName[f.bindingName] = f;
	IF._registeredFormsById[f.uniqueId] = f;
}

IFForm.dumpAllForms = function() {
	for (var bindingName in IF._registeredFormsByBindingName) {
		console.log('FORM:  ' + bindingName);
		var form = IFForm.formWithBindingName(bindingName);
		var components = form.components();
		for (var i=0; i < components.length; i++) {
			var component = components[i];
			console.log('--COMPONENT (' + component.element.type + '):  ' + component.bindingName);
		}
	}
}

IFForm.formWithBindingName = function(name) {
	var matches = [];
	for (var i in IF._registeredFormsByBindingName) {
		if (i.indexOf(name) >= 0) {
			matches[matches.length] = i;
		}
	}
	return IF._registeredFormsByBindingName[matches[0]];
}

IFForm.formWithId = function(id) {
	return IF._registeredFormsById[id];
}

// this breaks the naming rules but it's just to make client code cleaner
IFForm.formComponentInForm = function(componentName, formName) {
	var form = IFForm.formWithBindingName(formName);
	if (form) {
		return form.formComponentWithBindingName(componentName);
	}
	console.log("No such form: " + formName);
	return;
}

// static functions for backwards compatibility
// these have been moved under the namespace IFForm,
// but there are plain old methods for compatibility
// that forward the calls to the right place.  These
// will be removed once the older code is ported.

IFForm.formElementsBelowElement = function(element) {
	return jQuery(element).find(':input');
}
formElementsBelowElement = IFForm.formElementsBelowElement;

//---------------------------------------------------
IFForm.setValueOfFormElement = function(value, element) {
	//alert("setting value for form element " + element);
	if (element) {
		switch (element.type) {
			case "text":
			case "textarea":
			case "hidden":
			case "select-one":
			case "select-multiple":
				jQuery(element).val(value);
				break;
			case "checkbox":
				IFForm.setValuesOfCheckBoxGroup(value, element);
				break;
			case "radio":
				IFForm.setValuesOfRadioButtonGroup(value, element);
				break;
			default:
				alert("something else! " + element.type);
				break;
		}
	}
}
function setValueOfFormElement(value, element) {
	return IFForm.setValueOfFormElement(value, element);
}
//---------------------------------------------------

//---------------------------------------------------
IFForm.cleanUpReturnValue = function(value) {
	if (value == "undefined" || !value) {
		return '';
	}
	return value;
}
cleanUpReturnValue = IFForm.cleanUpReturnValue;
//---------------------------------------------------

//---------------------------------------------------
IFForm.valueOfFormElement = function(element) {
	if (element) {
		switch (element.type) {
			case "text":
			case "textarea":
			case "hidden":
			case "select-one":
			case "select-multiple":
				return cleanUpReturnValue(jQuery(element).val());
				break;
			case "checkbox":
				return cleanUpReturnValue(valueOfCheckBoxGroup(element));
				break;
			case "radio":
				return cleanUpReturnValue(valueOfRadioButtonGroup(element));
				break;
			default:
				//alert("something else! " + element.type);
				break;
		}
	}
}
valueOfFormElement = IFForm.valueOfFormElement;

IFForm.valueOfTextField = function(textfield) {
	return jQuery(textfield).val();
}
valueOfTextField = IFForm.valueOfTextField;

IFForm.setValueOfTextField = function(value, textfield) {
	if (! jQuery(textfield).val(value).size() ) {
		console.log("can't find text field " + textfield);
	}
}
setValueOfTextField = IFForm.setValueOfTextField;

IFForm.valueOfSelect = function(select) {
	return jQuery(select).val()[0];
}
valueOfSelect = IFForm.valueOfSelect;

IFForm.valuesOfSelect = function(select) {
	return jQuery(select).val();
}
valuesOfSelect = IFForm.valuesOfSelect;

IFForm.setValueOfSelect = function(value, select) {
	if (! jQuery(select).val(value).size() ) {
		console.log("can't find select " + select);
	}
}
setValueOfSelect = IFForm.setValueOfSelect;

IFForm.setValuesOfSelect = function(values, select) {
	if (! jQuery(select).val(values).size() ) {
		console.log("can't find select " + select);
	}
}
setValuesOfSelect = IFForm.setValuesOfSelect;

IFForm.valuesOfCheckBoxGroup = function(element) {
	var values = [];
	jQuery(element).find('input:checked').each(function() { values.push(this.value) } );
	return values;
}
valuesOfCheckBoxGroup = IFForm.valuesOfCheckBoxGroup;

IFForm.setValuesOfCheckBoxGroup = function(values, group) {
	if (! jQuery(group).find(':checkbox').val(values).size() ) {
		console.log("can't find checkbox group " + group);
	}
}
setValuesOfCheckBoxGroup = IFForm.setValuesOfCheckBoxGroup;

IFForm.checkedStateOfCheckBox = function(box) {
	return jQuery(box).val();
}
checkedStateOfCheckBox = IFForm.checkedStateOfCheckBox;

IFForm.setCheckedStateOfCheckBox = function(value, box) {
	if (! jQuery(box).val(value).size() ) {
		alert("Couldn't find checkbox " + box);
	}
}
setCheckedStateOfCheckBox = IFForm.setCheckedStateOfCheckBox;

IFForm.valueOfRadioButtonGroup = function(element) {
	return jQuery(element).find(':radio:checked').val();
}
valueOfRadioButtonGroup = IFForm.valueOfRadioButtonGroup;

IFForm.setValueOfRadioButtonGroup = function(value, group) {
	if (!jQuery(group).find(':radio').val([value]).size() ) {
		alert("Couldn't find radio button group " + group);
	}
}
setValueOfRadioButtonGroup = IFForm.setValueOfRadioButtonGroup;