# Copyright (c) 2010 - Action Without Borders
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

package IF::AsynchronousComponent;

use strict;
use base qw(
	IF::Component
);
use IF::Constants;

# This component adds the ability for a component to "update itself"
# asynchronously within a page using AJAX.  It's a work-in-progress
# but the ultimate goal is to allow client-side updating of
# regions of the page very transparently.

sub takeValuesFromRequest {
	my ($self, $context) = @_;

	my $ucid = $context->formValueForKey($IF::Constants::QK_CLIENT_SIDE_ID);
	IF::Log::debug("PCN is ".$self->pageContextNumber()." UCID is $ucid");
	# Only the async component that's the ROOT is allowed to renumber the tree.
	if ($ucid && $self->pageContextNumber() eq "1") {
		my $pcn = $self->pageContextNumberFromUniqueId($ucid);
		IF::Log::debug("$self - Renumbering page context to start with $pcn");
		if ($pcn && $pcn ne "1") {
			$self->setPageContextNumberRoot($pcn);
		}
	}
	foreach my $k (@{$self->persistentKeys()}) {
		IF::Log::debug("... trying to inflate persistent key $k");
		$self->setValueForKey($context->formValueForKey(PERSISTENT_KEY_PREFIX().$k), $k);
	}
	# process this value here and set it on this component.  we do this
	# because if we don't, and this component returns another component, it
	# will think that IT is responding asynchronously.
	if ($context->formValueForKey($IF::Constants::QK_ASYNCHRONOUS)) {
		$self->setIsRespondingAsynchronously(1);
	}
	# Remember to set the parent binding name so that when rendered
	# asynchronously, it recreates the same binding name tree.
    my $csn = $context->formValueForKey("client-side-name");
    if ($csn) {
       IF::Log::debug("Setting parent binding name to $csn");
       $self->setParentBindingName($csn);
    }
	IF::Log::debug("Calling SUPER::tvfr");
	$self->SUPER::takeValuesFromRequest($context);
}

sub appendToResponse {
	my ($self, $response, $context) = @_;

	# expand the asynchronous component definition
	# and wrap the response with tags defining it.
	# These tags will be read by the browser and
	# the front-end cache, which will have the ability
	# to ignore these asynchronous regions when
	# caching or retrieving cached pages.

	if ($self->shouldRenderWrapperInContext($context)) {
		$response->appendContentString($self->header());
	}

	if ($self->isRespondingAsynchronously()) {
		$response->appendContentString('<?xml version="1.0" encoding="utf-8" ?>'."\n");
		$response->appendContentString($self->asynchronousStatusMessages());

		# check for a different template based on the context.
		# in this case it allows the component to use a different template
		# for the asynchronous response than if the component is rendered
		# as part of the page.
		my $templateName = $self->mappedTemplateNameFromTemplateNameInContext(
                                    IF::Component::__templateNameFromComponentName($self->componentName()),
									$context);
		IF::Log::debug("loading template $templateName");
        my $template = $context->siteClassifier()->bestTemplateForPathAndContext($templateName, $context);
		if ($template) {
			$response->setTemplate($template);
		}
	}
	my $returnValue = $self->SUPER::appendToResponse($response, $context);
	if ($self->shouldRenderWrapperInContext($context)) {
	    $self->{_context} = $context;
		$response->appendContentString($self->footer());
		$self->{_context} = undef;
	}

	return $returnValue;
}

sub mappedTemplateNameFromTemplateNameInContext {
	my ($self, $templateName, $context) = @_;
	# Not sure if this will work
	my $appName = $self->context()->application()->name();
	return $templateName unless $appName;
	$templateName =~ s/$appName//;
	my $asynchronousToken = $self->asynchronousTemplateIdentifier();
	$templateName =~ s!\.html!$asynchronousToken.html!;
	return $templateName;
}

sub asynchronousTemplateIdentifier {
	my ($self) = @_;
	return ".async";
}

sub shouldRenderWrapperInContext {
	my ($self, $context) = @_;
	if ($self->shouldRenderAsynchronousController()) {
		if ($self->isRespondingAsynchronously()) {
			IF::Log::debug("ASYNC:: isRespondingAsynchronously is set");
			if (!$self->isRenderingAsRoot()) {
				IF::Log::debug("ASYNC:: $self is not being rendered as root");
				return 1;
			} else {
				IF::Log::debug("ASYNC:: $self is ".$self->rootComponent());
			}
		} else {
		    if ($self->isRootComponent()) {
		        return 0;
		    } else {
			    IF::Log::debug("ASYNC:: Rendering out header because isRespondingAsynchronously is not set");
			    return 1;
			}
		}
	}
	return 0;
}

