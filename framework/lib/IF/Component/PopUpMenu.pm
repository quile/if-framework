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

package IF::Component::PopUpMenu;

use strict;
use base qw(
	IF::Component
	IF::Interface::FormComponent
);

sub requiredPageResources {
	my ($self) = @_;
	return [
        IF::PageResource->javascript("/if-static/javascript/IF/PopUpMenu.js"),
	];
}

sub takeValuesFromRequest {
	my $self = shift;
	my $context = shift;

	$self->SUPER::takeValuesFromRequest($context);
	#IF::Log::debug("method is ".$self->objectInflatorMethod()." parent is ".$self->parent());
	if ($self->objectInflatorMethod() && $self->parent()) {
		$self->setSelection(
				$self->parent()->invokeMethodWithArguments($self->objectInflatorMethod(),
					$context->formValueForKey($self->name()),
					)
				);
	} else {
		$self->setSelection($context->formValueForKey($self->name()));
	}
	IF::Log::debug("Selection for ".$self->name()."/".$self->renderContextNumber()."/".$self->{NAME}." is ".$self->selection());
	if ($self->allowsOther()) {
		if ($self->selection() eq $self->otherValue()) {
			if ($self->otherAlternateKey()) {
				$self->setValueForKey($self->otherText(), "rootComponent." . $self->otherAlternateKey());
			} else {
				$self->setSelection($self->otherText());
			}

		}
	}
	$self->resetValues();
}

sub resetValues {
	my ($self) = @_;
	$self->setAnyString('');
	$self->setAnyValue('');
	delete $self->{_list};
	delete $self->{NAME}; # This is causing problems when unwinding during FancyTakeValues.
}

# Only synchronize the "selection" binding up to the enclosing component
sub shouldAllowOutboundValueForBindingNamed {
	my ($self, $bindingName) = @_;
	return ($bindingName eq "selection");
}

sub name {
	my $self = shift;
	return $self->{NAME} || $self->queryKeyNameForPageAndLoopContexts();
}

sub setName {
	my $self = shift;
	$self->{NAME} = shift;
}

sub list {
	my $self = shift;
	unless ($self->{_list}) {
		my $list;
		if ($self->values() &&
			$self->value() &&
			$self->displayString()) {
			$list = [];
			foreach my $value (@{$self->values()}) {
				push (@$list, { $self->value() => $value, $self->displayString() => $self->labels()->{$value} });
			}
		} else {
			$list = [];
			foreach my $item (@{$self->{LIST}}) {
				push (@$list, $item);
			}
		}

		if ($self->allowsNoSelection()) {
			if ($self->value() && $self->displayString()) {
				unshift (@$list, { $self->value() => $self->anyValue(), $self->displayString() => $self->anyString() });
			} else {
				unshift (@$list, ''); # TODO this is bogus but the only way to ensure that an empty value gets sent in this case
			}
		}

		if ($self->allowsOther()) {
			# Check to see if other is already in the list...
			my $hasOther = 0;
			foreach my $item (@$list) {
				if (ref($item)) {
					if ($item->{$self->value()} eq $self->otherValue()) {
						$hasOther = 1;
						last;
					}
				} else {
					if ($item eq $self->otherValue()) {
						$hasOther = 1;
						last;
					}
				}
			}
			# ...Only add the other value if it doesn't exist.
			unless ($hasOther) {
				if ($self->value() && $self->displayString()) {
					push (@$list, {$self->value() => $self->otherValue(), $self->displayString() => $self->otherLabel()});
				} else {
					push (@$list, $self->otherValue());
				}
			}
		}
		$self->{_list} = $list;
	}
	return $self->{_list};
}

sub setList {
	my $self = shift;
	$self->{LIST} = shift;
}

sub values {
	my $self = shift;
	return $self->{values};
}

sub setValues {
	my $self = shift;
	$self->{values} = shift;
}

sub labels {
	my $self = shift;
	return $self->{labels};
}

sub setLabels {
	my $self = shift;
	$self->{labels} = shift;
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

sub allowsNoSelection {
	my $self = shift;
	return $self->{allowsNoSelection};
}

sub setAllowsNoSelection {
	my $self = shift;
	$self->{allowsNoSelection} = shift;
}

sub objectInflatorMethod {
	my $self = shift;
	return $self->{objectInflatorMethod};
}

sub setObjectInflatorMethod {
	my $self = shift;
	$self->{objectInflatorMethod} = shift;
}

sub anyString {
	my $self = shift;
	return $self->{anyString} || $self->tagAttributeForKey('anyString');
}

sub setAnyString {
	my ($self, $value) = @_;
	$self->{anyString} = $value;
}

sub anyValue {
	my $self = shift;
	return $self->{anyValue};
}

sub setAnyValue {
	my ($self, $value) = @_;
	$self->{anyValue} = $value;
}

sub shouldIgnoreCase {
	my ($self) = @_;
	return $self->{shouldIgnoreCase};
}

sub setShouldIgnoreCase {
	my ($self, $value) = @_;
	$self->{shouldIgnoreCase} = $value;
}

sub shouldIgnoreAccents {
	my ($self) = @_;
	return $self->{shouldIgnoreAccents};
}

sub setShouldIgnoreAccents {
	my ($self, $value) = @_;
	$self->{shouldIgnoreAccents} = $value;
}

sub allowsOther {
	my ($self) = @_;
	return $self->{allowsOther};
}

sub setAllowsOther {
	my ($self, $value) = @_;
	$self->{allowsOther} = $value;
}

sub otherText {
	my ($self) = @_;
	return $self->{otherText};
}

sub setOtherText {
	my ($self, $value) = @_;
	$self->{otherText} = $value;
}

sub otherValue {
	my ($self) = @_;
	return $self->{otherValue} || "OTHER";
}

sub setOtherValue {
	my ($self, $value) = @_;
	$self->{otherValue} = $value;
}

sub otherLabel {
	my ($self) = @_;
	return $self->{otherLabel} || "Other";
}

sub setOtherLabel {
	my ($self, $value) = @_;
	$self->{otherLabel} = $value;
}

# An alternate key can be used to store the text value instead of the selection
sub otherAlternateKey {
	my ($self) = @_;
	return $self->{otherAlternateKey};
}

sub setOtherAlternateKey {
	my ($self, $value) = @_;
	$self->{otherAlternateKey} = $value;
}

sub escapeJavascript {
	my ($self, $string) = @_;
	$string =~ s/'/\\'/g;
	return $string;
}


1;