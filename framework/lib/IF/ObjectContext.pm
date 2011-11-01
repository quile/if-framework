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

package IF::ObjectContext;

use strict;
use IF::DB;
use IF::Log;
use IF::Entity;
use IF::Entity::Persistent;
use IF::Model;
use IF::FetchSpecification;
use IF::Qualifier;
use IF::Cache;
use IF::Array;

use Try::Tiny;

my $_objectContext;

# This allows only singletons:
sub new {
    my $className = shift;
    return $_objectContext if $_objectContext;
    $_objectContext = {
        _shouldTrackEntities => 0,
        _saveChangesInProgress => 0,
        _trackedEntities => undef,
        _addedEntities => undef,
        _forgottenEntities => undef,
        _deletedEntities => undef,
        _model => undef,
    };
    bless $_objectContext, $className;
    $_objectContext->init();
    $_objectContext->loadModel();
    return $_objectContext;
}

sub init {
    my ($self) = @_;
    $self->initTrackingStore();
    $self->enableTracking();
    $self->{_saveChangesInProgress} = 0;
    return $self;
}

sub initTrackingStore {
    my ($self) = @_;
    $self->{_trackedEntities}   = IF::Dictionary->new();
    $self->{_deletedEntities}   = IF::Dictionary->new();
    $self->{_addedEntities}     = IF::Array->new();
    $self->{_forgottenEntities} = IF::Array->new();
}

sub loadModel {
    my $self = shift;
    #$DB::single = 1;
    $self->setModel(IF::Model->defaultModel());
}

sub model {
    my ($self) = @_;
    return $self->{_model};
}

sub setModel {
    my ($self, $value) = @_;
    $self->{_model} = $value;
}

# sub entityWithUniqueIdentifier {
#     my ($self, $ui) = @_;
#     return undef unless $ui;
#     my $e = $ui->entityName();
#     my $eid = $ui->externalId();
#     return $self->entityWithExternalId($e, $eid);
# }

sub entityWithPrimaryKey {
    my $self = shift;
    my $entityName = shift;
    my $id = shift;

    unless ($id) {
        #IF::Log::warning("Attempt to fetch $entityName with no key failed");
        #IF::Log::stack(7);
        return;
    }

    # // temporary hack - FIXME!
    my $uid = IF::Entity::UniqueIdentifier->newFromString($entityName, $id);
    my $tracked = $self->trackedInstanceOfEntityWithUniqueIdentifier($uid);
    return $tracked if $tracked;

    my $entityClassDescription = $self->model()->entityClassDescriptionForEntityNamed($entityName);
    return unless $entityClassDescription;

    my $keyQualifier = $entityClassDescription->_primaryKey()->qualifierForValue($id);
    my $fetchSpecification = IF::FetchSpecification->new($entityName, $keyQualifier);
    my $entities = $self->entitiesMatchingFetchSpecification($fetchSpecification);
    if (scalar @$entities > 1) {
        IF::Log::warning("Found more than one $entityName matching id $id");
        return $entities->[0];
    }
    if (scalar @$entities == 0) {
        IF::Log::warning("No $entityName matching id $id found");
        return;
    }
    return $entities->[0];
}

sub entityWithExternalId {
    my ($self, $entityName, $externalId) = @_;
    return undef unless $externalId;  # TODO: just have externalIdIsValid() check for this ?
    return undef unless IF::Log::assert(
        IF::Utility::externalIdIsValid($externalId),
        "entityWithExternalId(): externalId='$externalId' .. is valid for class name $entityName",
    );
    return $self->entityWithPrimaryKey($entityName, IF::Utility::idFromExternalId($externalId));
}

sub newInstanceOfEntity {
    my ($self, $entityName) = @_;
    return $self->entityFromHash($entityName, {});
}

sub entityFromHash {
    my ($self, $entityName, $hash) = @_;
    return undef unless $entityName;
    return undef unless $hash;
    my $entityClass = $self->model()->entityNamespace()."::$entityName";
    return $entityClass->new(%{$hash});
}

sub entityFromRawHash {
    my ($self, $entityName, $hash) = @_;
    return unless $entityName;
    return unless $hash;
    my $entityClass = $self->model()->entityNamespace()."::$entityName";
    return $entityClass->newFromRawDictionary($hash);
}

