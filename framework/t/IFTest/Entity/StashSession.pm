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

package IFTest::Entity::StashSession;

use base qw(
    IF::Session::Stash
    IF::Entity::Transient
);

sub externalId {
	my ($self) = @_;
    return $self->id();
}

sub externalIdRegularExpression {
	my ($self) = @_;
	return '\d+';
}

sub invalidateExternalId {
	my ($self) = @_;
	IF::Log::debug("Deleting external sid");
	delete $self->{_externalId};
}

sub _idFromExternalId {
	my ($className, $externalId) = @_;
    return $externalId;
}

sub sessionWithExternalId {
	my ($className, $externalId) = @_;
	my $id = $className->_idFromExternalId($externalId);
	my $session = $className->instanceWithId($id);
	return $session;
}

sub sessionWithExternalIdAndContextNumber {
	my ($className, $externalId, $contextNumber) = @_;
	my $session = $className->sessionWithExternalId($externalId);
	return unless $session && $session->requestContextForContextNumber($contextNumber);
	return $session;
}


# this is here temporarily until I refactor the session handling goop a bit
# to handle session stores and fix this context numbering stuff.
sub save {
    my ($self) = @_;

    # this is bogus, it should be incremented only when a web transaction
    # completes, so that we don't increment it more than once per transaction
    $self->setContextNumber($self->contextNumber()+1);
	$self->setLastActiveDate(time);
	$self->SUPER::save();
}

sub lastActiveDate    { return $_[0]->{lastActiveDate} }
sub setLastActiveDate { $_[0]->{lastActiveDate} = $_[1] }
sub contextNumber     { return $_[0]->{contextNumber} }
sub setContextNumber  { $_[0]->{contextNumber} = $_[1] }
sub clientIp    { return $_[0]->{clientIp} }
sub setClientIp { $_[0]->{clientIp} = $_[1] }
sub isLong      { return $_[0]->{isLong} }
sub setIsLong   { $_[0]->{isLong} = $_[1] }

1;