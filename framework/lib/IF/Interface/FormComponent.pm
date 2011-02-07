package IF::Interface::FormComponent;

use strict;

sub isRequired {
	my ($self) = @_;
	my $v = $self->{isRequired} || $self->tagAttributeForKey('isRequired');
	return $v ? 1 : 0;
}

sub setIsRequired {
	my ($self, $value) = @_;
	$self->{isRequired} = $value;
}

# TODO This is bogus because there could be more than one message,
# eg "You must enter an email address" and "You must enter a valid email address"

sub validationFailureMessage {
	my ($self) = @_;
	return $self->{validationFailureMessage}  || $self->tagAttributeForKey('validationFailureMessage');
}

sub setValidationFailureMessage {
	my ($self, $value) = @_;
	$self->{validationFailureMessage} = $value;
}

sub validator {
	my ($self) = @_;
	return $self->{validator} || $self;
}

sub setValidator {
	my ($self, $value) = @_;
	$self->{validator} = $value;
}

sub hasValidValues {
	my ($self) = @_;
	if ($self->isRequired() && !$self->hasValueForValidation()) {
		return 0;
	}
	return 1;
}

sub isRequiredMessage {
    my ($self) = @_;
    return $self->{isRequiredMessage} ||  $self->tagAttributeForKey('isRequiredMessage');
}

sub setIsRequiredMessage {
    my ($self, $value) = @_;
    $self->{isRequiredMessage} = $value;
}

# This might not work for all form components
# but it will simplify
sub hasValueForValidation {
	IF::Log::warning("hasValueForValidation() has not been implemented");
}


1;