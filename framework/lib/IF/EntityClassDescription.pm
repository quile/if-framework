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

package IF::EntityClassDescription;

use strict;
use IF::PrimaryKey;

use base qw(
    IF::Interface::KeyValueCoding
);

sub new {
    my $className = shift;
    my $self = shift;
    return undef unless $self;
    bless $self, $className;
    $self->awake();
    return $self;
}

sub awake {
    my $self = shift;

    # initialise instance
    while (my ($attributeName, $attribute) = each %{$self->attributes()}) {
        $self->{_attributeToColumnMappings}->{$attribute->{ATTRIBUTE_NAME}} = $attribute->{COLUMN_NAME};
    }
}

sub name {
    my $self = shift;
    return $self->{NAME};
}

sub relationships {
    my $self = shift;
    my $relationships = $self->{RELATIONSHIPS} || {};
    if ($self->parentEntityClassName()) {
        $relationships = { %$relationships, %{$self->parentEntityClassDescription()->relationships()} };
    }
    return $relationships;
}

sub mandatoryRelationships {
    my $self = shift;
    my $mandatoryRelationships = [];
    foreach my $relationshipName (keys %{$self->relationships()}) {
        my $relationship = $self->relationshipWithName($relationshipName);
        next unless $relationship->{IS_MANDATORY};
        push (@$mandatoryRelationships, $relationshipName);
    }
    return $mandatoryRelationships;
}

sub relationshipWithName {
    my ($self, $relationshipName) = @_;
    my $relationship = $self->relationships()->{$relationshipName};
    if (!$relationship && $self->parentEntityClassName()) {
        $relationship = $self->parentEntityClassDescription()->relationshipWithName($relationshipName);
    }
    my $r = IF::Relationship::Modelled->newFromModelEntryWithName($relationship, $relationshipName);
    return $r;
}

sub watchedAttributes {
    my $self = shift;
    return $self->{WATCHED_ATTRIBUTES} || [];
}

sub attributes {
    my $self = shift;
    return $self->{ATTRIBUTES} || {};
}

sub allAttributeNames {
    my $self = shift;
    return [keys %{$self->{_attributeToColumnMappings}}];
}

sub allAttributes {
    my $self = shift;
    return [values %{$self->attributes()}];
}

sub defaultValueForAttribute {
    my $self = shift;
    my $attributeName = shift;
    my $attribute = $self->attributeWithName($attributeName);
    return $attribute->{DEFAULT};
}

sub attributeWithName {
    my $self = shift;
    my $attributeName = shift;
    return $self->attributes()->{$attributeName} ||
        $self->attributes()->{IF::Interface::KeyValueCoding::keyNameFromNiceName($attributeName)} ||
        $self->attributes()->{uc($attributeName)} ||
        $self->attributes()->{lc($attributeName)};
}

sub hasAttributeWithName {
    my $self = shift;
    my $attributeName = shift;

    return 1 if ($self->attributeWithName($attributeName));
    foreach my $attributeKey (keys %{$self->attributes()}) {
        my $attribute = $self->attributes()->{$attributeKey};
        return 1 if ($attribute->{ATTRIBUTE_NAME} eq $attributeName);
    }
    return 0;
}

sub columnNameForAttributeName {
    my ($self, $attributeName) = @_;
    return $self->{_attributeToColumnMappings}->{$attributeName} || $attributeName;
}

sub attributeNameForColumnName {
    my ($self, $columnName) = @_;
    my $attribute = $self->attributeForColumnNamed($columnName);
    return unless $attribute;
    return $attribute->{ATTRIBUTE_NAME};
}

sub attributeForColumnNamed {
    my ($self, $columnName) = @_;
    return $self->attributeWithName($columnName);
}

sub parentEntityClassName {
    my $self = shift;
    return $self->{PARENT_ENTITY};
}

sub parentEntityClassDescription {
    my $self = shift;
    return IF::Model->entityClassDescriptionForEntityNamed($self->parentEntityClassName());
}

sub _table {
    my $self = shift;
    return $self->{TABLE} if $self->{TABLE};
    return $self->aggregateEntityClassDescription()->_table();
}

