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

package IF::Component::RadioButtonGroup;

use strict;
use base qw(
    IF::Component::PopUpMenu
    IF::Interface::FormComponent
);

sub requiredPageResources {
    my ($self) = @_;
    return [
        IF::PageResource->javascript("/if-static/javascript/IF/RadioButtonGroup.js"),
    ];
}

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->{isVerticalLayout} = 1;
}

sub takeValuesFromRequest {
    my $self = shift;
    my $context = shift;

    $self->SUPER::takeValuesFromRequest($context);
    if ($self->objectInflatorMethod() && $self->parent()) {
        $self->setSelection(
                            $self->parent()->invokeMethodWithArguments($self->objectInflatorMethod(),
                                                                       $context->formValueForKey($self->name())
                                                                       )
                            );
    } else {
        $self->setSelection($context->formValueForKey($self->name()));
    }
}

sub itemIsSelected {
    my $self = shift;
    my $item = shift;
    my $value;

    if (UNIVERSAL::can($item, "valueForKey")) {
        $value = $item->valueForKey($self->value());
    } elsif (IF::Dictionary::isHash($item) && exists ($item->{$self->value()})) {
        $value = $item->{$self->value()};
    } else {
        $value = $item;
    }

    return 0 unless $value ne "";
    return ($value eq $self->selection());
}

sub displayStringForItem {
    my $self = shift;
    my $item = shift;
    if (UNIVERSAL::can($item, "valueForKey")) {
        return $item->valueForKey($self->displayString());
    }
    if (IF::Dictionary::isHash($item)) {
        if (exists($item->{$self->displayString()})) {
            return $item->{$self->displayString()};
        } else {
            return undef;
        }
    }
    return $item;
}

sub valueForItem {
    my $self = shift;
    my $item = shift;
    my $value;
    if (UNIVERSAL::can($item, "valueForKey")) {
        return $item->valueForKey($self->value());
    }
    if (IF::Dictionary::isHash($item)) {
        if (exists($item->{$self->value()})) {
            return $item->{$self->value()};
        } else {
            return undef;
        }
    }
    return $item;
}

sub shouldRenderInTable {
    my $self = shift;
    return $self->{shouldRenderInTable};
}

sub setShouldRenderInTable {
    my $self = shift;
    $self->{shouldRenderInTable} = shift;
}

sub isVerticalLayout {
    my $self = shift;
    return $self->{isVerticalLayout};
}

sub setIsVerticalLayout {
    my $self = shift;
    $self->{isVerticalLayout} = shift;
}

sub name {
    my ($self) = @_;
    return $self->{NAME} || $self->pageContextNumber();
}

1;
