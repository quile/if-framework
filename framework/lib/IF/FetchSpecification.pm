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

#=====================================
# FetchSpecification
# Abstracts the workings of SQL
# SELECT statements
# from the app developers
#======================================

package IF::FetchSpecification;

use strict;
use IF::Model;
use IF::Log;
use IF::Qualifier;
use IF::SQLExpression;


# Class methods

sub new {
    my ($className, $source, $qualifier, $sortOrderings) = @_;
    my $model = IF::Model->defaultModel();
    unless (IF::Log::assert($model, "Found a model to work with")) {
        return;
    }
    my $entityClassDescription = $model->entityClassDescriptionForEntityNamed($source);
    unless (IF::Log::assert($entityClassDescription, "Has entity class description for $source")) {
        return undef;
    }
    # for the purposes of fetching entities, we need to check if the
    # entity is an aggregate entity or a regular one, and if it's aggregate,
    # use the aggregate entityClassDescription instead

    # TODO:  Clean this mess up:
    my $self = {
        entity => $source,
        _entityClassDescription => $entityClassDescription,
        _tables => {},
        _prefetchingRelationships => [],
        _traversedRelationshipAttributes => {},
        distinct => 0,
        attributes => [],
        sortOrderings => $sortOrderings,
        fetchLimit => IF::Application->defaultApplication()->configurationValueForKey("DEFAULT_BATCH_SIZE"),
        startIndex => 0,
        _sqlExpression => IF::SQLExpression->new(),
    };

    bless $self, $className;
    if ($entityClassDescription->isAggregateEntity()) {
        # This is what we're fetching, so tell it to fetch the aggregate one
        $self->{_entityClassDescription} = $entityClassDescription->aggregateEntityClassDescription();
        # This is ultimately what we'll end up with:
        $self->{_rootEntityClassDescription} = $entityClassDescription;
        $self->{_isAggregateEntity} = 1; # not sure if we need this?
    }

    $self->setQualifier($qualifier);
    return $self;
}

sub subqueryForAttributes {
    my ($self, $attributes) = @_;
    $self->restrictFetchToAttributes($attributes);
    $self->setFetchLimit(); # have to zero the fetch limit for subqueries
    return $self;
}

sub restrictFetchToAttributes {
    my ($self, $attributes) = @_;
    $attributes = IF::Array->arrayFromObject($attributes);
    my $columnNames = [];
    my $model = IF::Model->defaultModel();
    foreach my $attribute (@$attributes) {
        if ($attribute =~ /\./) {
            my ($rn, $a) = split(/\./, $attribute);
            #IF::Log::debug("Restricting fetch to attribute $a on relationship $rn");
            my $r = $self->{_entityClassDescription}->relationshipWithName($rn);
            if ($r) {
                my $recd = $r->targetEntityClassDescription();
                if ($recd) {
                    my $ra = $recd->columnNameForAttributeName($a);
                    if ($ra) {
                        $self->addAttributeForTraversedRelationship($ra, $rn);
                    }
                }
            }
        } else {
            push (@$columnNames, $self->{_entityClassDescription}->columnNameForAttributeName($attribute));
        }
    }
    $self->setAttributes($columnNames); # TODO I hate this misnamed stuff! argh!
}

sub qualifier {
    my $self = shift;
    return $self->{qualifier};
}

sub setQualifier {
    my $self = shift;
    $self->{qualifier} = shift;
    return unless $self->{qualifier};
    $self->{qualifier}->setEntity($self->{entity});
}

sub sqlExpression {
    my $self = shift;
    return $self->{_sqlExpression};
}

sub entityName {
    my $self = shift;
    return $self->{entity};
}

sub distinct {
    my $self = shift;
    $self->{distinct};
}

sub setDistinct {
    my $self = shift;
    $self->{distinct} = shift;
}

# TODO: right now fetch limit and batch size are the same
sub fetchLimit {
    my $self = shift;
    return $self->{fetchLimit};
}

sub setFetchLimit {
    my $self = shift;
    $self->{fetchLimit} = shift;
}

sub batchSize {
    my $self = shift;
    return $self->fetchLimit();
}

sub setBatchSize {
    my $self = shift;
    my $value = shift;
    $self->setFetchLimit($value);
}

