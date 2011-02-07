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

package IF::MailQueue::MailIterator;

use strict;
use IF::DB;
use IF::Log;
use IF::ObjectContext;

sub new {
	my $className = shift;
	my $self = {};
	bless $self, $className;
	$self->init();
	return $self;
}

sub init {
	my $self = shift;
	$self->{_arguments} = {};
	$self->{_fieldMap} = {};
}

sub initWithQuery {
	my $self = shift;
	$self->{_query} = shift;
}

sub possibleArguments {
	my $self = shift;
	return [];
}

sub query {
	my $self = shift;
	return $self->{_query};
}

sub begin {
	my $self = shift;
	$self->{_dbh} = IF::DB::dbConnection();

	unless ($self->{_dbh}) {
		IF::Log::error("No database handle");
		exit (1);
	}
	$self->{_sth} = $self->{_dbh}->prepare($self->query());
	unless ($self->{_sth}->execute()) {
		IF::Log::error($self->{_dbh}->errstr);
		$self->{_dbh}->disconnect();
		exit (2);
	}
}

sub end {
	my $self = shift;
	$self->{_sth}->finish();
	$self->{_dbh}->disconnect();
}

sub nextResult {
	my $self = shift;
	my $row = $self->{_sth}->fetchrow_hashref();
	return undef unless $row;
	foreach my $k (keys %$row) {
		$row->{uc $k} = $row->{$k};
		if ($k !~ /^[A-Z0-9_]+$/) {
			delete $row->{$k};
		}
	}

	return $row;
}

sub addMappedFields {
	my $self = shift;
	my $row = shift;
	foreach my $key (keys %{$self->fieldMap()}) {
		my $value = $self->fieldMap()->{$key};
		next unless $value;
		my $mappedValue = eval $value;
		$row->{$key} = $mappedValue;
	}
	return $row;
}

sub setArgumentForKey {
	my $self = shift;
	my $argument = shift;
	my $key = shift;
	$self->{_arguments}->{$key} = $argument;
}

sub argumentForKey {
	my $self = shift;
	my $key = shift;
	return $self->{_arguments}->{$key};
}

sub setFieldMap {
	my $self = shift;
	$self->{_fieldMap} = shift;
}

sub fieldMap {
	my $self = shift;
	return $self->{_fieldMap};
}

sub objectContext {
	my ($self) = @_;
	return $self->{_oc} if $self->{_oc};
	$self->{_oc} = IF::ObjectContext->new();
	return $self->{_oc};
}

sub beginTest {}
sub endTest {}

1;

