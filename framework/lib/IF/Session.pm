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

package IF::Session;

# These methods get mixed-in with the IF::Session::* classes
# so don't try to subclass this directly.

use strict;

sub application {
    my $self = shift;
    return $self->{_application} if $self->{_application};
    return IF::Application->defaultApplication(); # Hokey but saves it from yacking
}

sub setApplication {
    my $self = shift;
    $self->{_application} = shift;
}

sub requestContextClassName {
  my $self = shift;
  return $self->{_requestContextClassName} ||= $self->application()->requestContextClassName();
}

# This should be overridden in your subclass to
# create an external id if there isn't one
sub externalId {
    my ($self) = @_;
    return $self->{_externalId};
}

# this is private API because only the fw should be
# setting this.
sub _setExternalId {
    my ($self, $value) = @_;
    $self->{_externalId} = $value;
}


sub isNullSession {
    my ($self) = @_;
    return ($self->{_externalId} eq IF::Context::NULL_SESSION_ID());
}

sub wasInflated {
    my ($self) = @_;
}

sub hasExpired {
    my ($self) = @_;
    # basic implementation just checks dates
    my $timeout = $self->application()->configurationValueForKey("DEFAULT_SESSION_TIMEOUT");
    my $now = CORE::time();
    my $last = IF::GregorianDate->new($self->lastActiveDate());
    return ($now - $timeout > $last->utc());
}

sub becomeInvalidated {
    my ($self) = @_;
    IF::Log::error("Session->becomeInvalidated not implemented");
}

# TODO - fix this API!  This is a lame way to do it;
# it's either yea or nay like this, whereas it should
# be fine-grained.
sub userCanViewAdminPages {
    return 0;
}

# NOTE: These are a NOP for DB-based sessions unless you implement
# them yourself with some kind of session store.
sub setSessionValueForKey {
    my ($self, $value, $key) = @_;
    return;
}

sub sessionValueForKey {
    my ($self, $key) = @_;
    return undef;
}

1;