sub entityArrayFromHashArray {
    my ($self, $entityName, $hashArray) = @_;
    return undef unless $entityName;
    return undef unless $hashArray;
    my $entityClass = $self->model()->entityNamespace()."::$entityName";
    my $entityArray =[];
    for my $e (@$hashArray) {
        push (@$entityArray, $entityClass->new(%{$e}));
    }
    return $entityArray;
}

sub allEntities {
    my $self = shift;
    my $entityName = shift;
    return [] unless $entityName;
    my $fetchSpecification = IF::FetchSpecification->new($entityName);
    $fetchSpecification->setFetchLimit(0);
    return $self->entitiesMatchingFetchSpecification($fetchSpecification);
}

sub entitiesWithPrimaryKeys {
    my ($self, $entityName, $entityIds) = @_;

    my $entityClassDescription = $self->model()->entityClassDescriptionForEntityNamed($entityName);
    return [] unless $entityClassDescription;

    unless (IF::Log::assert(!$entityClassDescription->isAggregateEntity(), "Entity is not aggregate")) {
        return;
    }

    my $results = [];
    for (my $i=0; $i<=$#$entityIds; $i+=30) {
        my $idList = [];
        for (my $j=$i; $j<($i+30); $j++) {
            last unless $entityIds->[$j];
            push (@$idList, $entityIds->[$j]);
        }
        my $qualifier = IF::Qualifier->new("SQL",
                            $entityClassDescription->_primaryKey()->stringValue().
                            " IN (".join(",", @$idList).")"
                        );
        my $entities = $self->entitiesMatchingQualifier($entityName, $qualifier);
        push (@$results, @$entities);
    }
    return $results;
}

sub entityMatchingQualifier {
    my ($self, $entityName, $qualifier) = @_;
    my $entities = $self->entitiesMatchingQualifier($entityName, $qualifier);
    if (scalar @$entities > 1) {
        IF::Log::warning("More than one entity found for entityMatchingQualifier");
    }
    return $entities->[0];
}

sub entitiesMatchingQualifier {
    my ($self, $entityName, $qualifier) = @_;
    unless ($entityName) {
        IF::Log::error("You must specify an entity type");
        return;
    }
    return unless $qualifier;
    my $fetchSpecification = IF::FetchSpecification->new($entityName, $qualifier);
    return $self->entitiesMatchingFetchSpecification($fetchSpecification);
}

sub entityMatchingFetchSpecification {
    my $self = shift;
    my $fetchSpecification = shift;
    my $entities = $self->entitiesMatchingFetchSpecification($fetchSpecification);
    return $entities->[0];
}

sub entitiesMatchingFetchSpecification {
    my $self = shift;
    my $fetchSpecification = shift;

    return IF::Array->new() unless $fetchSpecification;
    my $results = IF::DB::rawRowsForSQLWithBindings($fetchSpecification->toSQLFromExpression());
    $results = IF::Array->new() unless $results;
    my $unpackedResults = $fetchSpecification->unpackResultsIntoEntitiesInObjectContext($results, $self);
    IF::Log::database("Matched ".scalar @$results." rows, ".scalar @$unpackedResults." result(s).");

    if ($self->trackingIsEnabled()) {
        $self->trackEntities($unpackedResults);
    }
    return $unpackedResults;
}

sub countOfEntitiesMatchingFetchSpecification {
    my $self = shift;
    my $fetchSpecification = shift;

    my $results = IF::DB::_driver()->countUsingSQL($fetchSpecification->toCountSQLFromExpression());
    IF::Log::database("Counted ".$results->[0]->{COUNT}." results");
    return $results->[0]->{COUNT};
}

sub resultsForSummarySpecification {
    my ($self, $summarySpecification) = @_;
    return [] unless $summarySpecification;
    my $results = IF::DB::rawRowsForSQLWithBindings($summarySpecification->toSQLFromExpression());
    my $unpackedResults = $summarySpecification->unpackResultsIntoDictionaries($results);
    IF::Log::database("Summary contained ".scalar @$unpackedResults." results");
    return [map { bless $_, "IF::Dictionary" } @$unpackedResults];
}


sub trackEntities {
    my ($self) = shift;
    my $entities;
    if (IF::Array::isArray($_[0])) {
        $entities = $_[0];
    } else {
        $entities = \@_;
    }
    foreach my $entity (@$entities) {
        #print STDERR "Tracking entity $entity\n";
        $self->trackEntity($entity);
    }
}

