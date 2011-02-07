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

package IF::Component::TextField;

use strict;
use vars qw($DEFAULT_SIZE $DEFAULT_MAX_LENGTH);
use base qw(
	IF::Component
	IF::Interface::FormComponent
);

sub requiredPageResources {
	my ($self) = @_;
	return [
        IF::PageResource->javascript("/if-static/javascript/IF/TextField.js"),
	];
}

sub resetValues {
	my ($self) = @_;
	delete $self->{NAME};
	delete $self->{SIZE};
	delete $self->{MAX_LENGTH};
	delete $self->{VALUE};
}

sub takeValuesFromRequest {
	my $self = shift;
	my $context = shift;

	$self->SUPER::takeValuesFromRequest($context);
	$self->setValue($context->formValueForKey($self->name()));
	IF::Log::debug("Value of input field ".$self->name()." is ".$self->value());
}

sub name {
	my $self = shift;
	my $name = $self->{NAME};
	return $name || $self->queryKeyNameForPageAndLoopContexts();
}

sub setName {
	my $self = shift;
	$self->{NAME} = shift;
}

sub size {
	my $self = shift;
	return $self->{SIZE};
}

sub setSize {
	my $self = shift;
	$self->{SIZE} = shift;
}

sub maxLength {
	my $self = shift;
	return $self->{MAX_LENGTH};
}

sub setMaxLength {
	my $self = shift;
	$self->{MAX_LENGTH} = shift;
}

sub value {
	my $self = shift;
	return $self->{VALUE};
}

sub setValue {
	my $self = shift;
	$self->{VALUE} = shift;
}

sub escapeDoubleQuotes {
	my $self = shift;
	my $string = shift;
	$string =~ s/"/\&quot\;/g; #"
	return $string;
}

sub shouldEnableClientSideScripting {
	my $self = shift;
	return $self->{shouldEnableClientSideScripting};
}

sub setShouldEnableClientSideScripting {
	my $self = shift;
	$self->{shouldEnableClientSideScripting} = shift;
}

1;