sub shouldFetchRandomly {
    my ($self) = @_;
    return $self->{shouldFetchRandomly};
}

sub setShouldFetchRandomly {
    my ($self, $value) = @_;
    $self->{shouldFetchRandomly} = $value;
}

sub startIndex {
    my $self = shift;
    return $self->{startIndex};
}

sub setStartIndex {
    my $self = shift;
    $self->{startIndex} = shift;
}

sub setStartIndexForNextBatch {
    my $self = shift;
    return unless $self->{fetchLimit};
    $self->{startIndex} += $self->{fetchLimit};
}

sub setSortOrderings {
    my ($self, $value) = @_;
    $self->{sortOrderings} = IF::Array->arrayFromObject($value);
}

sub sortOrderings {
    my $self = shift;
    return $self->{sortOrderings};
}

sub inflateAsInstancesOfEntityNamed {
    my ($self) = @_;
    return $self->{inflateAsInstancesOfEntityNamed};
}

sub setInflateAsInstancesOfEntityNamed {
    my ($self, $value) = @_;
    $self->{inflateAsInstancesOfEntityNamed} = $value;
}

# Damn, this can only be done once this way.
# TODO: rewrite to allow re-entrant code
sub setPrefetchingRelationships {
    my $self = shift;
    $self->{_prefetchingRelationships} = shift || [];
    foreach my $relationship (@{$self->{_prefetchingRelationships}}) {
        IF::Log::debug("Setting prefetch on relationship '$relationship'");
        $self->sqlExpression()->addPrefetchedRelationshipOnEntity($relationship,
                            $self->{_entityClassDescription});
    }
}

sub prefetchingRelationships {
    my $self = shift;
    return $self->{_prefetchingRelationships};
}

sub attributes {
    my $self = shift;
    return $self->{attributes} if (scalar @{$self->{attributes}});
    return [keys %{$self->{_entityClassDescription}->attributes()}];
}

sub setAttributes {
    my $self = shift;
    $self->{attributes} = shift;
}

sub attributesForTraversedRelationship {
    my ($self, $r) = @_;
    return $self->{_traversedRelationshipAttributes}->{$r} || [];
}

sub setAttributesForTraversedRelationship {
    my ($self, $value, $r) = @_;
    $self->{_traversedRelationshipAttributes}->{$r} = IF::Array->arrayFromObject($value);
}

sub addAttributeForTraversedRelationship {
    my ($self, $attribute, $r) = @_;
    my $as = $self->attributesForTraversedRelationship($r);
    push (@$as, $attribute);
    $self->setAttributesForTraversedRelationship($as, $r);
}

sub addDynamicRelationshipWithName {
    my ($self, $dr, $name) = @_;
    return unless IF::Log::assert($dr && $name, "Adding dynamic relationship with name $name");
    # This is bogus because it has a side-effect of altering the
    # dynamic relationship, but that's OK because these are
    # supposed to be discarded once used
    $dr->setEntityClassDescription($self->entityClassDescription());
    $dr->setName($name);
    $self->sqlExpression()->addDynamicRelationship($dr);
}

