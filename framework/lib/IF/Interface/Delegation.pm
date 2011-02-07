package IF::Interface::Delegation;

use strict;
use IF::Log;

sub setDelegate {
	my $self = shift;
	$self->{_delegate} = shift;
	return unless $self->{_delegate};
	$self->{_delegate}->setDelegatedObject($self);
}

sub delegate {
	my $self = shift;
	return $self->{_delegate};
}

sub hasDelegate {
	my $self = shift;
	return ($self->{_delegate} ? 1 : 0);	
}

sub removeDelegate {
	my $self = shift;
	if ($self->{_delegate}) {
		delete $self->{_delegate};
	}
}

sub invokeDelegateMethodNamed {
	my $self = shift;
	my $methodName = shift;
	return unless ($self->canInvokeDelegateMethodNamed($methodName));
	return $self->delegate()->$methodName(@_);
}

sub canInvokeDelegateMethodNamed {
	my $self = shift;
	my $methodName = shift;
	return 0 unless ($self->hasDelegate());
	return 0 unless ($self->delegate()->can($methodName));
	return 1;
}

1;
