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

package IF::Relationship::Modelled;

# This represents an entry in the RELATIONSHIPS hash for a given
# entity in the model

use strict;
use base qw(
    IF::Interface::KeyValueCoding
);

use IF::Log;

my $TYPES = {
    TO_ONE => 1,
    TO_MANY => 2,
    FLATTENED_TO_MANY => 3,
};

sub newFromModelEntryWithName {
    my ($className, $entry, $name) = @_;
    return unless $entry;
    my $self = bless $entry, $className;
    $self->setName($name);
    return $self;
}

sub targetEntity {
    my ($self) = @_;
    return $self->{TARGET_ENTITY};
}

sub targetEntityClassDescription {
    my ($self, $model) = @_;
    unless ($self->{_tecd}) {
        $model ||= IF::Model->defaultModel();
        $self->{_tecd} = $model->entityClassDescriptionForEntityNamed($self->targetEntity());
    }
    return $self->{_tecd};
}

sub name {
    my ($self) = @_;
    return $self->{name};
}

sub setName {
    my ($self, $value) = @_;
    $self->{name} = $value;
}

sub sourceAttribute {
    my ($self) = @_;
    return $self->{SOURCE_ATTRIBUTE};
}

sub targetAttribute {
    my ($self) = @_;
    return $self->{TARGET_ATTRIBUTE};
}

sub joinTable {
    my ($self) = @_;
    return $self->{JOIN_TABLE};
}

sub joinTargetAttribute {
    my ($self) = @_;
    return $self->{JOIN_TARGET_ATTRIBUTE};
}

sub joinSourceAttribute {
    my ($self) = @_;
    return $self->{JOIN_SOURCE_ATTRIBUTE};
}

sub type {
    my ($self) = @_;
    return $self->{TYPE};
}

sub qualifier {
    my ($self) = @_;
    return $self->{QUALIFIER};
}

sub joinQualifiers {
    my ($self) = @_;
    return $self->{JOIN_QUALIFIERS};
}

sub defaultSortOrderings {
    my ($self) = @_;
    return $self->{DEFAULT_SORT_ORDERINGS};
}

sub isToOne {
    my $self = shift;
    return $self->type() eq 'TO_ONE';
}

1;