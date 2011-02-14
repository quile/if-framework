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

package IF::Session::Stash;

#------------------------------------------------------
# Implements the Stash-based persistence of sessions.
# TODO rewrite the whole session-handling nonsense
# from the ground up.  For now this will have to
# suffice
#------------------------------------------------------

use strict;
use base qw(
    IF::Entity::Transient
    IF::Interface::Stash
    IF::Session
);

my $MAX_REQUEST_CONTEXTS = 6;

#--------------- Class Methods --------------------

sub sessionWithExternalId {
    my ($className, $id) = @_;
    my $id = IF::Utility::idFromExternalId($id);
    return undef unless $id;
    return $className->instanceWithId($id);
}

sub sessionWithExternalIdAndContextNumber {
    my ($className, $id) = @_;
    return $className->sessionWithExternalId($id);
}

sub sessionWithId {
    my ($className, $id) = @_;
    return $className->instanceWithId($id);
}

sub sessionWithIdAndContextNumber {
    my ($className, $id) = @_;
    return $className->sessionWithId($id);}

sub externalIdRegularExpression {
    IF::Log::error("externalIdRegularExpression() not overridden in Session subclass");
}

sub sessionWithExternalIdIsAuthenticated {
    IF::Log::error("sessionWithExternalIdIsAuthenticated() not overridden in Session subclass");
}


#----------------- Instance methods ------------------

# This is subtracted from the context number to fetch
# the request context from the array.  It allows us to
# only keep track of the last n requestContexts rather
# than store all of them.

#------------------ Core Methods --------------------

sub lastActiveDate    { return $_[0]->{lastActiveDate} }
sub setLastActiveDate { $_[0]->{lastActiveDate} = $_[1] }
sub contextNumber     { return $_[0]->{contextNumber} }
sub setContextNumber  { $_[0]->{contextNumber} = $_[1] }
sub clientIp          { return $_[0]->{clientIp} }
sub setClientIp       { $_[0]->{clientIp} = $_[1] }
sub _requestContextOffset    { return $_[0]->{_requestContextOffset} }
sub _setRequestContextOffset { $_[0]->{_requestContextOffset} = $_[1] }
sub _requestContexts    { return $_[0]->{_requestContexts} ||= [] }
sub _setRequestContexts { $_[0]->{_requestContexts} = $_[1] }

sub requestContextForContextNumber {
    my ($self, $contextNumber, $noDefault) = @_;
    my $rcs = $self->_requestContexts();
    foreach my $rc (@$rcs) {
        next unless $rc->contextNumber() == $contextNumber;
        return $rc;
    }
    #IF::Log::error("RC context numbers don't match, possibly expired: $contextNumber");
    return undef;
}

sub requestContextForLastRequest {
    my $self = shift;
    return if ($self->contextNumber() == 0);
    return $self->requestContextForContextNumber($self->contextNumber()-1, 1);
}

sub newRequestContext {
    my $self = shift;
    unless ($self->application()) {
        IF::Log::error("Session has no application object");
        return undef;
    }
    my $requestContextClassName = $self->requestContextClassName();
    return unless $requestContextClassName;
    return $requestContextClassName->new();
}

sub requestContext {
    my $self = shift;
    unless ($self->{_requestContext}) {
        my $nr = $self->newRequestContext();
        $self->{_requestContext} = $nr;
        push (@{$self->_requestContexts()}, $nr);
        if (scalar @{$self->_requestContexts()} > $MAX_REQUEST_CONTEXTS) {
            shift @{$self->_requestContexts()};
            $self->{_requestContextOffset}++;
        }
        $self->{_requestContext}->setContextNumber($self->contextNumber());
    }
    return $self->{_requestContext};
}

# Note that the application-specified RequestContext class is ignored here.
# Rightly so; it should not be specified at that level, IMHO.
sub requestContextClassName {
  return "IF::Session::StashedRequestContext";
}

sub sessionValueForKey {
    my ($self, $key) = @_;
    return $self->{_store}->{$key};
}

sub setSessionValueForKey {
    my ($self, $value, $key) = @_;
    $self->{_store}->{$key} = $value;
}

sub save {
    my ($self, $when) = @_;

    # Don't save null sessions
    return if $self->isNullSession();

    # Generate an ID if there isn't one:
    unless ($self->id()) {
        my $sid = IF::DB::nextNumberForSequence("SESSION_ID");
        $self->setId($sid);
    }

    # unhook the application
    $self->{_applicationName} = $self->application()->name();
    $self->{_application} = undef;

    # unhook the request context
    $self->{_requestContext} = undef;

    $self->setStashedValueForKey($self, $self->id());
}

# This makes sure we remove the session from the stash.
sub becomeInvalidated {
    my ($self) = @_;
    if ($self->id()) {
        $self->setStashedValueForKey(undef, $self->id());
    }
}

# the session needs an id, even if it's in the stash;
# we use the id to generate the stash key
sub id    { return $_[0]->{id} }
sub setId { $_[0]->{id} = $_[1] }

# we need to implement "is" since this doesn't descend from
# IF::Entity::Persistent
sub is {
    my ($self, $other) = @_;
    return 0 unless $other;
    return 0 unless $other->can("id");
    return $self->id() == $other->id();
}

# override this so that we don't need to change
# too many implementation details of the
# session subclass
sub instanceWithId {
    my ($self, $id) = @_;
    return $self->stashedValueForKey($id);
}

#------------------------------------------------------------
# Here we are demoting the request context BS to a glorified
# dictionary; it need not be a first-class entity in the
# system and really only needs to be handled within a
# session.  It needs to respond to the same API as the
# entity version, but doesn't need to be persisted outside
# of the session
#------------------------------------------------------------

package IF::Session::StashedRequestContext;

use base qw(
    IF::Dictionary
    IF::Interface::RequestContextHandling
);

sub contextNumber    { return $_[0]->{contextNumber} }
sub setContextNumber { $_[0]->{contextNumber} = $_[1] }
sub sessionId        { return $_[0]->{sessionId} }
sub setSessionId     { $_[0]->{sessionId} = $_[1] }
sub renderedComponents    { return $_[0]->{renderedComponents} }
sub setRenderedComponents { $_[0]->{renderedComponents} = $_[1] }
sub callingComponent      { return $_[0]->{callingComponent} }
sub setCallingComponent   { $_[0]->{callingComponent} = $_[1] }


1;