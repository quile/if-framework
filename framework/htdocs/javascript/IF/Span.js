// span tag that is tied in to the js framework so we can
// easily get / set its value

IFSpan = IF.extend(IFFormComponent, function(uniqueId, bindingName) {
		this.uniqueId = uniqueId;
		this.bindingName = bindingName;
		this.element = jQuery('#'+uniqueId)[0];
		if (!this.element) {
			console.log("No span found with id "+uniqueId);
			return;
		}
		this.element.controller = this;
	},
{
		value: function() {
			jQuery(this.element).html();
		},

		setValue: function(value) {
			jQuery(this.element).html(value);
		},

		show: function() {
			jQuery(this.element).show();
		},

		hide: function() {
			jQuery(this.element).hide();
		}
});
