package IF::Interface::StatusMessageHandling;

use strict;
use IF::StatusMessage;
use IF::Log;
use IF::Array;
use IF::I18N;

# Moving all the handling of status messages to an "interface"
# that can be glommed onto anything

# TODO these are all bogus because the language should be irrelevant
# until rendering time, at which point the message should be
# pulled out of the appropriate language resource!

sub addInfoMessageInLanguage {
    my ($self, $message, $language) = @_;
	my $localizedMessage = _s($message, $language);
	IF::Log::debug("Pushing message $localizedMessage into viewer");
	push (@{$self->{_statusMessages}}, IF::StatusMessage->newInfoMessage($localizedMessage));
}

sub addConfirmationMessageInLanguage {
    my ($self, $message, $language) = @_;
	my $localizedMessage = _s($message, $language);
	IF::Log::debug("Pushing message $localizedMessage into viewer");
	push (@{$self->{_statusMessages}}, IF::StatusMessage->newConfirmationMessage($localizedMessage));
}

sub addWarningMessageInLanguage {
    my ($self, $message, $language) = @_;
	my $localizedMessage = _s($message, $language);
	push (@{$self->{_statusMessages}}, IF::StatusMessage->newWarningMessage($localizedMessage));
}

sub addErrorMessageInLanguage {
    my ($self, $message, $language) = @_;
	my $localizedMessage = _s($message, $language);
	push (@{$self->{_statusMessages}}, IF::StatusMessage->newErrorMessage($localizedMessage));
}

sub simpleAddErrorMessageForKey {
    my ($self, $key) = @_;
	$self->_deprecated_addErrorMessage($key);
}

sub statusMessages {
	my $self = shift;
	return $self->{_statusMessages} || [];
}

sub setStatusMessages {
	my ($self, $value) = @_;
	$self->{_statusMessages} = $value;
}

sub errors {
	my $self = shift;
	my $messages = $self->statusMessages();
	return [ grep { $_->typeIsError() } @$messages ];
}

sub hasErrors {
	my $self = shift;
	return IF::Array->arrayHasElements($self->errors());
}

1;