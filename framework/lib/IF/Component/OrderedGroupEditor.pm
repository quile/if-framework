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

package IF::Component::OrderedGroupEditor;
use strict;
use vars qw(@ISA);
use IF::Component;
use IF::Array;
@ISA = qw(IF::Component);

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->setSize(10); # default 10? seems ok
}

sub takeValuesFromRequest {
    my ($self, $context) = @_;
    $self->SUPER::takeValuesFromRequest($context);
    my $selectedValues = [split(":", $context->formValueForKey($self->uniqueId()."-hidden"))];
    my $list;
    if ($self->shouldUseSessionStore()) {
        $list = $context->session()->sessionValueForKey($self->uniqueId()."-list");
    } else {
        $list = $self->list();
    }
    if ($list && IF::Array::isArray($list)) {
        #IF::Log::dump($self->value());
        my $selection = [];
        foreach my $itemValue (@$selectedValues) {
            foreach my $item (@$list) {
                #IF::Log::debug("selection is $itemValue, item's value is ".$item->valueForKey($self->value()));
                if ($item->valueForKey($self->value()) eq $itemValue) {
                    push (@$selection, $item);
                    last;
                }
            }
        }
        $self->setSelection($selection);
        if ($self->shouldUseSessionStore()) {
            $context->session()->setSessionValueForKey(undef, $self->uniqueId."-list");
        }
    }
}

sub appendToResponse {
    my ($self, $response, $context) = @_;
    if ($self->shouldUseSessionStore()) {
        $context->session()->setSessionValueForKey($self->list(), $self->uniqueId()."-list");
    }
    return $self->SUPER::appendToResponse($response, $context);
}

sub selection {
    my $self = shift;
    return $self->{selection};
}

sub setSelection {
    my ($self, $value) = @_;
    $self->{selection} = $value;
}

sub list {
    my $self = shift;
    return $self->{list};
}

sub setList {
    my ($self, $value) = @_;
    $self->{list} = $value;
}

sub displayString {
    my $self = shift;
    return $self->{displayString};
}

sub setDisplayString {
    my ($self, $value) = @_;
    $self->{displayString} = $value;
}

sub value {
    my $self = shift;
    return $self->{value};
}

sub setValue {
    my ($self, $value) = @_;
    $self->{value} = $value;
}

sub size {
    my $self = shift;
    return $self->{size};
}

sub setSize {
    my ($self, $value) = @_;
    $self->{size} = $value;
}

sub shouldUseSessionStore {
    my $self = shift;
    return $self->{shouldUseSessionStore};
}

sub setShouldUseSessionStore {
    my ($self, $value) = @_;
    $self->{shouldUseSessionStore} = $value;
}

1;