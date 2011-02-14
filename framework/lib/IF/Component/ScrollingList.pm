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

package IF::Component::ScrollingList;

use strict;
use base qw(
    IF::Component
    IF::Interface::FormComponent
);

sub requiredPageResources {
    my ($self) = @_;
    return [
        IF::PageResource->javascript("/if-static/javascript/IF/ScrollingList.js"),
    ];
}

sub takeValuesFromRequest {
    my $self = shift;
    my $context = shift;

    $self->SUPER::takeValuesFromRequest($context);
    if ($self->objectInflatorMethod() && $self->parent()) {
        $self->setSelection(
                $self->parent()->invokeMethodWithArguments($self->objectInflatorMethod(),
                    $context->formValuesForKey($self->name())
                    )
                );
    } else {
        if ($self->isMultiple()) {
            $self->setSelection($context->formValuesForKey($self->name()));
        } else {
            $self->setSelection($context->formValueForKey($self->name()));
        }
    }
}

sub name {
    my $self = shift;
    return $self->{NAME} || $self->queryKeyNameForPageAndLoopContexts();
}

sub setName {
    my $self = shift;
    $self->{NAME} = shift;
}

sub anyString {
    my ($self) = @_;
    return $self->{anyString};
}

sub setAnyString {
    my ($self, $value) = @_;
    $self->{anyString} = $value;
}

sub anyValue {
    my ($self) = @_;
    return $self->{anyValue} || "";
}

sub setAnyValue {
    my ($self, $value) = @_;
    $self->{anyValue} = $value;
}

sub list {
    my $self = shift;
    return $self->{LIST};
}

sub setList {
    my $self = shift;
    $self->{LIST} = shift;
}

sub selection {
    my $self = shift;
    return $self->{SELECTION};
}

sub setSelection {
    my $self = shift;
    $self->{SELECTION} = shift;
}

sub value {
    my $self = shift;
    return $self->{VALUE};
}

sub setValue {
    my $self = shift;
    $self->{VALUE} = shift;
}

sub displayString {
    my $self = shift;
    return $self->{DISPLAY_STRING};
}

sub setDisplayString {
    my $self = shift;
    $self->{DISPLAY_STRING} = shift;
}

sub objectInflatorMethod {
    my $self = shift;
    return $self->{objectInflatorMethod};
}

sub setObjectInflatorMethod {
    my $self = shift;
    $self->{objectInflatorMethod} = shift;
}

sub size {
    my $self = shift;
    return $self->{size};
}

sub setSize {
    my $self = shift;
    $self->{size} = shift;
}

sub isMultiple {
    my $self = shift;
    return $self->{isMultiple};
}

sub setIsMultiple {
    my $self = shift;
    $self->{isMultiple} = shift;
}

1;
