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

package IF::Component::LocalizedString;

# This is just a place-holder; it won't actually work.
use strict;
use base qw(
	IF::Component
);

use IF::I18N;

sub init {
	my ($self) = @_;
	$self->SUPER::init();
	delete $self->{_language};
	delete $self->{_value};
	delete $self->{_key};
	delete $self->{_hash};
}

sub stringValue {
	my ($self) = @_;

    IF::Log::debug("Looking for string for ".$self->key());
    if ($self->key()) {
        return _s($self->key());
    }
    if ($self->value()) {
        return _s($self->value());
    }
	return "MISSING STRING LITERAL";
}

sub hasCompiledResponse {
	my $self = shift;
	return 1;
}

sub appendToResponse {
	my ($self, $response, $context) = @_;

	$response->setContent($self->stringValue());
	return;
}

sub language {
    my $self = shift;
    return $self->{_language} || $self->context()->language();  # default to the session's language
}

sub setLanguage {
    my $self = shift;
    $self->{_language} = shift;
}

sub hash {
    my $self = shift;
    return $self->{_hash};
}

sub setHash {
    my $self = shift;
    $self->{_hash} = shift;
}

sub key {
    my $self = shift;
    return $self->{_key};
}

sub setKey {
    my $self = shift;
    $self->{_key} = shift;
}

sub value {
	my $self = shift;
	return $self->{_value};
}

sub setValue {
	my ($self, $value) = @_;
	$self->{_value} = $value;
}

1;
