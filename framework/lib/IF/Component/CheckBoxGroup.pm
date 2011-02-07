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

package IF::Component::CheckBoxGroup;

use strict;
use base qw(
	IF::Component::ScrollingList
	IF::Interface::FormComponent
);

sub requiredPageResources {
	my ($self) = @_;
	return [
        IF::PageResource->javascript("/if-static/javascript/IF/CheckBoxGroup.js"),
	];
}

sub takeValuesFromRequest {
	my $self = shift;
	my $context = shift;

	$self->SUPER::takeValuesFromRequest($context);
	#IF::Log::debug("CheckBoxGroup ".$self->name());
	if ($self->objectInflatorMethod() && $self->parent()) {
		$self->setSelection(
			$self->parent()->invokeMethodWithArguments($self->objectInflatorMethod(),
							$context->formValuesForKey($self->name())
						)
		);
	} else {
	#	IF::Log::debug("selected values for checkbox group: ".join(", ", @{$context->formValuesForKey($self->name())}));
		$self->setSelection($context->formValuesForKey($self->name()));
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

#IF::Log::debug("Checking if item $value is selected.");
	return 0 unless $value ne "";
	return 0 unless (IF::Array::isArray($self->selection()));
#TODO: Optimise this by hashing it
	foreach my $selectedValue (@{$self->selection()}) {
		unless (ref $selectedValue) {
#IF::Log::debug("Checking ($selectedValue, $value) to see if it's selected");
			return 1 if ($selectedValue eq $value);
# this could be optimised:
			if ($selectedValue =~ /^[0-9\.]+$/ &&
				$value =~ /^[0-9\.]+$/ &&
				$selectedValue == $value) {
				return 1;
			}
			next;
		}
		if (UNIVERSAL::can($selectedValue, "valueForKey")) {
			return 1 if $selectedValue->valueForKey($self->value()) eq $value;
		} else {
			return 1 if $selectedValue->{$self->value()} eq $value;
		}
	}
	return 0;
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

sub name {
	my ($self) = @_;
	# This has to be pageContextNumber so that the checkboxes
	# all get this component's unique id
	return $self->{NAME} || $self->pageContextNumber();
}

1;
