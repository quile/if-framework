if (typeof jQuery != 'undefined') {
	var $jq = jQuery.noConflict();
}
// make sure we can log to something, even if it's /dev/null
// because lame-ass JS doesn't have a standard way to write
// to a console.
if (typeof console == 'undefined') {
	console = new Object();
	jQuery.each(['trace','log','debug','info','warn','error','time','timeEnd','count'],
		function () { console[this] = function() {} });
}


// TODO - Insert the binding name into the title property
/// without bashing what's there
jQuery.fn.IFWireFormController = function() {
	// each form
	return this.each(function(){
		if (this.id && typeof this.controller == 'undefined') {
			if (typeof IFForm != 'undefined') {
				this.controller = new IFForm(this.id, this.title);
				IF.controllers[this.id] = this.controller;
				jQuery(this).attr('title','').IFCallSetupFunction();
			} else {
				console.log("IFForm not loaded. You're doing it wrong.  Check load order?");
			}

		}
	});
};
jQuery.fn.IFWireFormElementController = function(controllerClass) {
	// each element of a given form
	return this.each(function(){
		if (this.id && typeof this.controller == 'undefined') {
			this.controller = new controllerClass(this.id, this.title);
			jQuery(this).attr('title','').IFCallSetupFunction();
		}
	});
};
jQuery.fn.IFCallSetupFunction = function() {
	return this.each(function(){
		if (IF.setupFn[this.id]) {
			console.log("Calling setup fn on "+this.id);
			IF.setupFn[this.id](this.controller);
		}
	});
};
// TODO what about radio buttons?
jQuery.fn.IFBuildFormControllers = function() {
	console.log('build form controllers');
	this.find('form').IFWireFormController();
	if (typeof IFTextField != 'undefined')
		this.find('textarea, :text, input:hidden, :password').IFWireFormElementController(IFTextField);
	if (typeof IFSubmitButton != 'undefined')
		this.find(':submit, :image, :button').IFWireFormElementController(IFSubmitButton);
	if (typeof IFCheckBox != 'undefined')
		this.find(':checkbox').IFWireFormElementController(IFCheckBox);
	return this;
};


if (typeof IF == 'undefined') {
	IF = {
		buildFormControllers : function() {
			jQuery('body').IFBuildFormControllers();
	 	},
		// controllers objects
		controllers : {},
		// setup calls on the controller
		setupFn : {},
		log : function(msg) {
			console.log(msg);
		},
		// cookie functions http://www.quirksmode.org/js/cookies.html
		createCookie: function(name,value,days) {
			if (days)
			{
				var date = new Date();
				date.setTime(date.getTime()+(days*24*60*60*1000));
				var expires = "; expires="+date.toGMTString();
			}
			else var expires = "";
			document.cookie = name+"="+value+expires+"; path=/";
		},
		readCookie: function(name) {
			var nameEQ = name + "=";
			var ca = document.cookie.split(';');
			for(var i=0;i < ca.length;i++)
			{
				var c = ca[i];
				while (c.charAt(0)==' ') c = c.substring(1,c.length);
				if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
			}
			return null;
		},
		areCookiesEnabled: function() {
			// IE returns a false positive on cookies.
			if (!jQuery.browser.msie && typeof(navigator) != 'undefined' && typeof(navigator.cookieEnabled) != 'undefined') {
				return navigator.cookieEnabled;
			} else {
				IF.createCookie('test-cookies', '1', 0);
				var test = IF.readCookie('test-cookies');
				//Erase the cookie
				IF.createCookie('test-cookies', '', -1);
				return test == '1';
			}
		},

		// http://www.lshift.net/blog/2006/08/03/subclassing-in-javascript-part-2
		extend: function(superclass, constructor_extend, prototype) {
		    var res = function () {
		        superclass.apply(this);
		        constructor_extend.apply(this, arguments);
		    };
		    var withoutcon = function () {};
		    withoutcon.prototype = superclass.prototype;
		    res.prototype = new withoutcon();
		    for (var k in prototype) {
		        res.prototype[k] = prototype[k];
		    }
		    return res;
		},

		stripTags: function(text) {
			return text.replace(/<\/?[^>]+>/gi, '');
        },

		//This returns /YourApp/<site>/en/
		contextPrefix: function() {
			var url = window.location.pathname;
	        var urlParts = url.split('/');
	        // 4 parts of the url includes the first '' from the leading /
	        return urlParts.splice(0, 4).join('/') + '/';
		}
	};
};

jQuery(function() {
	IF.buildFormControllers()
});