sub trackEntity {
    my ($self, $entity) = @_;
    return if $entity->isTrackedByObjectContext();
    if ($entity->hasNeverBeenCommitted()) {
        push (@{$self->{_addedEntities}}, $entity);
        $entity->awakeFromInsertionInObjectContext($self);
    } else {
        my $pkv = $entity->uniqueIdentifier()->description();
        if ($self->{_trackedEntities}->{$pkv}) {
            if ($self->{_trackedEntities}->{$pkv} == $entity) {
                # this instance is already being tracked
            } else {
                my $trackedEntity = $self->{_trackedEntities}->{$pkv};
                if ($trackedEntity->hasChanged()) {
                    # TODO what to do here?
                    IF::Log::error("Entity $pkv is already tracked by the ObjectContext but instances do not match");
                }
            }
        } else {
            $self->{_trackedEntities}->{$pkv} = $entity;
            $entity->awakeFromFetchInObjectContext($self);
        }
    }
    $self->{_forgottenEntities}->removeObject($entity);
    #print STDERR "Setting tracking object context of $entity to $self\n";
    $entity->setTrackingObjectContext($self);

    # if the entity that was just added has related
    # entities, we are going to track them too.
    # TODO:kd - watch for cycles here.
    my $relatedEntities = $entity->relatedEntities();
    foreach my $e (@$relatedEntities) {
        $self->trackEntity($e);
    }
}

sub untrackEntity {
    my ($self, $entity) = @_;
    my $e = $self->trackedInstanceOfEntity($entity) || $entity;
    unless ( $self->{_forgottenEntities}->containsObject($e) ) {
        $self->{_forgottenEntities}->addObject($e);
    }
    $self->{_addedEntities}->removeObject($e);
    unless ( $e->hasNeverBeenCommitted() ) {
        my $pkv = $e->uniqueIdentifier()->description();
        delete $self->{_trackedEntities}->{$pkv};
    }
    #print STDERR "Removing tracking object context of $e\n";
    $e->setTrackingObjectContext(undef);
}

sub entityIsTracked {
    my ($self, $entity) = @_;
    my $e = $self->trackedInstanceOfEntity($entity);
    return defined $e;
}

sub updateTrackedInstanceOfEntity {
    my ($self, $entity) = @_;
    return if $self->{_saveChangesInProgress};
    $self->untrackEntity($entity);
    $self->trackEntity($entity);
}

sub trackedInstanceOfEntity {
    my ($self, $entity) = @_;
    unless ($entity) {
        IF::Log::error("Cannot retrieve tracked instance of nil");
        return undef;
    }

    if ($entity->hasNeverBeenCommitted()) {
        # we can't check for it by pk
        if ($self->{_addedEntities}->containsObject($entity)) { return $entity }
        return undef;
    }
    my $pkv = $entity->uniqueIdentifier()->description();
    return $self->{_trackedEntities}->{$pkv} || $self->{_deletedEntities}->{$pkv};
}

sub trackedInstanceOfEntityWithUniqueIdentifier {
    my ($self, $uid) = @_;
    return $self->{_trackedEntities}->{$uid->description()};
}

# For now there's no real difference between
# inserting it into the ObjectContext and
# tracking stuff that comes from the DB - but
# maybe there will be so I'm adding this
# here.
sub insertEntity {
    my ($self, $entity) = @_;
    return unless $self->{_shouldTrackEntities};
    $self->trackEntity($entity);
}

sub forgetEntity {
    my ($self, $entity) = @_;
    return unless $self->{_shouldTrackEntities};
    $self->untrackEntity($entity);
}

sub deleteEntity {
    my ($self, $entity) = @_;
    return unless $self->{_shouldTrackEntities};
    # TODO add notifications
    return unless $entity->isTrackedByObjectContext();

    unless ($entity->hasNeverBeenCommitted()) {
        my $pkv = $entity->uniqueIdentifier->description();
        if ($self->{_deletedEntities}->{$pkv}) {
            if ($self->{_deletedEntities}->{$pkv} == $entity) {
                # this instance is already deleted - ignore
            } else {
                IF::Log::error("Can't delete $entity - object with same PK value has already been deleted");
            }
        } else {
            $self->{_deletedEntities}->{$pkv} = $entity;
        }
    }
}

