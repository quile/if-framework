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

package IF::Entity;

use strict;
use base qw(
    IF::Interface::KeyValueCoding
    IF::Interface::Delegation
    IF::Interface::Notifications
    IF::Behaviour::ModelFu
);

#====================================
use IF::Model;
use IF::Array;
use IF::Log;
use IF::Date::Unix;
use IF::Entity::UniqueIdentifier;
#====================================

sub new {
	my $className = shift;

	my $self = {};
	$self->{__storedValues} = {};		# contains representation of DB column values
	$self->{_wasDeletedFromDataStore} = 0;
	$self->{__joinRecordForRelationship} = {}; # tracks transient join information to other objects

	my $namespace = $className;
	$namespace =~ s/::([A-Za-z0-9_]*)$//g;
	$self->{_entityClassName} = $1;
	$self->{_namespace} = $namespace;
	bless $self, $className;
	$self->initValuesWithArray(\@_);	# inflate the entity if we're initialising it with values

	if (scalar @_ > 0) {
		$self->awakeFromInflation();
	} else {
		$self->init();
	}
	return $self;
}

sub newFromDictionary {
    my ($className) = shift;
    my $e = $className->new();
    my $dictionary = { @_ };
    if ($dictionary) {
        foreach my $k (keys %$dictionary) {
            $e->setValueForKey($dictionary->{$k}, $k);
        }
    }
    return $e;
}

sub init {
	my $self = shift;
}

sub awakeFromInflation {
	my $self = shift;
}


# dangerous: maybe make this private?
sub setId {
	my $self = shift;
	my $value = shift;
	$self->setStoredValueForKey($value, "id");
}

sub id {
	my $self = shift;
	return $self->storedValueForKey("id");
}

sub uniqueIdentifier {
	my ($self) = @_;
	return IF::Entity::UniqueIdentifier->newFromEntity($self);
}

# I want everyone to start using this instead of "id" when vending this
# goo to the public as part of URLs etc
sub externalId {
	my ($self) = @_;
	return undef unless $self->id();
	return IF::Utility::externalIdFromId($self->id());
}

#-----

# stringification for use in admin tools and elsewhere
#
#  Overload one or the other or be happy with the default
#  behaviour

sub summaryAttributes {
	my ($self) = @_;
	return ['title', 'name'];
}

sub asString {
	my $self = shift;
	my $separator = shift;  # optional
	$separator ||= ', ';
	if (my $summaryAttributes = $self->summaryAttributes()) {
		my @rawAttrs = map {$self->valueForKey($_)} @$summaryAttributes;
		my $attrs = [];
		foreach my $a (@rawAttrs) {
			push @$attrs, $a if $a;
		}
		my $str = join(', ', @$attrs);
		return $str if $str;
	}
	return scalar $self;
}

1;
