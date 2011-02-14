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

my $_objectContext;

# This allows only singletons:
sub new {
    my $className = shift;
    return $_objectContext if $_objectContext;
    my $self = { _cachedEntitiesByEntityClass => {},
#                 _fileCache => IF::Cache::cacheOfTypeWithName("MemCached", "Entities"),
#                 _shouldUseCache => 1,
             };
    bless $self, $className;
    $self->loadModel();
    unless ($self->{_model}) {
        IF::Log::error("Error loading default model into ObjectContext, application is not initialized");
        return undef;
    }
    $_objectContext = $self;
    return $self;
}

sub loadModel {
    my $self = shift;
    $self->setModel(IF::Model->defaultModel());
}

sub model {
    my $self = shift;
    return $self->{_model};
}

sub setModel {
    my $self = shift;
    $self->{_model} = shift;
}

sub entityWithUniqueIdentifier {
    my ($self, $ui) = @_;
    return undef unless $ui;
    my $e = $ui->entityName();
    my $eid = $ui->externalId();
    return $self->entityWithExternalId($e, $eid);
}

sub entityWithPrimaryKey {
    my $self = shift;
    my $entityName = shift;
    my $id = shift;

    unless ($id) {
        #IF::Log::warning("Attempt to fetch $entityName with no key failed");
        #IF::Log::stack(7);
        return;
    }

    if ($self->hasCachedEntityWithIdForEntityClass($id, $entityName) && $self->shouldUseCache()) {
        IF::Log::debug("Cache hit for entity $entityName with id $id");
        return $self->cachedEntityWithIdForEntityClass($id, $entityName);
    }
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
    #if ($self->{_fileCache}) {
    #    $self->{_fileCache}->setCachedValueForKey($entities->[0], $cacheKey);
    #}
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
    my $self = shift;
    my $entityName = shift;
    my $entityIds = shift;


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
    $self->addEntitiesToCache($results) if $self->shouldUseCache();
    return $results;
}

sub entityMatchingQualifier {
    my $self = shift;
    my $entityName = shift;
    my $qualifier = shift;
    my $entities = $self->entitiesMatchingQualifier($entityName, $qualifier);
    if (scalar @$entities > 1) {
        IF::Log::warning("More than one entity found for entityMatchingQualifier");
    }
    return $entities->[0];
}

sub entitiesMatchingQualifier {
    my $self = shift;
    my $entityName = shift;
    my $qualifier = shift;
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
    return $self->entitiesMatchingFetchSpecificationUsingSQLExpressions($fetchSpecification);
}

sub entitiesMatchingFetchSpecificationUsingSQLExpressions {
    my $self = shift;
    my $fetchSpecification = shift;

    return [] unless $fetchSpecification;
    my $results = IF::DB::rawRowsForSQLWithBindings($fetchSpecification->toSQLFromExpression());
    $results = [] unless $results;
    my $unpackedResults = $fetchSpecification->unpackResultsIntoEntities($results);
    $self->addEntitiesToCache($unpackedResults) if $self->shouldUseCache();
    IF::Log::database("Matched ".scalar @$results." rows, ".scalar @$unpackedResults." result(s).");
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

sub deleteEntity {
    my $self = shift;
    my $entity = shift;
    if (UNIVERSAL::can($entity, "_deleteSelf")) {
        $entity->_deleteSelf();
    }
}

sub clearCachedEntities {
    my $self = shift;
    $self->{_cachedEntitiesByEntityClass} = {};
    IF::Log::debug("Cached entities cleared");
}

sub hasCachedEntityWithIdForEntityClass {
    my $self = shift;
    my $id = shift;
    my $entityClass = shift;
    return 1 if $self->{_cachedEntitiesByEntityClass}->{$entityClass}->{$id};
    return 0;
}

sub cachedEntityWithIdForEntityClass {
    my $self = shift;
    my $id = shift;
    my $entityClass = shift;
    return $self->{_cachedEntitiesByEntityClass}->{$entityClass}->{$id};
}

sub cachedEntitiesOfClass {
    my $self = shift;
    my $entityClass = shift;
    return $self->{_cachedEntitiesByEntityClass}->{$entityClass};
}

sub addEntityToCache {
    my $self = shift;
    my $entity = shift;
    $self->{_cachedEntitiesByEntityClass}->{$entity->_entityClassName()}->{$entity->id()} = $entity;
    IF::Log::debug("Added entity $entity to cache");
}

sub addEntitiesToCache {
    my $self = shift;
    my $entities = shift;
    foreach my $entity (@$entities) {
        $self->addEntityToCache($entity);
    }
}

sub shouldUseCache {
    my $self = shift;
    return $self->{_shouldUseCache};
}

sub setShouldUseCache {
    my $self = shift;
    $self->{_shouldUseCache} = shift;
}

1;
