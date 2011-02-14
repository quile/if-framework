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

package IF::Session::DB;

# implements the DB-based persistence of sessions
use strict;
use base qw(
    IF::Entity::Persistent
    IF::Session
);

#--------------- Class Methods --------------------

sub sessionWithExternalId {
    IF::Log::error("sessionWithExternalId() not overridden in Session subclass");
}

sub sessionWithExternalIdAndContextNumber {
    IF::Log::error("sessionWithExternalIdAndContextNumber() not overridden in Session subclass");
}

sub sessionWithId {
    IF::Log::error("sessionWithId() not overridden in Session subclass");
}

sub sessionWithIdAndContextNumber {
    IF::Log::error("sessionWithIdAndContextNumber() not overridden in Session subclass");
}

sub externalIdRegularExpression {
    IF::Log::error("externalIdRegularExpression() not overridden in Session subclass");
}

sub sessionWithExternalIdIsAuthenticated {
    IF::Log::error("sessionWithExternalIdIsAuthenticated() not overridden in Session subclass");
}


#--------------- Core Methods --------------------

sub lastActiveDate {
    my $self = shift;
    return $self->storedValueForKey("lastActiveDate");
}

sub setLastActiveDate {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "lastActiveDate");
}

sub contextNumber {
    my $self = shift;
    return $self->storedValueForKey("contextNumber");
}

sub setContextNumber {
    my $self = shift;
    my $value = shift;
    IF::Log::stack(4);
    $self->setStoredValueForKey($value, "contextNumber");
}

sub clientIp {
    my $self = shift;
    return $self->storedValueForKey("clientIp");
}

sub setClientIp {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "clientIp");
}

sub store {
    my $self = shift;
    return $self->faultEntityForRelationshipNamed("store");
}

sub requestContextForContextNumber {
    my ($self, $contextNumber, $noDefault) = @_;
    # short circuit this pain if we can
    if ($self->{_requestContextsByNumber}->{$contextNumber}) {
        return $self->{_requestContextsByNumber}->{$contextNumber};
    }
    $self->{_requestContextsByNumber}->{$contextNumber} = $self->requestContextClassName()->requestContextForSessionIdAndContextNumber($self->id(), $contextNumber);
    return $self->{_requestContextsByNumber}->{$contextNumber} if $self->{_requestContextsByNumber}->{$contextNumber};
    return $self->requestContextForLastRequest() unless $noDefault;
    return;
}

sub requestContextForLastRequest {
    my $self = shift;
    return if ($self->contextNumber() == 0);
    unless ($self->{_requestContextForLastRequest}) {
        $self->{_requestContextForLastRequest} = $self->requestContextForContextNumber($self->contextNumber()-1, 1);
    }
    return $self->{_requestContextForLastRequest};
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
        $self->{_requestContext} = $self->newRequestContext();
        $self->{_requestContext}->setSessionId($self->id());
        $self->{_requestContext}->setContextNumber($self->contextNumber());
    }
    return $self->{_requestContext};
}

sub wasInflated {
    my ($self) = @_;
    # If the session is authenticated force it to always use
    # the master db.  You need to implement the sessionWithExternalIdIsAuthenticated
    # or it won't work...
    # TODO... fix this nasty rubbish.
    if (ref($self)->sessionWithExternalIdIsAuthenticated($self->externalId())) {
        IF::DB::dbConnection()->setLockedToDefaultWriteDataSource();
    }
}

sub save {
    my ($self, $when) = @_;

    IF::Log::stack(5);

    # Don't save null sessions
    return if $self->isNullSession();
    return $self->SUPER::save($when);
}

sub becomeInvalidated {
    my ($self) = @_;
    # yikes
    $self->_deleteSelf();
}

1;