sub _primaryKey {
    my $self = shift;
    unless ($self->{_primaryKeyDefinition}) {
        $self->{_primaryKeyDefinition} = IF::PrimaryKey->new($self->{PRIMARY_KEY});
    }
    return $self->{_primaryKeyDefinition};
}

sub aggregateKeyName {
    my $self = shift;
    return $self->{AGGREGATE_KEY_NAME};
}

sub aggregateValueName {
    my $self = shift;
    return $self->{AGGREGATE_VALUE_NAME};
}

sub aggregateEntity {
    my $self = shift;
    return $self->{AGGREGATE_ENTITY};
}

sub aggregateTable {
    my $self = shift;
    return $self->{AGGREGATE_TABLE};
}

sub aggregateQualifier {
    my $self = shift;
    return $self->{AGGREGATE_QUALIFIER};
}

sub isReadOnly {
    my $self = shift;
    return $self->{IS_READ_ONLY};
}

sub isAggregateEntity {
    my $self = shift;

    return ($self->{AGGREGATE_TABLE} || $self->{AGGREGATE_ENTITY} || $self->{_isGenerated} );
}

sub aggregateEntityClassDescription {
    my $self = shift;
    if ($self->aggregateEntity()) {
        return IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($self->aggregateEntity());
    }
    if ($self->{_aggregateEntityClassDescription}) {
        return $self->{_aggregateEntityClassDescription};
    }

    # otherwise, create and cache an entity class description:
    my $attributes = {
        ID => _attributeWithNameAndColumnNameAndSizeAndType("id", "ID", 11, "int"),
        CREATION_DATE => _attributeWithNameAndColumnNameAndSizeAndType("creationDate", "CREATION_DATE", 11, "int"),
        MODIFICATION_DATE => _attributeWithNameAndColumnNameAndSizeAndType("modificationDate", "MODIFICATION_DATE", 11, "int"),
        $self->aggregateKeyName() => _attributeWithNameAndColumnNameAndSizeAndType(
                                            $self->aggregateKeyName(), $self->aggregateKeyName(), 32, "varchar"),
        $self->aggregateValueName() => _attributeWithNameAndColumnNameAndSizeAndType(
                                            $self->aggregateValueName(), $self->aggregateValueName(), undef, "text"),
    };

    my $primaryKeyObject = $self->_primaryKey();
    foreach my $field (@{$primaryKeyObject->keyFields()}) {
         $attributes->{$field} = $self->attributeWithName($field);
    }

    if ($self->aggregateQualifier()) {
        $attributes->{QUALIFIER} = $self->attributeWithName("QUALIFIER");
    }

    my $aecd = {
        TABLE => $self->aggregateTable(),
        PRIMARY_KEY => "ID",
        ATTRIBUTES => $attributes,
        _isGenerated => 1,
    };
    $self->{_aggregateEntityClassDescription} = IF::EntityClassDescription->new($aecd);
    return $aecd;
}

sub formattedCreationDate {
    my ($self, $time) = @_;
    my $gd = IF::GregorianDate->new($time);
    my $cd = $self->attributeWithName("creationDate");
    if ($cd && $cd->{TYPE} eq "datetime") {
        return $gd->sqlDateTime();
    }
    return $gd->utc();
}

sub formattedModificationDate {
    my ($self, $time) = @_;
    my $gd = IF::GregorianDate->new($time);
    my $md = $self->attributeWithName("modificationDate");
    if ($md && $md->{TYPE} eq "datetime") {
        return $gd->sqlDateTime();
    }
    return $gd->utc();
}

# TODO:  This *almost* belongs here but not quite

