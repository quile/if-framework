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

package IF::Relationship::ManyToMany;

use strict;
use base qw(
    IF::Relationship::Dynamic
);


# TODO  rework this to be free of AWB terminology.
#       finish writing unit tests
#       profit


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

sub sourceAssetTypeAttribute {
    my ($self) = @_;
    return $self->{sourceAssetTypeAttribute};
}

sub setSourceAssetTypeAttribute {
    my ($self, $value) = @_;
    $self->{sourceAssetTypeAttribute} = $value;
}


#----------------------------------

sub targetEntityColumnValue {
    my ($self) = @_;
    return $self->{_targetEntityColumnValue} if $self->{_targetEntityColumnValue};
    my $ta = $self->targetAssetTypeAttribute();
    return unless $ta;
    my $ecd;
    if ($self->{_jcd}) {
        $ecd = $self->{_jcd};
    }
    return unless $ecd;
    my $attr = $ecd->attributeWithName($ta);
    return unless IF::Log::assert($attr, "Attribute $ta found on ".$ecd->name());
    unless (IF::Log::assert($attr->{TYPE} eq "int", "Target asset type attribute is a string")) {
        # the attribute is an asset name (we hope!)
        return $self->{_targetEntityColumnValue} = $self->targetAssetTypeName();
    }
    return '';
}

sub sourceEntityColumnValue {
    my ($self) = @_;
    return $self->{_sourceEntityColumnValue} if $self->{_sourceEntityColumnValue};
    my $ta = $self->sourceAssetTypeAttribute();
    return unless $ta;
    my $ecd;
    if ($self->{_jcd}) {
        $ecd = $self->{_jcd};
    }
    return unless $ecd;
    my $attr = $ecd->attributeWithName($ta);
    return unless IF::Log::assert($attr, "Attribute $ta found on ".$ecd->name());
    unless (IF::Log::assert($attr->{TYPE} eq "int", "Target asset type attribute is a string")) {
        # the attribute is an asset name (we hope!)
        return $self->{_sourceEntityColumnValue} = $self->sourceAssetTypeName();
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

sub sourceAttributeName {
    my ($self) = @_;
    return $self->{sourceAttributeName} || "id";
}

sub targetAttributeName {
    my ($self) = @_;
    return $self->{targetAttributeName} || "id";
}

sub joinEntity {
    my ($self) = @_;
    return $self->{joinEntity};
}

sub setJoinEntity {
    my ($self, $value) = @_;
    my $jcd = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($value);
    return unless IF::Log::assert($jcd, "Join entity class exists");
    $self->{joinEntity} = $value;
    $self->{_jcd} = $jcd;
}

sub joinTable {
    my ($self) = @_;
    return $self->{JOIN_TABLE} || ($self->{_jcd} ? $self->{_jcd}->_table() : undef);
}

sub setJoinTable {
    my ($self, $value) = @_;
    $self->{JOIN_TABLE} = $value;
}

sub joinTargetAttribute {
    my ($self) = @_;
    return $self->{JOIN_TARGET_ATTRIBUTE};
}

sub setJoinTargetAttribute {
    my ($self, $value) = @_;
    $self->{JOIN_TARGET_ATTRIBUTE} = $value;
}

sub joinSourceAttribute {
    my ($self) = @_;
    return $self->{JOIN_SOURCE_ATTRIBUTE};
}

sub setJoinSourceAttribute {
    my ($self, $value) = @_;
    $self->{JOIN_SOURCE_ATTRIBUTE} = $value;
}

# what should this be?
sub type {
    my ($self) = @_;
    return "FLATTENED_TO_MANY";
}

sub qualifier {
    my ($self) = @_;
    return $self->{QUALIFIER};
}

sub joinQualifiers {
    my ($self) = @_;
    my $jq = $self->{JOIN_QUALIFIERS};
    if ($self->joinTable()) {
        if ($self->targetAssetTypeAttribute()) {
            # this refers to an attribute in the JOIN table
            my $k = $self->targetAssetTypeAttribute();
            if ($self->{_jcd}) {
                $k = $self->{_jcd}->columnNameForAttributeName($self->targetAssetTypeAttribute());
            }
            $jq->{$k} = $self->targetEntityColumnValue();
        }
        if ($self->sourceAssetTypeAttribute()) {
            # this refers to an attribute in the JOIN table
            my $k = $self->sourceAssetTypeAttribute();
            if ($self->{_jcd}) {
                $k = $self->{_jcd}->columnNameForAttributeName($self->sourceAssetTypeAttribute());
            }
            $jq->{$k} = $self->sourceEntityColumnValue();
        }
    }
    return $jq;
}

sub setJoinQualifiers {
    my ($self, $value) = @_;
    $self->{JOIN_QUALIFIERS} = $value;
}

1;
