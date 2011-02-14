// Javascript for StatusMessagesViewer

var _statusMessageViewers = new Array();

function StatusMessagesViewer(uniqueId) {
    this.uniqueId = uniqueId;
    this.component = jQuery('#'+uniqueId)[0];
    if (!this.component) {
        //alert("No status messages viewer " + uniqueId + " found");
    }
}

StatusMessagesViewer.addStatusMessagesViewer = function(viewer) {
    _statusMessageViewers[_statusMessageViewers.length] = viewer;
}

StatusMessagesViewer.primaryStatusMessagesViewer = function(viewer) {
    if (_statusMessageViewers.length == 0) {
        //alert("No primary status messages viewer found!");
        return;
    }
    return _statusMessageViewers[0];
}

// ------ instance methods -------

StatusMessagesViewer.prototype.init = function() {
    StatusMessagesViewer.addStatusMessagesViewer(this);
}

StatusMessagesViewer.prototype.postStatusMessages = function(messages, classes, hasErrors) {
    this.clearStatusMessages();
    var statDiv = jQuery('#'+this.uniqueId + '-messages')[0];
    if (messages.length < 1) {
        statDiv.hide();
    } else {
        statDiv.show();
    }
    
    if (hasErrors) {
        statDiv.css('error-messages');
    } else {
        statDiv.css('status-messages');
    }
    
    for(i=0; i < messages.length; i++) {
        jQuery('#' + this.uniqueId + '-message-list').append('<li class="'+classes[i]+'">'+messages[i]+'</li>');    
    }
}

StatusMessagesViewer.prototype.clearStatusMessages = function() {
    var msgList =  jQuery('#'+this.uniqueId + '-message-list')[0];
    var nodeList = jQuery(msgList).find('li').each(function(){
            this.parent.removeChild(node);
    });
}
