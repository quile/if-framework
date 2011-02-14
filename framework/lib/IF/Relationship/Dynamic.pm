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

package IF::Relationship::Dynamic;

# A dynamic relationship is one that is not
# modelled in the pmodel file, that needs to
# be created at runtime, based on derived info
# usually from a column in a table.
use strict;
use base qw(
    IF::Relationship::Modelled
);

# This is a raw constructor... it's meant to
# be augmented in your own code
sub new {
    my ($className) = @_;
    return bless {}, $className;
}

# The name is what should be used in key paths in qualifiers
sub name {
    my ($self) = @_;
    return $self->{name};
}

sub setName {
    my ($self, $value) = @_;
    $self->{name} = $value;
}

sub sourceAttributeName {
    my ($self) = @_;
    return $self->{sourceAttributeName};
}

sub setSourceAttributeName {
    my ($self, $value) = @_;
    $self->{sourceAttributeName} = $value;
}

sub targetAttributeName {
    my ($self) = @_;
    return $self->{targetAttributeName};
}

sub setTargetAttributeName {
    my ($self, $value) = @_;
    $self->{targetAttributeName} = $value;
}

sub sourceAttribute {
    my ($self) = @_;
    return $self->{sourceAttribute} ||= $self->entityClassDescription()->columnNameForAttributeName($self->sourceAttributeName());
}

sub setSourceAttribute {
    my ($self, $value) = @_;
    $self->{sourceAttribute} = $value;
}

sub targetAttribute {
    my ($self) = @_;
    return $self->{targetAttribute} ||= $self->targetEntityClassDescription()->columnNameForAttributeName($self->targetAttributeName());
}

sub setTargetAttribute {
    my ($self, $value) = @_;
    $self->{targetAttribute} = $value;
}

# I decided to make this the public API
# instead of the rather badly named "targetEntity"
sub targetAssetTypeAttribute {
    my ($self) = @_;
    return $self->{targetAssetTypeAttribute};
}

sub setTargetAssetTypeAttribute {
    my ($self, $value) = @_;
    $self->{targetAssetTypeAttribute} = $value;
}

# ... which is here for compatibility
sub targetEntity {
    my ($self) = @_;
    return $self->targetAssetTypeName();
}

#----------------------------------

sub targetEntityColumnValue {
    my ($self) = @_;
    return $self->{_targetEntityColumnValue} if $self->{_targetEntityColumnValue};
    my $ta = $self->targetAssetTypeAttribute();
    return unless $ta;
    # how do we get the attribute information?  hmmmm
    my $ecd = $self->entityClassDescription();
    my $attr = $ecd->attributeWithName($ta);
    return unless IF::Log::assert($attr, "Attribute $ta found on ".$ecd->name());
    unless (IF::Log::assert($attr->{TYPE} eq "int", "Target asset type attribute is a string")) {
        # the attribute is an asset name (we hope!)
        return $self->{_targetEntityColumnValue} = $self->targetAssetTypeName();
    }
    return '';
}

sub targetEntityClassDescription {
    my ($self, $model) = @_;
    unless ($self->{_tecd}) {
        $model ||= IF::Model->defaultModel();
        $self->{_tecd} = $model->entityClassDescriptionForEntityNamed($self->targetAssetTypeName());
    }
    return $self->{_tecd};
}

# This gets set when the dynamic relationship is added the fetchspec
sub entityClassDescription {
    my ($self) = @_;
    return $self->{entityClassDescription};
}

sub setEntityClassDescription {
    my ($self, $value) = @_;
    $self->{entityClassDescription} = $value;
}

# This is the name
sub targetAssetTypeName {
    my ($self) = @_;
    return $self->{targetAssetTypeName};
}

sub setTargetAssetTypeName {
    my ($self, $value) = @_;
    $self->{targetAssetTypeName} = $value;
}


# what should this be?
sub type {
    my ($self) = @_;
    return "TO_MANY";
}

sub qualifier {
    my ($self) = @_;

    if ($self->targetAssetTypeAttribute()) {
        # we need to qualify the source table on this, because it
        # stores the name or asset-type-id of the target asset type
        # (and therefore the target table) in the source table
        my $columnValue = $self->targetEntityColumnValue();
        if (IF::Log::assert($columnValue, "Target asset type column value exists")) {
            my $q = IF::Qualifier->key($self->targetAssetTypeAttribute()." = %@", $columnValue);
            $q->setEntity($self->entityClassDescription()->name());
            return $q;
        }
    }
    return $self->{QUALIFIER};
}

sub defaultSortOrderings {
    my ($self) = @_;
    return $self->{DEFAULT_SORT_ORDERINGS};
}

1;