sub isRenderingAsRoot {
	my ($self) = @_;
	return ($self->parent() == undef);
}

# -------------- yikes warning -------------
# This component injects markup into the
# response.  This markup does not come from
# a template... TODO - remedy this!!!
# ------------------------------------------

sub asynchronousStatusMessages {
	my ($self) = @_;
	my $list = $self->{_statusMessages} || [];
	my $stringList = [];
	my $classList = [];
	my $hasErrors = 0;
	my $hasMessages = scalar @$list;

	foreach my $msg (@$list) {
		push @$stringList, $msg->text();
		push @$classList, $msg->cssClass();
		$hasErrors = 1 if $msg->typeIsError();
	}
	my $messages = '"'. join ('", "', @$stringList) .'"' if $hasMessages;
	my $classes = '"'. join ('", "', @$classList) .'"' if $hasMessages;;

	# when this is refreshed asynchronously, this script will
	# be run by the browser when the component is loaded; it will
	# fish out the primary status viewer and post the messages that >this< component
	# has embedded in it.
	# TODO -41 actually, I feel that it should have its OWN status messages
	# viewer, so that any status messages are WITH the component that generated them.
	my $output = <<"EOL";
<script language="javascript">
		if (typeof StatusMessagesViewer != "undefined") {
			StatusMessagesViewer.primaryStatusMessagesViewer().postStatusMessages([$messages], [$classes], $hasErrors);
		}
</script>
EOL

	#IF::Log::debug($output);
	return;
}

sub wrapperTag {
	my ($self) = @_;
	return ($self->isInline() ? "span" : "div");
}

sub header {
	my ($self) = @_;

	my $header = '<'.$self->wrapperTag().' id="'.$self->uniqueId().'" updateFrom="'.$self->updateFrom().'">';

	my $output;
	if ($self->redirect()) {
		my $url = $self->redirect();
		$output = <<"EOL";
<script language="javascript">
	location.replace("$url");
</script>
EOL
	}

	return $header . $output;
}

sub footer {
	my ($self) = @_;
	return '</'.$self->wrapperTag().">\n".$self->controller();
}

# so evil to have all this goop buried in here.

sub controller {
	my ($self) = @_;
	my $bindingName = $self->parentBindingName();
	my $nestedBindingPath = $self->nestedBindingPath();
	my $url = $self->updateFrom();

	my $clientSideName = $self->clientSideName() || $nestedBindingPath;
	my $csvar = $clientSideName;
	my $onLoadCode = ($self->updateOnLoad() ? "c.reload()" : "");
	my $reloadEventCode = ($self->reloadEvent()
		? "jQuery('body').bind('".$self->reloadEvent()."', function() { c.reload() })"
	 	: "");
	my $uniqueId = $self->uniqueId();
	my ($host, $rootUrl, $action, $queryString) = ($url =~ q/^((?:https?:\/\/)?[^\/]+)?(\/[\w-_\/]+\/)(\w+)\?(.+)$/);
    #my ($rootUrl, $action, $queryString) = ($url =~ q/^((?:https?:\/)?\/[^\?]+\/)(\w+)\?(.+)$/);
	return <<EOC;
<script type="text/javascript">
	jQuery(function () {
		var c = new AsynchronousComponent("$uniqueId", "$nestedBindingPath");
		c.initWithValues("$rootUrl", "$action", "$queryString");
		// register with the component registry
		componentRegistry.registerComponentWithName(c, "$clientSideName");
		$reloadEventCode
		$onLoadCode
	});
</script>
EOC
}

sub _updateUrl {
	my ($self) = @_;
	my $qd = $self->persistentQueryDictionary();
	$qd->{$IF::Constants::QK_ASYNCHRONOUS} = $self->uniqueId();  # aieee I hate shit like this (temporary!)
	my $context = $self->context();
	my $url = IF::Utility::urlInContextForDirectActionOnComponentWithQueryDictionary(
		$context,
		"default",
		$self->updateFromComponent(),
		{
			$context? %{$context->queryDictionary()} : (),
			%$qd,
		}
	);
	# Wipe out the server so it's relative...All your base are belong to us.
	my $base = IF::Utility::baseUrlInContext($self->context());
	$url =~ s/$base//g;
	return $url;
}

