// This allows us to represent a component
// on the client side with a javascript
// client.

// ---- constructor ----
function AsynchronousComponent(uniqueId, bindingName, renderContextNumber) {
    this.uniqueId = uniqueId;
    this.bindingName = bindingName;
    this.renderContextNumber = renderContextNumber;
    this.component = jQuery('#'+uniqueId);
    if (!this.component) {
        alert("Couldn't find component " + uniqueId);
    }
}

// ---- instance methods ----
AsynchronousComponent.prototype.init = function() {
    // alert("Init of " + this.uniqueId);
}

AsynchronousComponent.prototype.initWithValues = function(rootUrl, action, queryString) {
    this.init();
    this.rootUrl = rootUrl;
    this.action = action;
    this.queryString = queryString;
    this.updateUrl = rootUrl + action + "?" + queryString;
}

AsynchronousComponent.prototype.reloadFromUrl = function(url, qd, type, func) {
    var targetId = this.uniqueId;
    jQuery('#'+targetId).html('<div class="whileLoading">&nbsp;</div>');
    type = type || 'GET';
    func = func || function(data){
        jQuery('#'+targetId).html(data).IFBuildFormControllers();
    };
    jQuery.ajax({
        url: url,
        data: qd,
        type: type,
        success: func,
        error: function(XMLHttpRequest, textStatus, errorThrown) {
            console.log('Error: '+textStatus+' - '+errorThrown);
        }
     });
}

AsynchronousComponent.prototype.reload = function() {
    console.log("Loading from "+ this.updateUrl + "...");
    this.reloadFromUrl(this.updateUrl);
}

AsynchronousComponent.prototype.queryStringFromExtrasDictionary = function(dictionary) {
    // i had to restore this code because the ajax() code above doesn't do the same
    // thing... we need to overwrite, not join.  sorry this is so hopeless and low-level but
    // i couldn't see an easy way in jQuery to do this
    var url = this.updateUrl;
    var qs = "";
    if (url.indexOf('?') != -1) {
        var parts = url.split('?');
        url = parts[0];
        qs = parts[1];
    }

    var qd = new Object();
    var kvps = qs.split("&");
    for (var i=0; i<kvps.length; i++) {
        var kvs = kvps[i].split("="); // this doesn't take quoted shit into account
        var key = kvs[0];
        var value = kvs[1];
        qd[key] = value;
    }

    // stomp
    for (var key in dictionary) {
        qd[key] = dictionary[key];
    }

    //rebuild
    qs = "";
    for (var key in qd) {
        var value = qd[key];
        qs = qs + key + "=" + value + "&";
    }
    return qs;
}

AsynchronousComponent.prototype.reloadWithQueryDictionary = function (dictionary) {
    var queryString = "";
    // do some javascripty stuff to generate a query string from a dictionary
    this.reloadWithQueryString(queryString);
}

AsynchronousComponent.prototype.reloadWithExtraQueryKeyValuePairs = function (dictionary) {
    var qs = this.queryStringFromExtrasDictionary(dictionary);
    this.reloadFromUrl(this.rootUrl + this.action + "?" + qs);
}

AsynchronousComponent.prototype.reloadWithActionAndExtraQueryKeyValuePairs = function(action, dictionary) {
    var qs = this.queryStringFromExtrasDictionary(dictionary);
    this.reloadFromUrl(this.rootUrl + action + "?" + qs);
}

AsynchronousComponent.prototype.reloadWithQueryString = function (string) {
    // reload from the URL with qs
    //alert("Reloading!");
    this.reloadFromUrl(this.updateUrl + "&" + string)
}

AsynchronousComponent.prototype.submitWithActionAndSerializedForm = function (action, form) {
    var qd = jQuery.extend(jQuery(form).serializeArray(),
        { '_async' : this.uniqueId, '_ucid=' : this.renderContextNumber });
    var url = this.rootUrl + action;
    this.reloadFromUrl(url, qd, 'POST');
}

AsynchronousComponent.prototype.failureMessage = function (status) {
    if (404 == status)
        return 'Resource not found. '+status;
    return 'Temporary server failure. Please try again shortly. '+status;
}

AsynchronousComponent.prototype.uniqueId = function() {
    return this.uniqueId;
}

AsynchronousComponent.prototype.bindingName = function() {
    return this.bindingName;
}