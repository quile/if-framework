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

package IF::RequestContext;

use strict;
use base qw(
    IF::Entity::Persistent
    IF::Interface::RequestContextHandling
);

sub requestContextForSessionIdAndContextNumber {
	my ($className, $sessionId, $contextNumber) = @_;
	return IF::ObjectContext->new()->entityMatchingQualifier("RequestContext",
	            IF::Qualifier->and([
	                IF::Qualifier->key("contextNumber = %@", $contextNumber),
	                IF::Qualifier->key("sessionId = %@", $sessionId)
	            ]));
}

sub session {
	my $self = shift;
	return $self->faultEntityForRelationshipNamed("session");
}

sub contextNumber {
	my $self = shift;
	return $self->storedValueForKey("contextNumber");
}

sub setContextNumber {
	my $self = shift;
	my $value = shift;
	$self->setStoredValueForKey($value, "contextNumber");
}

sub sessionId {
	my $self = shift;
	return $self->storedValueForKey("sessionId");
}

sub setSessionId {
	my $self = shift;
	my $value = shift;
	$self->setStoredValueForKey($value, "sessionId");
}

sub renderedComponents {
	my $self = shift;
	return $self->storedValueForKey("renderedComponents");
}

sub setRenderedComponents {
	my $self = shift;
	my $value = shift;
	$self->setStoredValueForKey($value, "renderedComponents");
}

sub callingComponent {
	my $self = shift;
	return $self->storedValueForKey("callingComponent");
}

sub setCallingComponent {
	my $self = shift;
	my $value = shift;
	$self->setStoredValueForKey($value, "callingComponent");
}

sub awakeFromInflation {
	my $self = shift;
	$self->SUPER::awakeFromInflation();
	my $renderedComponents = {};
	my $renderedPageContextNumbers = {};
	foreach my $component (split("/", $self->renderedComponents())) {
		my ($componentName, $pageContextNumbers) = split("=", $component);
		foreach my $pageContextNumber (split(":", $pageContextNumbers)) {
			$renderedComponents->{$componentName}->{$pageContextNumber}++;
			$renderedPageContextNumbers->{$pageContextNumber}++;
		}
	}
	$self->{_renderedComponents} = $renderedComponents;
	$self->{_renderedPageContextNumbers} = $renderedPageContextNumbers;
}

sub prepareForCommit {
	my $self = shift;
	my $renderedComponents = [];
	foreach my $componentName (keys %{$self->{_renderedComponents}}) {
		my $pageContextNumbers = join (":", keys %{$self->{_renderedComponents}->{$componentName}});
		push (@$renderedComponents, $componentName."=".$pageContextNumbers);
	}

	$self->setRenderedComponents(join("/", @$renderedComponents));
}


1;