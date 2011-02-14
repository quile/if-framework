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

package IF::AggregateEntity;

use strict;
use base qw(
    IF::Entity::Persistent
);
use IF::_AggregatedKeyValuePair;

# An aggregate entity is made up of an array of other entities
# that are inflated and aggregated into a single entity.
# The definition of an aggregate entity must include at least:
# * The entity class name of the aggregated entities
# * A primary key field name (must be unique, but NOT an auto increment)
# * A key field name
# * A value field name
# Optionally, it can also include:
# * Ordering information for the aggregates
# * Relationships to other entities

sub initWithEntities {
    my ($self, $entities) = @_;
    $self->_setAggregatedEntities($entities);
}

sub initWithRows {
    my ($self, $rows) = @_;
    my $entities = [];
    foreach my $row (@$rows) {
        my $aggregatedKeyValuePair = IF::_AggregatedKeyValuePair->new();
        $aggregatedKeyValuePair->setEntityClassDescription($self->_aggregateEntityClassDescription());
        foreach my $key (keys %$row) {
            $aggregatedKeyValuePair->setStoredValueForKey($row->{$key}, $key);
        }
        push (@$entities, $aggregatedKeyValuePair);
    }
    $self->_setAggregatedEntities($entities);
}

# These two methods are for your aggregate entity accessors:
sub aggregateValueForKey {
    my ($self, $key) = @_;
    return $self->storedValueForKey($key);
}

sub setAggregateValueForKey {
    my ($self, $value, $key) = @_;
    return if ($self->isReadOnly());
    $self->setStoredValueForKey($value, $key);
}

sub isReadOnly {
    my $self = shift;
    #IF::Log::debug("ecn is $self->{_entityClassName}");
    return $self->entityClassDescription()->isReadOnly();
}

# private API for manipulating the aggregated entities

sub _aggregateKeyName {
    my $self = shift;
    return $self->entityClassDescription()->aggregateKeyName();
}

sub _aggregateValueName {
    my $self = shift;
    return $self->entityClassDescription()->aggregateValueName();
}

sub _setAggregatedEntities {
    my ($self, $entities) = @_;

    my $primaryKeyObject = $self->entityClassDescription()->_primaryKey();
    my $keyName = $self->_aggregateKeyName();
    my $valueName = $self->_aggregateValueName();
    IF::Log::debug("$primaryKeyObject, $keyName, $valueName");

    $self->{_aggregatedEntities} = $entities; # TODO hash them by key
    my $primaryKey;
    my $earliestCreationDate = 0;
    my $latestModificationDate = 0;

    foreach my $entity (@$entities) {
        unless ($primaryKey) {
            $primaryKey = $primaryKeyObject->valueForEntity($entity);
        } else {
            IF::Log::assert($primaryKey eq $primaryKeyObject->valueForEntity($entity), "Aggregate primary key field is identical for all aggregated entities");
        }

        my $key = $entity->valueForKey($keyName);
        my $value = $entity->valueForKey($valueName);

        $self->addStoredValueForKey($value, $key);
        if ($earliestCreationDate == 0 || $earliestCreationDate > $entity->valueForKey("creationDate")) {
            $earliestCreationDate = $entity->valueForKey("creationDate");
        }
        if ($latestModificationDate == 0 || $latestModificationDate < $entity->valueForKey("modificationDate")) {
            $latestModificationDate = $entity->valueForKey("modificationDate");
        }
    }
    $self->setCreationDate($earliestCreationDate);
    $self->setModificationDate($latestModificationDate);
    $self->_setAggregatePrimaryKey($primaryKey);
}

sub _aggregatedEntitiesFromKeyValuePairs {
    my $self = shift;
    my $entities = [];
    my $aggregateEntityClass = $self->entityClassDescription()->aggregateEntity() || "IF::_AggregatedKeyValuePair";
    my $primaryKeyObject = $self->entityClassDescription()->_primaryKey();
    my $keyName = $self->_aggregateKeyName();
    my $valueName = $self->_aggregateValueName();
    my $aggregateQualifier = $self->entityClassDescription()->aggregateQualifier();
    #IF::Log::dump($self->storedKeys());
    foreach my $key (@{$self->storedKeys()}) {
        next if ($self->_keyIsPrivate($key));
        my $value = $self->storedValueForKey($key);
        unless (IF::Array::isArray($value)) {
            $value = [$value];
        }
        foreach my $v (@$value) {
            #IF::Log::debug("Key = $key, value = $value");
            my $entity;
            if ($aggregateEntityClass eq "IF::_AggregatedKeyValuePair") {
                $entity = IF::_AggregatedKeyValuePair->new();
                $entity->setEntityClassDescription($self->_aggregateEntityClassDescription());
            } else {
                $entity = IF::ObjectContext->new()->entityFromHash($aggregateEntityClass, {});
            }
            next unless $entity;
            $entity->setValueForKey($v, $valueName);
            $entity->setValueForKey($key, $keyName);
            $primaryKeyObject->setValueForEntity($self->id(), $entity);
            $entity->setValueForKey($self->creationDate(), "creationDate");
            $entity->setValueForKey($self->modificationDate(), "modificationDate");
            push (@$entities, $entity);
        }
    }
    return $entities;
}

