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

package IF::MailQueue::Entity::MailQueueEntry;

use strict;
use base qw(
    IF::Entity::Persistent
);

sub message {
    my $self = shift;
    unless ($self->{_message}) {
        $self->{_message} = $self->faultEntityForRelationshipNamed("message");
    }
    return $self->{_message};
}

sub mailEvent {
    my $self = shift;
    return $self->faultEntityForRelationshipNamed("mailEvent");
}

sub fieldValues {
    my $self = shift;
    my $fieldValues;
    my $fv = $self->storedValueForKey("fieldValues");
    eval $fv; # DANGER! TODO add some guards against exploits
    return $fieldValues;
}

sub setFieldValues {
    my $self = shift;
    my $fieldValues = shift;
    my $fieldValuesAsString = Data::Dumper->Dump([$fieldValues], [qw($fieldValues)]);
    $self->setStoredValueForKey($fieldValuesAsString, "fieldValues");
}

sub isLastMessage {
    my $self = shift;
    return $self->storedValueForKey("isLastMessage");
}

sub setIsLastMessage {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "isLastMessage");
}

sub email {
    my $self = shift;
    return $self->storedValueForKey("email");
}

sub setEmail {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "email");
}

sub sender {
    my $self = shift;
    return $self->storedValueForKey("sender");
}

sub setSender {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "sender");
}

sub mailMessageId {
    my $self = shift;
    return $self->storedValueForKey("mailMessageId");
}

sub setMailMessageId {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "mailMessageId");
}

sub sendDate {
    my $self = shift;
    return $self->storedValueForKey("sendDate");
}

sub setSendDate {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "sendDate");
}

sub mailEventId {
    my $self = shift;
    return $self->storedValueForKey("mailEventId");
}

sub setMailEventId {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "mailEventId");
}

1;