sub orderedAttributes {
    my $self = shift;

    # we decide on order like this:
    # 1. If there are indexed fields, we use those in order
    # 2. Check for important names like TYPE and geographic names
    # 3. All other attributes, grouped by type

    my $attributes = [];
    my $attributesLeftToOrder = [keys %{$self->attributes()}];
    my $attributeHasNotBeenOrdered = {map {$_ => 1} @$attributesLeftToOrder};
#    my $fullyIndexedFields = $self->{FULLY_INDEXED_FIELDS};
#    if ($fullyIndexedFields) {
#        foreach my $attribute (sort {$fullyIndexedFields->{$a} <=> $fullyIndexedFields->{$b}} keys %$fullyIndexedFields) {
#            next if ($attribute =~ /\./); # skip if it's a key-path
#            my $niceName = IF::Interface::KeyValueCoding::niceName($attribute);
#            next unless $self->hasAttributeWithName($niceName);
#            push (@$attributes, $self->attributeWithName($attribute));
#            delete $attributeHasNotBeenOrdered->{uc($attribute)};
#            delete $attributeHasNotBeenOrdered->{$niceName};
#        }
#    }

    my $IMPORTANT_FIELDS = [qw(NAME TITLE FIRST_NAME LAST_NAME DESCRIPTION MISSION ADD1 ADD2 CITY STATE COUNTRY ZIP
                               URL PHONE EMAIL FAX TYPE CATEGORY CONTACT_NAME CONTACT_EMAIL
                               ID CREATION_DATE MODIFICATION_DATE )];

    foreach my $attribute (@$IMPORTANT_FIELDS) {
        next unless ($attributeHasNotBeenOrdered->{$attribute} ||
                     $attributeHasNotBeenOrdered->{lc($attribute)}); # TODO: Fix all this nasty hackage
        my $niceName = IF::Interface::KeyValueCoding::niceName($attribute);
        IF::Log::debug($niceName);
        next unless ($self->hasAttributeWithName($niceName));
        #IF::Log::error("Has attribute $niceName");
        push (@$attributes, $self->attributeWithName($attribute));
        delete $attributeHasNotBeenOrdered->{$attribute};
        delete $attributeHasNotBeenOrdered->{lc($attribute)};
    }

    my $dateAttributes = [];
    my $textAttributes = [];
    my $enumAttributes = [];
    my $otherAttributes = [];
    foreach my $attributeLeftToBeOrdered (keys %$attributeHasNotBeenOrdered) {
        my $attribute = $self->attributeWithName($attributeLeftToBeOrdered);
        next unless $attribute;
        IF::Log::debug("Couldn't find attribute for $attributeLeftToBeOrdered") unless $attribute;
        if ($attributeLeftToBeOrdered =~ /DATE$/i) {
            push (@$dateAttributes, $attribute);
        } elsif ($attribute->{TYPE} =~ /(CHAR|TEXT|BLOB)/i) {
            push (@$textAttributes, $attribute);
        } elsif ($attribute->{TYPE} =~ /^ENUM$/i) {
            push (@$enumAttributes, $attribute);
        } else {
            push (@$otherAttributes, $attribute);
        }
    }
    push (@$attributes, @$dateAttributes, @$textAttributes, @$enumAttributes, @$otherAttributes);
    return $attributes;
}

#===============================================
# Geographic Location Handling ..

sub _geographicAttributeKeys {
    my ($self) = @_;
    return $self->{GEOGRAPHIC_ATTRIBUTE_KEYS};
}

sub hasGeographicData {
    my ($self) = @_;
    return defined($self->_geographicAttributeKeys());
}

sub geographicCountryNameKey {
    my ($self) = @_;
    return $self->_geographicAttributeKeys()->{COUNTRY_NAME};
}

sub geographicStateNameKey {
    my ($self) = @_;
    return $self->_geographicAttributeKeys()->{STATE_NAME};
}

sub geographicCityNameKey {
    my ($self) = @_;
    return $self->_geographicAttributeKeys()->{CITY_NAME};
}

sub geographicAddress1NameKey {
    my ($self) = @_;
    return $self->_geographicAttributeKeys()->{ADDRESS1_NAME};
}

sub geographicAddress2NameKey {
    my ($self) = @_;
    return $self->_geographicAttributeKeys()->{ADDRESS2_NAME};
}

# TODO: same for geographicMetroAreaNameKey(), geographicSuburbNameKey(), and geographicAreaNameKey()


#===============================================
sub _attributeWithNameAndColumnNameAndSizeAndType {
    # AndElvesAndOrcsesAndMen...Gollum!Gollum!
    my ($name, $columnName, $size, $type) = @_;
    return {
        'DEFAULT' => '',
        'EXTRA' => '',
        'SIZE' => $size,
        'NULL' => '',
        'ATTRIBUTE_NAME' => $name,
        'VALUES' => [],
        'COLUMN_NAME' => $columnName,
        'KEY' => '',
        'TYPE' => $type,
    };
}


1;