sub setIsRespondingAsynchronously {
	my ($self, $value) = @_;
	$self->{_isRespondingAsynchronously} = 1;
}

sub isRespondingAsynchronously {
	my ($self) = @_;
	return $self->{_isRespondingAsynchronously};
	#return $self->context()->formValueForKey($IF::Constants::QK_ASYNCHRONOUS);
}

sub updateOnLoad {
	my $self = shift;
	return $self->{updateOnLoad};
}

sub setUpdateOnLoad {
	my ($self, $value) = @_;
	$self->{updateOnLoad} = $value;
}

sub redirect {
	my $self = shift;
	return $self->{redirect};
}

sub setRedirect {
	my ($self, $value) = @_;
	$self->{redirect} = $value;
}

sub updateFrom {
	my $self = shift;
	return $self->{updateFrom} ||
			$self->_updateUrl();
}

sub setUpdateFrom {
	my ($self, $value) = @_;
	$self->{updateFrom} = $value;
}

sub clientSideName {
	my ($self) = @_;
	# ouch, this could frak things up:
	#return $self->{clientSideName} || $self->parentBindingName();
	return $self->{clientSideName} || $self->nestedBindingPath();
}

sub setClientSideName {
	my ($self, $value) = @_;
	$self->{clientSideName} = $value;
}

sub updateFromComponent {
	my $self = shift;
	return $self->{updateFromComponent} ||
			$self->componentNameRelativeToSiteClassifier();
}

sub setUpdateFromComponent {
	my ($self, $value) = @_;
	$self->{updateFromComponent} = $value;
}

sub shouldRenderAsynchronousController {
	my ($self) = @_;
	return 1;
}

sub requiredPageResources {
	my ($self) = @_;
	my $prs = $self->SUPER::requiredPageResources();
	push (@$prs,
	    IF::PageResource->javascript("/if-static/javascript/jquery/jquery-1.2.6.js"),
		IF::PageResource->javascript("/if-static/javascript/IF/ComponentRegistry.js"),
		IF::PageResource->javascript("/if-static/javascript/IF/AsynchronousComponent.js"),
		);
	return $prs;
}

# The async component will optionally listen for this
# event and reload itself.
sub reloadEvent {
	my ($self) = @_;
	return $self->{reloadEvent};
}

sub setReloadEvent {
	my ($self, $value) = @_;
	$self->{reloadEvent} = $value;
}

# consumers should override or set this if they wish to be rendered
# inline using span tags rather than as a block using div tags
# default: not inline
sub isInline {
	my ($self) = @_;
	# default to undef intentional
	return $self->{isInline};
}

sub setIsInLine {
	my ($self,$value) = @_;
	$self->{isInline} = $value;
}

# allow the async component to "persist" values by declaring keys that are 'persisted',
# meaning the values are passed back and forth between async requests.  Note: you are
# *totally* responsible for presenting these key-value pairs yourself.  If you want
# to persist an array of strings, for example, it's *your* job to turn that
# array into a string and back into an array.  This is where you declare which >keys<
# to persist.  valueForKey() will be called once for each one, and then
# setValueForKey() will be called during takeValues once for each one.

sub persistentKeys {
	my ($self) = @_;
	return [];
}

sub PERSISTENT_KEY_PREFIX {
	return "_pk-";
}

sub persistentQueryDictionary {
	my ($self) = @_;
	my $qd = {
		_ucid => $self->renderContextNumber(),
	};
	if (scalar @{$self->persistentKeys()}) {
		foreach my $k (@{$self->persistentKeys()}) {
			$qd->{PERSISTENT_KEY_PREFIX().$k} = $self->valueForKey($k);
		}
	}
	return $qd;
}

sub pageContextNumberFromUniqueId {
	my ($self, $uid) = @_;
	# experimental:
	my ($foo, $bar) = split("L", $uid, 2);
	my $pcn = $foo;
	#$pcn =~ tr/Z[a-j]/_[0-9]/;
	$pcn =~ s/^c//;
	return $pcn; # this ignores the loop context... bad!
}

1;
