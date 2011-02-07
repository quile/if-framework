package IF::Interface::PageResourceHandling;

use strict;
use IF::Array;
use IF::Log;

my $COMBINED_PAGE_RESOURCE_TAG = "<%_PAGE_RESOURCES_%>";
my $CSS_PAGE_RESOURCE_TAG = "<%_CSS_PAGE_RESOURCES_%>";
my $JS_PAGE_RESOURCE_TAG = "<%_JS_PAGE_RESOURCES_%>";

# -------------- "resource" management ------------
# this should return a list of "page" resources
# that this component requires.  For example,
# a component that needs a particular stylesheet
# should return 
# [ IF::PageResource->stylesheet("/stylesheets/foo.css") ]
# 
# When a component 'requires' a resource, the >page<
# object for the transaction assembles a list of
# required components and then feeds it to its
# page wrapper, that emits the appropriate tags.

sub requiredPageResources {
	my ($self) = @_;
	return [];
}

# TODO
# This is not exactly ideal, because this should live in the
# appendToResponse of a parent method, and all pages etc
# should inherit it and just "work".  However, until
# the inheritance hierarchy is cleaned up, we can't do that,
# mainly because of the caching pages, so instead this goop
# is buried in a convenience here that can be called from
# the appendToResponse() methods of the different subclasses of IF::Component.

sub addPageResourcesToResponseInContext {
	my ($self, $response, $context) = @_;
	
	$response->renderState()->addPageResources($self->requiredPageResources());
	
	# cheezy hack
	
	if ($self->isRootComponent()) {
#		my $content = $self->_contentWithPageResourcesFromRawContent($response->content());
		my $content = $self->_contentWithPageResourcesFromResponse($response);
		$response->setContent($content);
	}
}

sub _contentWithPageResourcesFromResponse {
	my ($self, $response) = @_;
	
	my $content = $response->content();
	my $cssResources = $self->pageResourcesOfTypeInResponseAsHtml('stylesheet', $response);
	my $jsResources = $self->pageResourcesOfTypeInResponseAsHtml('javascript', $response);
	# replace the tag even if it's with nothing ...
	my $allResources = $cssResources.$jsResources;
	$content =~ s/$CSS_PAGE_RESOURCE_TAG/$cssResources/;
	$content =~ s/$JS_PAGE_RESOURCE_TAG/$jsResources/;
	$content =~ s/$COMBINED_PAGE_RESOURCE_TAG/$allResources/;
	IF::Log::debug(" ^^^^^^^^^^^^^^^^ inserting resources into page ^^^^^^^^^^^^^^^ ");
	return $content;
}

# This asks the context for all accumulated page resources
# and generates tags that pull them into the page.  This is
# a bit gnarly because generating HTML from here is bad,
# bit this stuff will change very infrequently.
# This should be moved to IF::Page once all the
# pages are ported to be subclasses of that.

sub pageResourcesOfTypeInResponseAsHtml {
	my ($self, $type, $response) = @_;

	my $resources = $response->renderState()->pageResources();
	return unless IF::Array->arrayHasElements($resources);
	
	my $filteredSet = [];
	foreach my $r (@$resources) {
		push @$filteredSet, $r if $r->type() eq $type;
	}
	return unless IF::Array->arrayHasElements($filteredSet);
	
	my $content = "";
	foreach my $r (@$filteredSet) {
		$content .= $r->tag()."\n";
	}
	return $content;
}

1;