sub _keyIsPrivate {
    my ($self, $key) = @_;
    return 1 if ($key eq "wasInflated");
    my $primaryKeyObject = $self->entityClassDescription()->_primaryKey();
    return 1 if ($primaryKeyObject->hasKeyField($key));
    foreach my $attribute (values %{$self->entityClassDescription()->{ATTRIBUTES}}) {
        IF::Log::debug("Checking attribute $attribute->{ATTRIBUTE_NAME} for $key");
        return 1 if ($attribute->{ATTRIBUTE_NAME} eq $key &&
                     $primaryKeyObject->hasKeyField($attribute->{COLUMN_NAME}));
    }
    return 0;
}

# This stuff is too damn complex right now:
#sub _addAggregatedEntityForKey {
#    my ($self, $entity, $key) = @_;
#    if (exists($self->{_aggregatedEntities}->{$key})) {
#        push (@{$self->{_aggregatedEntities}->{$key}}, $entity);
#    } else {
#        $self->{_aggregatedEntities}->{$key} = [$entity];
#    }
#}
#
#sub _aggregatedEntitiesForKey {
#    my ($self, $key) = @_;
#    return $self->{_aggregatedEntities}->{$key} || [];
#}

sub _aggregateEntityClassDescription {
    my $self = shift;
    return $self->entityClassDescription()->aggregateEntityClassDescription();
}

sub _setAggregatePrimaryKey {
    my ($self, $value) = @_;
    my $primaryKeyObject = $self->entityClassDescription()->_primaryKey();
    $primaryKeyObject->setValueForEntity($value, $self);
}

sub id {
    my $self = shift;
    my $primaryKeyObject = $self->entityClassDescription()->_primaryKey();
    return $primaryKeyObject->valueForEntity($self);
}

sub hasNeverBeenCommitted {
    my $self = shift;
    my $primaryKeyObject = $self->entityClassDescription()->_primaryKey();
    my $values = $primaryKeyObject->valuesForEntity($self);
    foreach my $value (@$values) {
        return 0 if $value;
    }
    return 1;
}

