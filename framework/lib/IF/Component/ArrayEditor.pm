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

package IF::Component::ArrayEditor;
use strict;
use base qw(
	IF::Component
);

my $SEPARATOR = '%#@';
my $MAXIMUM_POSSIBLE_STARTING_NUMBER = 40; # Totally arbitrary!

sub init {
	my $self = shift;
	$self->SUPER::init(@_);
	$self->setEditor("TextField");
	$self->setValues([]);
	$self->setMinimumNumberOfFields(1);
	$self->setMaximumNumberOfFields();
	$self->setUserCanChangeSize(0);
	$self->setAllowsNoSelection(1);
	#$self->_setPageContextOffset(scalar keys %{$self->{_bindings}}); #aiee
}

sub takeValuesFromRequest {
	my $self = shift;
	my $context = shift;
	$self->SUPER::takeValuesFromRequest($context);
# pull the values out of the context:
	my $values = [];
	my $uniqueName = $self->uniqueId();
	foreach my $key (sort $context->formKeys()) {
		if ($key =~ /^hidden-$uniqueName/) {
			$values = [split($self->separator(), $context->formValueForKey($key))];
			last;
		}
		#IF::Log::debug("Foo: $key");
		next unless ($key =~ /^$uniqueName(L[0-9]+)?-/);
		IF::Log::debug("Value: ".$context->formValueForKey($key));
		push (@$values, $context->formValueForKey($key));
	}
	$self->setValues($values);
}

sub appendToResponse {
	my $self = shift;
	my $response = shift;
	my $context = shift;
	my $returnValue = $self->SUPER::appendToResponse($response, $context);
	$context->setTransactionValueForKey("1", "loaded-array-editor"); #TODO: fix this using RequestContext
	return $returnValue;
}

sub values {
	my $self = shift;
	my $values = $self->{values} || [];
	if (@$values < $self->minimumNumberOfFields()) {
		push (@$values, "" x ($self->minimumNumberOfFields - scalar @$values));
	}
	return $values;
}

sub setValues {
	my $self = shift;
	$self->{values} = shift;
	IF::Log::dump($self->{values});
}

sub hiddenValues {
	my $self = shift;
	my $hiddenValues = join('!*#', @{$self->values()});
	return $hiddenValues;
}

sub editor {
	my $self = shift;
	return $self->{editor};
}

sub setEditor {
	my $self = shift;
	$self->{editor} = shift;
}

sub name {
	my $self = shift;
	return $self->{name} || $self->pageContextNumber();
}

sub setName {
	my $self = shift;
	$self->{name} = shift;
}

sub aValue {
	my $self = shift;
	return $self->{aValue};
}

sub setAValue {
	my $self = shift;
	$self->{aValue} = shift;
}

sub labels {
	my $self = shift;
	return $self->{labels};
}

sub setLabels {
	my $self = shift;
	$self->{labels} = shift;
}

sub minimumNumberOfFields {
	my $self = shift;
	return $self->{minimumNumberOfFields};
}

sub setMinimumNumberOfFields {
	my $self = shift;
	$self->{minimumNumberOfFields} = shift;
}

sub maximumNumberOfFields {
	my $self = shift;
	return $self->{maximumNumberOfFields};
}

sub setMaximumNumberOfFields {
	my $self = shift;
	$self->{maximumNumberOfFields} = shift;
}

sub startingNumberOfFields {
	my $self = shift;
	return $self->{startingNumberOfFields} || scalar @{$self->values()};
}

sub setStartingNumberOfFields {
	my $self = shift;
	$self->{startingNumberOfFields} = shift;
}

sub fields {
	my $self = shift;
	my $values = $self->values();
	my $startingNumberOfFields = $self->startingNumberOfFields();
	if ($startingNumberOfFields < $self->minimumNumberOfFields()) {
		$startingNumberOfFields = $self->minimumNumberOfFields();
	}
	if ($self->maximumNumberOfFields() && $startingNumberOfFields > $self->maximumNumberOfFields()) {
		$startingNumberOfFields = $self->maximumNumberOfFields();
	}
	my $fields = [ @$values[0..($startingNumberOfFields-1)] ];
	return $fields;
}

sub fieldsForDopeyBrowser {
	my $self = shift;
	my $values = $self->values();
	my $startingNumberOfFields = $self->startingNumberOfFields();
	if ($startingNumberOfFields < $self->minimumNumberOfFields()) {
		$startingNumberOfFields = $self->minimumNumberOfFields();
	}
	if ($self->maximumNumberOfFields() && $startingNumberOfFields < $MAXIMUM_POSSIBLE_STARTING_NUMBER) {
		$startingNumberOfFields = $self->maximumNumberOfFields();
	}
	my $fields = [ @$values[0..($startingNumberOfFields-1)] ];
	return $fields;
}

sub fieldValue {
	my $self = shift;
	return $self->{aField};
}

sub fieldName {
	my $self = shift;
	return $self->uniqueId()."-".$self->{fieldIndex};
}

sub hasFieldLabel {
	my $self = shift;
	return 0 unless $self->labels();
	return 0 unless (IF::Array::isArray($self->labels()) && scalar @{$self->labels()} > 0);
	return 1;
}

sub fieldLabel {
	my $self = shift;
	return $self->labels()->[$self->{fieldIndex}];
}

sub isFirstTimeLoaded {
	my $self = shift;
	return 1 unless $self->context()->transactionValueForKey("loaded-array-editor");
	return 0;
}

sub filterNewLinesAndQuotes {
	my $self = shift;
	my $value = shift;
	$value =~ s/[\r\n\t]/ /g;
	$value = IF::Utility::escapeHtml($value);
	return $value;
}

sub userCanChangeSize {
	my $self = shift;
	return $self->{userCanChangeSize};
}

sub setUserCanChangeSize {
	my $self = shift;
	$self->{userCanChangeSize} = shift;
}

sub separator {
	return $SEPARATOR;
}

sub uniqueName {
	my ($self) = @_;
	unless ($self->{_uniqueName}) {
		$self->{_uniqueName} = $self->uniqueId();
	}
	return $self->{_uniqueName};
}

sub _setPageContextOffset {
	my $self = shift;
	$self->{_pageContextOffset} = shift;
}

sub nextPageContextNumber {
	my $self = shift;
	$self->{_pageContextOffset}++;
	return $self->pageContextNumber().".".$self->{_pageContextOffset};
}

sub allowsNoSelection {
	my $self = shift;
	return $self->{allowsNoSelection};
}

sub setAllowsNoSelection {
	my $self = shift;
	$self->{allowsNoSelection} = shift;
}

1;