sub buildSQLExpression {
    my $self = shift;
    my $model = IF::Model->defaultModel();

    my $sq = $self->sqlExpression();

    $sq->setDistinct($self->distinct());
    $sq->setShouldFetchRandomly($self->shouldFetchRandomly());
    $sq->setInflateAsInstancesOfEntityNamed($self->inflateAsInstancesOfEntityNamed());

    # populate sql expression:
    # 1. set the basic root entity class for the fetch.  This also
    #    populates the table and column lists for this entity
    $sq->addEntityClassDescription($self->{_entityClassDescription});

    # 1a. Automatically traverse any dynamic relationships that have been added
    foreach my $rn (@{$sq->dynamicRelationshipNames()}) {
        IF::Log::debug("Forcing traversal of dynamic relationship $rn");
        $sq->addTraversedRelationshipOnEntity($rn, $self->{_entityClassDescription});
    }

    if (scalar @{$self->{attributes}} > 0) {
        foreach my $attribute (@{$self->{attributes}}) {
            $sq->onlyFetchColumnForTable($attribute, $self->{_entityClassDescription}->_table());
        }
    }

    # aieeee, TODO optimise this so we don't keep doing this everywhere.
    foreach my $rn (keys %{$self->{_traversedRelationshipAttributes}}) {
        my $r = $self->{_entityClassDescription}->relationshipWithName($rn);
        if ($r) {
            my $recd = $model->entityClassDescriptionForEntityNamed($r->{TARGET_ENTITY});
            if ($recd) {
                my $rt = $recd->_table();
                foreach my $a (@{$self->attributesForTraversedRelationship($rn)}) {
                    $sq->onlyFetchColumnForTable($a, $rt);
                }
            }
        }
    }

    $sq->addTableToFetch($self->{_entityClassDescription}->_table());

    # 1b. Check for mandatory relationships and add them to the prefetch
    #IF::Log::debug("Mandatory relationships:");
    foreach my $mandatoryRelationship (@{$self->{_entityClassDescription}->mandatoryRelationships()}) {
        $sq->addPrefetchedRelationshipOnEntity($mandatoryRelationship,
                            $self->{_entityClassDescription});
    }



    # 2. tell the Qualifier Tree to generate SQL.  This will also
    #    fill in any traversed relationships that are found
    if ($self->qualifier()) {
        my $sqlQualifier = $self->qualifier()->sqlWithBindValuesForExpressionAndModel($sq, $model);
        $sq->setQualifier($sqlQualifier->{SQL});
        $sq->setQualifierBindValues($sqlQualifier->{BIND_VALUES});
    }

    # 3. Fill in what's left
    $sq->setSortOrderings($self->{sortOrderings});
    # TODO implement batched fetching for aggregates too.  For now, turn off
    # the fetch limit and index
    unless ($self->{_isAggregateEntity}) {
        $sq->setFetchLimit($self->fetchLimit());
        $sq->setStartIndex($self->{startIndex});
    }
}

sub toSQLFromExpression {
    my $self = shift;

    $self->buildSQLExpression();

    # Generate the SQL for the whole statement, and return it and
    # the bind values ready to be passed to the DB
    return {
        SQL => $self->sqlExpression()->selectStatement(),
        BIND_VALUES => $self->sqlExpression()->bindValues(),
    };
}

sub toCountSQLFromExpression {
    my $self = shift;

    $self->buildSQLExpression();

    # Generate the SQL for the whole statement, and return it and
    # the bind values ready to be passed to the DB
    return {
        SQL => $self->sqlExpression()->selectCountStatement(),
        BIND_VALUES => $self->sqlExpression()->bindValues(),
    };
}

sub resolveEntityHash {
    my $self = shift;
    my $hash = shift;
    my $primaryEntity = shift;
    return unless $primaryEntity;
    delete $hash->{$self->{entity}};
    foreach my $entityType (keys %$hash) {
        if ($entityType eq '_RELATIONSHIP_HINTS') {
            $primaryEntity->_deprecated_setRelationshipHints($hash->{$entityType});
        } else {
            my $prefetchedRelationshipName = $self->sqlExpression()->relationshipNameForEntityType($entityType);
            next unless $prefetchedRelationshipName;
            my $relationship = $self->{_entityClassDescription}->relationshipWithName($prefetchedRelationshipName);
            unless ($relationship) {
                $relationship = $self->sqlExpression()->dynamicRelationshipWithName($prefetchedRelationshipName);
            }
            next unless $relationship;
            if ($relationship->type() eq "TO_ONE" || $relationship->type() eq "TO_MANY") {
                $primaryEntity->addEntityToRelationship($hash->{$entityType}, $prefetchedRelationshipName);
                if (IF::Array->arrayHasElements(
                        $self->attributesForTraversedRelationship($prefetchedRelationshipName))) {
                    $hash->{$entityType}->setIsPartiallyInflated(1);
                }
            }
        }
    }
    return $primaryEntity;
}

