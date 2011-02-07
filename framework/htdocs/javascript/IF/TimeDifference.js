// This allows us to represent a component
// on the client side with a javascript
// client.

TimeDifference = IF.extend(IFComponent,function(uniqueId, bindingName) {
		this.uniqueId = uniqueId;
		this.bindingName = bindingName;
		this._shouldDisplay = true;
		this._properties = new Array(); // useful to put stuff in!
	},
{		
		calculateSinceUnixTime: function (unixTime) {
		    //A blank date is the same as Now
		    var firstDate = new Date();
		    var secondDate = new Date(unixTime * 1000);
		    this.calculate(firstDate, secondDate);
		},
		
		calculate: function(firstDate, secondDate) {
		    //Diff is in milliseconds
			var diff = firstDate.getTime() - secondDate.getTime();
			var prop = this.properties();
			if (prop && prop['maximumNumberOfMilliseconds']) {
				if (diff > prop['maximumNumberOfMilliseconds']) {
					this.setShouldDisplay(false);
				}
			}
		    //Constants
            var second = 1000, minute = 60 * second, hour = 60 * minute, day = 24 * hour;
            this.setDays(Math.floor(diff / day));
        	diff -= this.days() * day;
        	this.setHours(Math.floor(diff / hour));
        	diff -= this.hours() * hour;
        	this.setMinutes(Math.floor(diff / minute));
        	diff -= this.minutes() * minute;
        	this.setSeconds(Math.floor(diff / second));
		},
		
		shouldDisplay: function() {
			return this._shouldDisplay;
		},
		
		setShouldDisplay: function(value) {
			this._shouldDisplay = value;
		},
		
		updateDisplay: function() {
		    this.updateDisplayWithId(this.uniqueId + '_display');
		},
		
		updateDisplayWithId: function(displayId) {
		    var props = this.properties();		    
		    var dic = this.translationDictionary();
		    var display = '';
		    if (props['displayStyle'] == 'STANDARD') {
		        if (this.days() > 0) {
		            display += this.days() + ' ' + (this.days() == 1 ? dic['TD_DAY'] : dic['TD_DAYS']);
		        } else if (this.hours() > 0) {
		            display += this.hours() + ' ' + (this.hours() == 1 ? dic['TD_HOUR'] : dic['TD_HOURS']);
		        } else if (this.minutes() > 0) {
		            display += this.minutes() + ' ' + (this.minutes() == 1 ? dic['TD_MINUTE'] : dic['TD_MINUTES']);
		        } else {
		            display += this.seconds() + ' ' + (this.seconds() == 1 ? dic['TD_SECOND'] : dic['TD_SECONDS']);
		        }
		    } else if (props['displayStyle'] == 'FULL') {
		        if (this.days() > 0) {
		            display += this.days() + ' ' + (this.days() == 1 ? dic['TD_DAY'] : dic['TD_DAYS']) + ', ';
		        }
		        if (this.hours() > 0) {
		            display += this.hours() + ' ' + (this.hours() == 1 ? dic['TD_HOUR'] : dic['TD_HOURS']) + ', ';
		        }
		        if (this.minutes() > 0) {
		            display += this.minutes() + ' ' + (this.minutes() == 1 ? dic['TD_MINUTE'] : dic['TD_MINUTES']) + ', ';
		        }
		        if (this.seconds() > 0) {
		            display += this.seconds() + ' ' + (this.seconds() == 1 ? dic['TD_SECOND'] : dic['TD_SECONDS']);
		        }
		    }
			if (props['template']) {
				var template = dic[props['template']];
				if (template) {
					var re = new RegExp("\\$\\{timeDifference\\}", "g");
					display = template.replace(re, display);
				}
			}
			if (this.shouldDisplay()) {
				jQuery('#' + displayId).text(display);
			}
		},
		
		days: function() {
		    return this._days;
		},
		
		setDays: function(value) {
		    this._days = value;
		},
		
		hours: function() {
		    return this._hours;
		},
		
		setHours: function(value) {
		    this._hours = value;
		},
		
		minutes: function() {
		    return this._minutes;
		},
		
		setMinutes: function(value) {
		    this._minutes = value;
		},
		
		seconds: function() {
		    return this._seconds;
		},
		
		setSeconds: function(value) {
		    this._seconds = value;
		},
		
		translationDictionary: function() {
			if (! this._translationDictionary) {
				console.log("Translation Dictionary was not set and it should have been.  Initializing in English.");
		        this.setTranslationDictionary({
		                                        'TD_UPDATED_TEMPLATE': 'Updated ${timeDifference} ago',
		                                        'TD_DAYS': 'days', 
		                                        'TD_DAY': 'day', 
		                                        'TD_HOURS': 'hours', 
		                                        'TD_HOUR': 'hour', 
		                                        'TD_MINUTES': 'minutes',
		                                        'TD_MINUTE': 'minute',
		                                        'TD_SECONDS': 'seconds',
		                                        'TD_SECOND': 'second'
		                                        });
			}
		    return this._translationDictionary;
		},
		
		setTranslationDictionary: function(value) {
		    this._translationDictionary = value;
		},
		
		properties: function() {
			if (!this._properties) {
		       console.log("Properties were not set and they should have been.  Initializing with defaults.");
		       this.setProperties({
		                            'displayStyle': 'STANDARD',
		                            'template': 'TD_UPDATED_TEMPLATE'
		                        });
		    }
    	    return this._properties;
    	},

    	setProperties: function(p) {
    	    this._properties = p;
    	}

});
