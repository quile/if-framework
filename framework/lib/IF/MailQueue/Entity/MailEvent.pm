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

package IF::MailQueue::Entity::MailEvent;

use strict;
use base qw(
    IF::Entity::Persistent
);

# TODO rewrite this without SQL
sub deleteAllQueueEntries {
	my $self = shift;
	my $query = "DELETE FROM MAIL_QUEUE_ENTRY WHERE MAIL_EVENT_ID=".int($self->id());
	my ($results, $dbh) = IF::DB::executeArbitrarySQL($query);
}

sub createdBy {
	my $self = shift;
	return $self->storedValueForKey("createdBy");
}

sub setCreatedBy {
	my $self = shift;
	my $value = shift;
	$self->setStoredValueForKey($value, "createdBy");
}

sub logMessage {
	my $self = shift;
	return $self->storedValueForKey("logMessage");
}

sub setLogMessage {
	my $self = shift;
	my $value = shift;
	$self->setStoredValueForKey($value, "logMessage");
}

1;