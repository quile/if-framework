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

package IF::PrimaryKey;

use strict;
use IF::Log;
use IF::Qualifier;
use overload '""' => "stringValue",
             'ne' => "ne",
             'eq' => "eq";

sub new {
    my $className = shift;
    my $self = bless {
        _keyDefinition => "",
        _keyFields => {},
        }, $className;
    $self->_setKeyDefinition(shift);
    return $self;
}

sub _keyDefinition {
    my $self = shift;
    return $self->{_keyDefinition};
}

sub _setKeyDefinition {
    my ($self, $value) = @_;
    $self->{_keyDefinition} = $value;
    $self->setKeyFieldsFromKeyDefinition($self->{_keyDefinition});
}

sub setKeyFieldsFromKeyDefinition {
    my $self = shift;
    my $keyDefinition = shift;
    my $keys = [split(":", $keyDefinition)];
    $self->{_keyFieldNames} = $keys;
    my $order = 0;
    foreach my $key (@$keys) {
        $self->{_keyFields}->{$key} = {
            key => $key,
            order => $order,
        };
        $order++;
    }
}

sub hasKeyField {
    my ($self, $key) = @_;
    return exists($self->{_keyFields}->{$key});
}

sub keyFields {
    my $self = shift;
    return $self->{_keyFieldNames};
}

sub qualifierForValue {
    my ($self, $value) = @_;
    if ($self->isCompound()) {
        # expect a number of values
        return $self->qualifierForValues([split(":", $value)]);
    }
    return $self->qualifierForValues([$value]);
}

sub qualifierForValues {
    my ($self, $values) = @_;
    my $qualifiers = [];
    my $order = 0;
    foreach my $key (@{$self->keyFields()}) {
        push (@$qualifiers, IF::Qualifier->key("$key = %@", $values->[$order]));
        $order++;
    }
    if (scalar @$qualifiers == 1) {
        return $qualifiers->[0];
    } else {
        return IF::Qualifier->and($qualifiers);
    }
}

sub valueForEntity {
    my ($self, $entity) = @_;
    return join(":", @{$self->valuesForEntity($entity)}); # escape ":" in this?
}

sub valuesForEntity {
    my ($self, $entity) = @_;
    my $values = [];
    foreach my $key (@{$self->keyFields()}) {
        push (@$values, $entity->valueForKey($key));
    }
    return $values;
}

sub setValueForEntity {
    my ($self, $value, $entity) = @_;
    my $values = [split(":", $value)];
    my $index = 0;
    foreach my $key (@{$self->keyFields()}) {
        $entity->setValueForKey(shift @$values, $key);
    }
}

sub stringValue {
    my $self = shift;
    return $self->{_keyDefinition};
}

sub isCompound {
    my $self = shift;
    return (scalar @{$self->keyFields()} > 1);
}

sub ne {
    my ($self, $other) = @_;
    return ($self->stringValue() ne $other);
}

sub eq {
    my ($self, $other) = @_;
    return ($self->stringValue() eq $other);
}

1;