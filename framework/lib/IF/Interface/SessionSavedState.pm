package IF::Interface::SessionSavedState;

# This is a convenience for components needing to save and restore
# groups of their properties to the session accross transaction.
# The component need only implement sessionStateKeysToSave and optionally
# sessionStateNamespace.

use strict;

#--- Users should implement one or more of the following

sub sessionStateKeysToSave {
    my $self = shift;
    return [];
}

# For any key needing help to reinflate, return an
# anonymous fn taking the value read in from the session
# as its only argument.  You get $self inside the
# sub because of its presence in the enclosing scope
# at the time of creation (fun with closures).
sub sessionStateInflationDelegateForKey {
    my ($self, $key) = @_;
    return;
}

sub sessionStateNamespace {
    my $self = shift;
    return ref($self);
}

#---

# Public API

sub sessionStateSave {
    my ($self) = @_;
    IF::Log::debug("sessionState STORE");
    foreach my $key (@{$self->sessionStateKeysToSave()}) {
        $self->setSessionStateValueForKey($self->valueForKey($key), $key);
    }
}

sub sessionStateRestore {
    my ($self) = @_;
    IF::Log::debug("sessionState RESTORE");
    foreach my $key (@{$self->sessionStateKeysToSave()}) {
        if (my $delegate = $self->sessionStateInflationDelegateForKey($key)) {
            $delegate->($self->sessionStateValueForKey($key));
        } else {
            $self->setValueForKey($self->sessionStateValueForKey($key), $key);
        }
    }
}

sub sessionStateClear {
    my ($self) = @_;
    IF::Log::debug("sessionState CLEAR");
    foreach my $key (@{$self->sessionStateKeysToSave()}) {
        $self->setSessionStateValueForKey(undef, $key);
    }
}

sub sessionStateValueForKey {
    my ($self, $key) = @_;
    my $prefix = $self->sessionStateNamespace() . '_';
    my $value = $self->session()->sessionValueForKey($prefix.$key);
    IF::Log::debug("sessionState returning $value for key $prefix$key");
    return $value;
}

sub setSessionStateValueForKey {
    my ($self, $value, $key) = @_;
    my $prefix = $self->sessionStateNamespace() . '_';
    $self->session()->setSessionValueForKey($value, $prefix.$key);
    IF::Log::debug("sessionState stored $value for key $prefix$key");
}

1;