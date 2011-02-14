// ---- constructor ----

function ComponentRegistry() {
    this.components = new Array();
    this.componentNames = new Array();
};
var MAIN_CONTENT_KEY = "MAIN_CONTENT"; // this is pretty lame

ComponentRegistry.prototype = {
        
    // store and retrieve components by name using these
    // methods.
    registerComponentWithName: function(component, name) {
        var existingComponent = this.components[name];
        if (existingComponent) {
            this.components[name][this.components[name].length] = component;
        } else {
            this.components[name] = new Array();
            this.components[name][0] = component;
        }
        // add the name
        this.componentNames[this.componentNames.length] = name;
    },
    
    componentWithName: function(name) {
        return this.componentWithNameRelativeToComponent(name, null);
    },
    
    componentWithNameRelativeToComponent: function(name, from) {
        var bestName = this.bestMatchingComponentNameForNameRelativeToComponent(name, from);
        var existingComponent = this.components[bestName];
        if (existingComponent) {
            // TODO allow the consumer to fetch more than one?
            return existingComponent[0];
        }
        return null;
    },
    
    componentsWithName: function(name) {
        return this.componentsWithNameRelativeToComponent(name, null);
    },
    
    componentsWithNameRelativeToComponent: function(name, from) {
        var bestName = this.bestMatchingComponentNameForNameRelativeToComponent(name, from);
        var existingComponents = this.components[bestName];        
        if (existingComponents) {
            return existingComponents;
        }
        return new Array();
    },
    
    bestMatchingComponentNameForNameRelativeToComponent: function(name, from) {
        // if there's a 'from', check relative to the 'from':
        if (from) {
            var c = from.bindingName();
            // console.log("Checking for component " + name + " relative to " + c);
            if (c) {
                var n = c + "/" + name;
                var e = this.components[n];
                if (e) {
                    return n;
                }
            }
        }
        
        // brute force for the name
        var matches = [];
        for (var i in this.components) {
            if (i.indexOf(name) >= 0) {
                matches[matches.length] = i;
            }
        }
        if (matches.length) {
            return matches[0];
        }
        
        // otherwise, try the name directly
        var e = this.components[name];
        if (e) {
            return name;
        }
        
        return "";
    },
    
    // Specialty methods used for page-building
    
    mainContent: function() {
        if (this._mainContent) {
            return this._mainContent;
        }
        this._mainContent = $(MAIN_CONTENT_KEY);
        return this._mainContent;
    },
    
    reloadMainContentFromUrl: function(url) {
        var mc = this.mainContent();
        if (!mc) {
            return;
        }
        // here we would set up the "please wait" goop
        mc.innerHTML = "..."; // max can do a nice spinning gif or something here.
        // add an on success callback here to focus back the the top of the page
        new Ajax.Updater(mc, url, { asynchronous:true, evalScripts:true });
    },
    
    // Page has wrapper
    pageHasWrapper: function() {
        var mc = this.mainContent();
        return (mc != null);
    }
};

// create an instance of the component registry if it doesn't exist.
if (typeof componentRegistry == "undefined") {
    var componentRegistry = new ComponentRegistry();
}