sub save {
    my $self = shift;
    my $when = shift || "NOW";
    return unless $self->isValidForCommit();
    return if $self->isReadOnly();
    my $entityClassDescription = $self->entityClassDescription();
#
#    # First, check all the cached related entities and see
#    # if any of them need to be committed
#    my $relationships = $entityClassDescription->relationships();
#    my $primaryKey = $entityClassDescription->_primaryKey();
#
#    foreach my $relationshipName (keys %$relationships) {
#        my $relationship = $relationships->{$relationshipName};
#        next unless ($relationship->{TYPE} eq "TO_ONE" &&
#                     uc($relationship->{SOURCE_ATTRIBUTE}) ne uc($primaryKey));
#
#        foreach my $entity (@{$self->_cachedEntitiesForRelationshipNamed($relationshipName)}) {
#            unless ($entity) {
#                IF::Log::error("Undefined entity in ".$relationshipName." on ".$entityClassDescription->name());
#                next;
#            }
#            $entity->save();
#            $self->setValueForKey($entity->valueForKey($relationship->{TARGET_ATTRIBUTE}), $relationship->{SOURCE_ATTRIBUTE});
#        }
#    }

    # Allow the object a chance to react before being committed to the DB
    $self->prepareForCommit();

    # remove all previous rows if there were any:
    unless ($self->hasNeverBeenCommitted()) {
        IF::Log::debug("HAS BEEN COMMITTED");
        foreach my $entity (@{$self->{_aggregatedEntities}}) {
            IF::Log::debug("Deleting entity $entity");
            $entity->_deleteSelf();
        }
    }

     # commit all the k-v pairs
     # if we have no id, get the id from the first committed row
     # and use that for subsequent rows
     my $entities = $self->_aggregatedEntitiesFromKeyValuePairs();
     my $primaryKeyObject = $entityClassDescription->_primaryKey();
     unless (scalar @$entities == 0) {
         my $aggregateKey = $self->id();
         unless ($aggregateKey) {
             my $firstEntity = $entities->[0];
            $firstEntity->save();

             $aggregateKey = $firstEntity->valueForKey("id");
         }
          IF::Log::debug("Aggregate PK is $aggregateKey");
         foreach my $entity (@$entities) {
            $primaryKeyObject->setValueForEntity($aggregateKey, $entity);
            if ($self->entityClassDescription()->aggregateQualifier()) {
                $entity->setValueForKey($entityClassDescription->aggregateQualifier(), "QUALIFIER");
            }
            $entity->save();
         }
         $self->{_aggregatedEntities} = $entities;
         $self->_setAggregatePrimaryKey($aggregateKey);
     }

    $self->markAllStoredValuesAsClean();

    # now that we've committed the object, we can
    # fix relationships
#    foreach my $relationshipName (keys %$relationships) {
#        my $relationship = $relationships->{$relationshipName};
#        next if ($relationship->{TYPE} eq "TO_ONE" &&
#                     uc($relationship->{SOURCE_ATTRIBUTE}) ne uc($primaryKey));
#
#        foreach my $deletedEntity (@{$self->_deletedEntitiesForRelationshipNamed($relationshipName)}) {
#            $deletedEntity->_deleteSelf(); # WRONG
#        }
#
#        foreach my $entity (@{$self->_cachedEntitiesForRelationshipNamed($relationshipName)}) {
#            if ($relationship->{TYPE} eq "TO_ONE" || $relationship->{TYPE} eq "TO_MANY") {
#                my $targetAttribute = $relationship->{TARGET_ATTRIBUTE};
#                my $sourceAttribute = $relationship->{SOURCE_ATTRIBUTE};
#
#                IF::Log::debug("Setting ".$targetAttribute." to ".$self->valueForKey($sourceAttribute));
#                $entity->setValueForKey($self->valueForKey($sourceAttribute), $targetAttribute);
#                $entity->save();
#            } elsif ($relationship->{TYPE} eq "FLATTENED_TO_MANY") {
#                if ($entity->hasNeverBeenCommitted()) {
#                    $entity->save();
#                }
#                # build a join record for the join table
#                my $record = {
#                    $relationship->{JOIN_TARGET_ATTRIBUTE} => $self->valueForKey($relationship->{SOURCE_ATTRIBUTE}),
#                    $relationship->{JOIN_SOURCE_ATTRIBUTE} => $entity->valueForKey($relationship->{TARGET_ATTRIBUTE}),
#                    %{$entity->_deprecated_relationshipHints()},
#                };
#                IF::DB::updateRecordInDatabase(undef, $record, $relationship->{JOIN_TABLE});
#            }
#        }
#
#        delete $self->{_relatedEntities}->{$relationshipName}->{removedEntities};
#        delete $self->{_relatedEntities}->{$relationshipName}->{deletedEntities};
#    }

}

sub _deleteSelf {
    my $self = shift;

    if ($self->wasDeletedFromDataStore() || $self->hasNeverBeenCommitted()) {
        IF::Log::warning("Can't delete $self, object has never been committed or has already been deleted");
        return;
    }
    return unless ($self->canBeDeleted());

    # Apply cascading delete rules
    my $entitiesToDelete = $self->entitiesForDeletionByRules();
    #IF::Log::debug("Scheduled to delete these entities:");
    my $objectContext = IF::ObjectContext->new();
    foreach my $entityToDelete (@$entitiesToDelete) {
        $objectContext->deleteEntity($entityToDelete);
    }

    # check relationships for NULLIFY rules
    foreach my $relationshipName (keys %{$self->entityClassDescription()->relationships()}) {
        my $relationship = $self->relationshipNamed($relationshipName);
        next unless $relationship;
        if ($relationship->{DELETION_RULE} eq "FORCED_REMOVAL") {
            $self->removeAllEntitiesForRelationshipDirectlyFromDatabase($relationshipName);
        } elsif ($relationship->{DELETION_RULE} eq "NULLIFY") {
            if ($relationship->{TYPE} eq "FLATTENED_TO_MANY") {
                $self->removeAllObjectsFromBothSidesOfRelationshipWithKey($relationshipName);
            } else {
                # for now only allow NULLIFY for relationships that link to this entity's PK:
                if ($relationship->{SOURCE_ATTRIBUTE} eq $self->entityClassDescription()->_primaryKey()) {
                    foreach my $entity (@{$self->entitiesForRelationshipNamed($relationshipName)}) {
                        $entity->setValueForKey(0, $relationship->{TARGET_ATTRIBUTE});
                        $entity->save();
                    }
                }
            }
        }
    }

    IF::Log::debug("==> _deleteSelf() called for ".ref($self).", destroying record with ID ".$self->{ID}."\n");
    $self->willBeDeleted();

    # remove all previous rows if there were any:
    unless ($self->hasNeverBeenCommitted()) {
        foreach my $entity (@{$self->{_aggregatedEntities}}) {
            $entity->_deleteSelf();
        }
    }

    $self->{_wasDeletedFromDataStore} = 1;
}