# This needs to be optimised so that it no longer requires the sort, which is a waste of RAM
# and computation, especially for big lists
sub unpackResultsIntoEntitiesInObjectContext {
    my $self = shift;
    my $results = shift;
    my $oc = shift;
    my $unpackedResults = {};

    my $primaryKey = uc($self->{_entityClassDescription}->_primaryKey()->stringValue());
    my $objectContext = $oc || IF::ObjectContext->new();
    # IF::Log::debug("::: will be hashing the entities by $primaryKey");
    my $order = 0;
    my $rootEntityClassName = $self->inflateAsInstancesOfEntityNamed() || $self->{entity};

    if ($self->{_isAggregateEntity}) {
        # TODO  this is braindead right now, implement so it
        # unpacks aggregates correctly
        my $aggregatedByPrimaryKey = {};
        my $aggregatePrimaryKey = $self->{_rootEntityClassDescription}->_primaryKey();
        foreach my $result (@$results) {
            my $entityHash = $self->sqlExpression()->dictionaryOfEntitiesFromRawRow($result);
            my $primaryEntity = $entityHash->{$self->{_entityClassDescription}->{NAME} || "IF::_AggregatedKeyValuePair"};
            my $primaryKeyValue = $aggregatePrimaryKey->valueForEntity($primaryEntity);
            my $existingPrimaryEntityRecord = $aggregatedByPrimaryKey->{$primaryKeyValue};
            unless ($existingPrimaryEntityRecord) {
                $aggregatedByPrimaryKey->{$primaryKeyValue} = [ $primaryEntity ];
            } else {
                push (@{$aggregatedByPrimaryKey->{$primaryKeyValue}}, $primaryEntity);
            }

        }
        foreach my $key (keys %$aggregatedByPrimaryKey) {
            #IF::Log::debug("init...$key..." .$self->{entity});
            my $e = $objectContext->entityFromHash($rootEntityClassName, { wasInflated => 1 });
            $e->initWithEntities($aggregatedByPrimaryKey->{$key});
            $unpackedResults->{$key} = { ENTITY => $e, ORDER => 0 };
        }
    } else {
        my $isFetchingPartialEntity;
        if (scalar @{$self->attributes} < keys %{$self->{_entityClassDescription}->attributes()}) {
            $isFetchingPartialEntity = 1;
        }
        foreach my $result (@$results) {
            my $entityHash = $self->sqlExpression()->dictionaryOfEntitiesFromRawRow($result);
            my $uniqueHash = {};
            foreach my $entityType (keys %$entityHash) {
                my $u = $objectContext->trackedInstanceOfEntity($entityHash->{$entityType})
                        || $entityHash->{$entityType};
                $uniqueHash->{$entityType} = $u;
            }
            my $primaryEntity = $uniqueHash->{$rootEntityClassName};
            if ($isFetchingPartialEntity) {
                $primaryEntity->setIsPartiallyInflated(1);
            }
            my $primaryKeyValue = $primaryEntity->storedValueForRawKey($primaryKey);
            #IF::Log::debug("::: hashing entity with primary key $primaryKeyValue");
            my $existingPrimaryEntityRecord = $unpackedResults->{$primaryKeyValue};
            unless ($existingPrimaryEntityRecord) {
                $unpackedResults->{$primaryKeyValue} = {
                    ENTITY => $primaryEntity,
                    ORDER => $order,
                };
            } else {
                $primaryEntity = $existingPrimaryEntityRecord->{ENTITY};
            }
            $self->resolveEntityHash($uniqueHash, $primaryEntity);
            $order++;
        }
    }
    my $sortedResults = IF::Array->new();
    foreach my $result (sort {$a->{ORDER} <=> $b->{ORDER}} values %$unpackedResults) {
        push (@$sortedResults, $result->{ENTITY});
    }
    return $sortedResults;
}

sub entityClassDescription {
    my ($self) = @_;
    return $self->{_entityClassDescription};
}

sub addDerivedDataSourceWithName {
    my ($self, $fetchSpecification, $name) = @_;
    # This will register it with the sql expression generator and allow for the name
    # to be used within qualifiers
    $self->sqlExpression()->addDerivedDataSourceWithDefinitionAndName($fetchSpecification, $name);
}

sub addDerivedDataSourceWithNameAndQualifier {
    my ($self, $fetchSpecification, $name, $qualifier) = @_;
    $self->sqlExpression()->addDerivedDataSourceWithDefinitionAndName($fetchSpecification, $name);
    $self->setQualifier(IF::Qualifier->and([
            $self->qualifier(),
            $qualifier,
        ]));
}

1;