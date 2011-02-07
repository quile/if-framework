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

package PF::Dictionary;

use strict;

sub new {
	my $className = shift;
	my $self = {};
	bless $self, $className;
	my $dictionary = shift;
	if ($dictionary) {
		$self->initWithDictionary($dictionary);
	}
	return $self;
}

sub initWithDictionary {
	my $self = shift;
	my $dictionary = shift;
	$self->removeAllObjects();
	foreach my $key (keys %$dictionary) {
		$self->setObjectForKey($dictionary->{$key}, $key);
	}
	return $self;
}

sub removeAllObjects {
	my $self = shift;
	foreach my $key (keys %$self) {
		$self->removeObjectForKey($key);
	}
}

sub numberOfKeys {
	my $self = shift;
	return scalar keys %$self;
}

sub objectForKey {
	my $self = shift;
	my $key = shift;
	return $self->{$key};
}

sub setObjectForKey {
	my $self = shift;
	my $object = shift;
	my $key = shift;
	$self->{$key} = $object;
}

# this method name is confusing becuase it actually
# returns whether or not the key exists not the object
sub hasObjectForKey {
	my $self = shift;
	my $key = shift;
	return exists($self->{$key});
}

sub allKeys {
	my $self = shift;
	return [keys %$self];
}

sub allObjects {
	my $self = shift;
	return [values %$self];
}

sub removeObjectForKey {
	my $self = shift;
	my $key = shift;
	delete $self->{$key};
}

sub removeObject {
	my $self = shift;
	my $object = shift;
	foreach my $key (keys %$self) {
		next unless ($self->objectForKey($key) == $object);
		$self->removeObjectForKey($key);
	}
}

sub removeObjectsForKeys {
	my $self = shift;
	my $keys = shift;
	foreach my $key (@$keys) {
		$self->removeObjectForKey($key);
	}
}

1;