sub creationDate {
    my $self = shift;
    return $self->{_creationDate};
}

sub setCreationDate {
    my ($self, $value) = @_;
    $self->{_creationDate} = $value;
}

sub modificationDate {
    my $self = shift;
    return $self->{_modificationDate};
}

sub setModificationDate {
    my ($self, $value) = @_;
    $self->{_modificationDate} = $value;
}

sub wasInflated {
    my ($self) = @_;
    return $self->{wasInflated};
}

sub setWasInflated {
    my ($self, $value) = @_;
    $self->{wasInflated} = $value;
}

sub _table {
    my $self = shift;
    return $self->_aggregateEntityClassDescription()->_table();
}

#----------------------------------------------
# This stuff should be moved into its own
# "interface" but for now we just override
# the parent class's implementation to
# clean it up and simplify it

sub initStoredValuesWithArray {
    my $self = shift;
    my $storedValueArray = shift;
    my $storedValues = {@$storedValueArray};
    foreach my $key (keys %$storedValues) {
        #IF::Log::debug("init ".$key." - ".$storedValues->{$key});
        $self->setStoredValueForRawKey($storedValues->{$key}, $key);
    }
}

sub storedKeys {
    my $self = shift;
    return [keys %{$self->{__storedValues}}];
}

sub storedValueForKey {
    my $self = shift;
    my $key = shift;
    return $self->storedValueForRawKey($key);
}

sub storedValueForRawKey {
    my $self = shift;
    my $key = shift;
    return unless exists($self->{__storedValues}->{$key});
    return $self->{__storedValues}->{$key}->{v};
}

sub addStoredValueForKey {
    my ($self, $value, $key) = @_;
    if (exists($self->{__storedValues}->{$key}->{v})) {
        if (IF::Array::isArray($self->{__storedValues}->{$key}->{v})) {
            push (@{$self->{__storedValues}->{$key}->{v}}, $value);
        } else {
            $self->{__storedValues}->{$key}->{v} = [ $self->{__storedValues}->{$key}->{v} , $value ];
        }
    } else {
        $self->setStoredValueForKey($value, $key);
    }
}

sub setStoredValueForKey {
    my ($self, $value, $key) = @_;
    $self->setStoredValueForRawKey($value, $key);
}

sub setStoredValueForRawKey {
    my ($self, $value, $key) = @_;
    return if (exists($self->{__storedValues}->{$key}->{v})
            && !(IF::Array::isArray($value) || IF::Array::isArray($self->{__storedValues}->{$key}->{v}))
            && $value eq $self->{__storedValues}->{$key}->{v});

    if (!exists($self->{__storedValues}->{$key}->{o}) &&
        exists($self->{__storedValues}->{$key}->{v})) {
        $self->{__storedValues}->{$key}->{o} = $self->{__storedValues}->{$key}->{v};
    }
    $self->{__storedValues}->{$key}->{v} = $value;
    $self->{__storedValues}->{$key}->{d} = 1;
}

sub revertToSaved {
    my $self = shift;
    foreach my $key (keys %{$self->{__storedValues}}) {
        next unless $self->{__storedValues}->{$key}->{o};
        $self->{__storedValues}->{$key}->{v} = $self->{__storedValues}->{$key}->{o};
        delete $self->{__storedValues}->{$key}->{o};
    }
    $self->markAllStoredValuesAsClean();
}

sub revertToSavedValueForRawKey {
    my ($self, $key) = @_;
    unless ($self->{__storedValues}->{$key}->{o}) {
        IF::Log::warning("Attempt to revert to saved value for key $key failed because there is no saved value");
        return;
    }
    $self->{__storedValues}->{$key}->{v} = $self->{__storedValues}->{$key}->{o};
    delete $self->{__storedValues}->{$key}->{o};
    delete $self->{__storedValues}->{$key}->{d};
}

sub storedValueForKeyHasChanged {
    my $self = shift;
    my $key = shift;
    return 0 unless $self->{__storedValues}->{$key}->{d};
    return 1;
}

sub removeStoredValueForKey {
    my ($self, $key) = @_;
    delete $self->{__storedValues}->{$key};
}

sub currentStoredRepresentation {
    my $self = shift;
    return if $self->hasNeverBeenCommitted();
    my $objectContext = IF::ObjectContext->new();
    my $isUsingCache = $objectContext->shouldUseCache();
    $objectContext->setShouldUseCache(0);
    my $entity = $objectContext->entityWithPrimaryKey($self->{_entityClassName}, $self->id());
    $objectContext->setShouldUseCache($isUsingCache);
    return $entity;
}

1;