# These are just here for testing; you generally won't want to use these.
sub forgottenEntities { return $_[0]->{_forgottenEntities} }
sub addedEntities     { return $_[0]->{_addedEntities}     }
sub deletedEntities   { return $_[0]->{_deletedEntities}   }

# we need to include _addedEntities here too; from the POV
# outside of the OC, added entities are "tracked" too.
sub trackedEntities {
    my ($self) = @_;
    return IF::Array->new()->initWithArrayRef([
        values %{$self->{_trackedEntities}},
        @{$self->{_addedEntities}},
        values %{$self->{_deletedEntities}},
    ]);
}

sub changedEntities {
    my ($self) = @_;
    my $changed = IF::Array->new();
    foreach my $e (values %{$self->{_trackedEntities}}) {
        if ($e->hasChanged()) {
            push @$changed, $e;
        }
    }
    return $changed;
}

sub enableTracking {
    my ($self) = @_;
    $self->{_shouldTrackEntities} = 1;
}

sub disableTracking {
    my ($self) = @_;
    $self->{_shouldTrackEntities} = 0;
}

sub trackingIsEnabled {
    my ($self) = @_;
    return $self->{_shouldTrackEntities};
}

sub saveChanges {
    my ($self) = @_;
    unless ($self->{_shouldTrackEntities}) {
        # TODO:kd - exceptions
        IF::Log::error("Can't call saveChanges on an ObjectContext that is not tracking");
        return;
    }

    # TODO Make transactions optional
    #[startTransaction];
    $self->{_saveChangesInProgress} = 1;

    try {
        # Process additions first.
        my $aes = $self->{_addedEntities};
        foreach my $ae (@{$self->{_addedEntities}}) {
            $ae->save();
        }

        # then updates
        my $updatedEntities = $self->{_trackedEntities}->allValues();
        foreach my $ue (@$updatedEntities) {
            $ue->save();
        }

        # then deletions
        my $des = $self->{_deletedEntities}->allValues();
        foreach my $de (@$des) {
            $des->_deleteSelf();
        }
    } catch {
        # [WMDB rollbackTransaction];
        IF::Log::error("Transaction failed: $_");
        return;
    };

    # I think we succeeded at this point, so
    # move the added entities into the trackedEntities
    # dictionary, clear the deletedEntities out,
    # and do some other housekeeping

    # NOTE: none of the exceptions thrown here are
    # likely ever to occur; conceivably they could,
    # and we need to check for them, but in general
    # this code shouldn't throw.
    try {
        foreach my $entity (@{$self->{_addedEntities}}) {
            if ($entity->hasNeverBeenCommitted()) {
                # this shouldn't be possible
                IF::Log::error("Failed to save new object $entity");
                return; #?
            }
            my $pkv = $entity->uniqueIdentifier()->description();
            if ($self->{_trackedEntities}->{$pkv}) {
                # this instance is already being tracked
                IF::Log::error("Newly saved object seems to be tracked already: $entity");
                return;
            } else {
                $self->{_trackedEntities}->{$pkv} = $entity;
            }
        }

        foreach my $entity (values %{$self->{_deletedEntities}}) {
            unless ($entity->wasDeletedFromDataStore()) {
                IF::Log::error("Object should have been deleted but wasn't: $entity");
                return;
            }
        }
    } catch {
        # [WMDB rollbackTransaction];
        IF::Log::error("Error during saveChanges: $_");
        $self->{_saveChangesInProgress} = 0;
        return;
    };

    $self->{_addedEntities}   = IF::Array->new();
    $self->{_deletedEntities} = IF::Dictionary->new();

    # hmmmm, do we really want to flush this?
    $self->{_forgottenEntities} = IF::Array->new();

    # otherwise, commit the transaction
    #[WMDB endTransaction];


    $self->{_saveChangesInProgress} = 0;
    #[WMLog debug:UTIL.object.repr(UTIL.keys(_trackedEntities))];
}

sub clearTrackedEntities {
    my ($self) = @_;
    my $all = $self->trackedEntities();
    foreach my $e (@$all) {
        $self->untrackEntity($e);
    }
    $self->initTrackingStore();
}

1;
