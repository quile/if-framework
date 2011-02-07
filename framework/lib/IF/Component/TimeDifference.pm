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

package IF::Component::TimeDifference;

use base qw(
    IF::Component
);
use strict;

use JSON;

sub requiredPageResources {
	my ($self) = @_;
	return [
		@{$self->SUPER::requiredPageResources()},
		IF::PageResource->javascript("/if-static/javascript/IF/Component.js"),
		IF::PageResource->javascript("/if-static/javascript/IF/TimeDifference.js"),
	];
}

sub startDate {
	my ($self) = @_;
	return $self->{startDate};
}

sub setStartDate {
	my ($self, $value) = @_;
	$self->{startDate} = $value;
}

sub displayStyle {
	my ($self) = @_;
	return $self->{displayStyle} || 'STANDARD';
}

sub setDisplayStyle {
	my ($self, $value) = @_;
	$self->{displayStyle} = $value;
}

sub template {
	my ($self) = @_;
	return $self->{template};
}

sub setTemplate {
	my ($self, $value) = @_;
	$self->{template} = $value;
}

sub maximumNumberOfMilliseconds {
	my ($self) = @_;
	return $self->{maximumNumberOfMilliseconds};
}

sub setMaximumNumberOfMilliseconds {
	my ($self, $value) = @_;
	$self->{maximumNumberOfMilliseconds} = $value;
}

sub maximumNumberOfDays {
	my ($self) = @_;
	return $self->{maximumNumberOfDays};
}

sub setMaximumNumberOfDays {
	my ($self, $value) = @_;
	$self->setMaximumNumberOfMilliseconds($value * (24 * 60 * 60 * 1000));
	$self->{maximumNumberOfDays} = $value;
}

sub maximumNumberOfMinutes {
	my ($self) = @_;
	return $self->{maximumNumberOfMinutes};
}

sub setMaximumNumberOfMinutes {
	my ($self, $value) = @_;
	$self->setMaximumNumberOfMilliseconds($value * (60 * 60 * 1000));
	$self->{maximumNumberOfMinutes} = $value;
}

sub propertiesAsJSON {
	my ($self) = @_;
	return $self->{propertiesAsJSON} if $self->{propertiesAsJSON};
	my $props = {
		displayStyle => $self->displayStyle(),
		template => $self->template(),
		maximumNumberOfMilliseconds => $self->maximumNumberOfMilliseconds(),
	};
	return $self->{propertiesAsJSON} = to_json($props);
}

sub clientSideName {
	my ($self) = @_;
	return $self->{clientSideName} || $self->parentBindingName();
}

sub setClientSideName {
	my ($self, $value) = @_;
	$self->{clientSideName} = $value;
}

1;