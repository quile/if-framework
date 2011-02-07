package IF::Entity::Persistent;

use strict;
use base qw(
    IF::Entity
);
use IF::ObjectContext;

sub initValuesWithArray {
    my ($self, $values) = @_;
    $self->initStoredValuesWithArray($values);
	$self->markAllStoredValuesAsClean();	# flush the dirty bits for those values    
}

sub instanceWithId {
	my ($className, $id) = @_;
	return undef unless $id;
	my $entityName = $className;
	$entityName =~ s/.*:://g;
	return IF::ObjectContext->new()->entityWithPrimaryKey($entityName, $id);
}

sub instanceWithExternalId { 
	my ($className, $externalId) = @_;
	return undef unless $externalId;
	return undef unless IF::Log::assert(
		IF::Utility::externalIdIsValid($externalId),
		"instanceWithExternalId(): externalId='$externalId' .. is valid for $className",
	); 
	return $className->instanceWithId(IF::Utility::idFromExternalId($externalId));
}

sub instanceWithName {
	my ($className, $name) = @_;
	return undef unless $name;
	return unless IF::Log::assert($className->can('name'),"$className implements name() property");
	my $entityName = $className;
	$entityName =~ s/.*:://g;
	return IF::ObjectContext->new()->entityMatchingQualifier($entityName, IF::Qualifier->key('name = %@',$name));
}

sub is {  # This is *the* equality test for Entities !
	my $self = shift;
	my $other = shift;
	return 0 unless $other;
	
	my $primaryKey = $self->entityClassDescription()->_primaryKey();
	unless ($self->valueForKey($primaryKey)) {
		return 0;
	}
	# TODO: This assumes a numeric primary key !
	return ($self->valueForKey($primaryKey) == $other->valueForKey($primaryKey));
}

sub relationshipNamed {
	my $self = shift;
	my $relationshipName = shift;
	return undef unless $self->entityClassDescription();
	return $self->entityClassDescription()->relationshipWithName($relationshipName);
}

sub fetchSpecificationForFlattenedToManyRelationshipNamed {
	my $self = shift;
	my $relationshipName = shift;
	my $relationship = $self->relationshipNamed($relationshipName);
	unless ($self->storedValueForRawKey($relationship->{SOURCE_ATTRIBUTE})) {
		#IF::Log::warning("Attempt to create fetch specification for relationship named \"$relationshipName\" on $self failed: source attribute ".$relationship->{SOURCE_ATTRIBUTE}." is null");
		return undef;
	}

	my $targetEntity = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($relationship->{TARGET_ENTITY});
	my $qualifiers = [];

	if ($relationship->{QUALIFIER}) {
		push (@$qualifiers, $relationship->{QUALIFIER});
	}

	my $fetchSpecification = IF::FetchSpecification->new($relationship->{TARGET_ENTITY});
	$fetchSpecification->setFetchLimit();

	my $sqlExpression = $fetchSpecification->sqlExpression();
	# this is bogus... it shouldn't be here... all of this relationship
	# traversal stuff needs to be encapsulated properly.
	my $targetTable = $targetEntity->{TABLE};
	unless ($targetTable) {
		# must be aggregate?
		$targetTable = $targetEntity->{AGGREGATE_TABLE};
	}
	$sqlExpression->addTable($targetTable) if $targetTable;
	$sqlExpression->addTable($relationship->{JOIN_TABLE});
	$sqlExpression->addTableToFetch($relationship->{JOIN_TABLE});
	
	if ($relationship->{RELATIONSHIP_HINTS}) {
		# force it to fetch the id of the join table record, which
		# should suffice for uniquing these rows if this relationship
		# is altered/saved again:
		$sqlExpression->addColumnForTable("ID", $relationship->{JOIN_TABLE});
		foreach my $hint (@{$relationship->{RELATIONSHIP_HINTS}}) {
			$sqlExpression->addColumnForTable($hint, $relationship->{JOIN_TABLE});
		}
	}
	if ($relationship->{DEFAULT_SORT_ORDERINGS}) {
		my $sortOrderings = [];
		foreach my $ordering (@{$relationship->{DEFAULT_SORT_ORDERINGS}}) {
			push (@$sortOrderings, $ordering);
		}
		$fetchSpecification->setSortOrderings($sortOrderings);
	}

	my $sourceAttributeValue = $self->storedValueForRawKey($relationship->{SOURCE_ATTRIBUTE});
	my $sourceAttribute = $self->entityClassDescription()->attributeForColumnNamed($relationship->{SOURCE_ATTRIBUTE});
	if ($sourceAttribute && $sourceAttribute->{TYPE} =~ /CHAR/io) {
		$sourceAttributeValue = IF::DB::quote($sourceAttributeValue);
	}
	push (@$qualifiers, IF::Qualifier->new("SQL", 
			   $sqlExpression->aliasForTable($targetTable).".".$relationship->{TARGET_ATTRIBUTE}."=".
			   $sqlExpression->aliasForTable($relationship->{JOIN_TABLE}).".".$relationship->{JOIN_SOURCE_ATTRIBUTE}));
	push (@$qualifiers, IF::Qualifier->new("SQL",
			   $sqlExpression->aliasForTable($relationship->{JOIN_TABLE}).".".$relationship->{JOIN_TARGET_ATTRIBUTE}."=".	
			   $sourceAttributeValue));
	
	if ($relationship->{JOIN_QUALIFIERS}) {
		foreach my $joinQualifierAttribute (keys %{$relationship->{JOIN_QUALIFIERS}}) {
			my $joinQualifierValue = $relationship->{JOIN_QUALIFIERS}->{$joinQualifierAttribute};
			unless ($joinQualifierValue =~ /^\d+$/) {
				$joinQualifierValue = IF::DB::quote($joinQualifierValue);
			}
			push (@$qualifiers, IF::Qualifier->new("SQL",
				$sqlExpression->aliasForTable($relationship->{JOIN_TABLE}).".".$joinQualifierAttribute."=".	
												   $joinQualifierValue));
		}
	}
	
	push (@$qualifiers, @{$self->additionalQualifiersForRelationshipNamed($relationshipName)});
	$fetchSpecification->setQualifier(IF::Qualifier->and($qualifiers));
	return $fetchSpecification;
}

# These older methods have been deprecated in favour of
# newer ones that actually do it correctly; these methods
# had the nasty side-effect of committing un-committed
# objects.
sub _deprecated_addObjectToBothSidesOfRelationshipWithKeyAndHintsAndCommitIfNeeded {
	my $self = shift;
	my $object = shift;
	my $relationshipName = shift;
	my $hints = shift;
	my $relationship = $self->relationshipNamed($relationshipName);
	unless ($relationship) {
		IF::Log::error("No such relationship: $relationshipName");
		return;
	}

	my $objectPrimaryKey = $object->entityClassDescription()->_primaryKey();
	my $primaryKey = $self->entityClassDescription()->_primaryKey();
	# make sure we have something to associate:
	unless ($object->valueForKey($objectPrimaryKey)) {
		$object->save();
	}
	unless ($self->valueForKey($primaryKey)) {
		$self->save();
	}
	
	if ($relationship->{TYPE} eq "FLATTENED_TO_MANY") {
		# build a join record for the join table
		my $record = {
			$relationship->{JOIN_TARGET_ATTRIBUTE} => $self->valueForKey($relationship->{SOURCE_ATTRIBUTE}),
			$relationship->{JOIN_SOURCE_ATTRIBUTE} => $object->valueForKey($relationship->{TARGET_ATTRIBUTE}),
			%$hints,
		};
		IF::DB::updateRecordInDatabase(undef, $record, $relationship->{JOIN_TABLE});
	} else {	
		my $targetAttribute = $relationship->{TARGET_ATTRIBUTE};
		my $sourceAttribute = $relationship->{SOURCE_ATTRIBUTE};
		#IF::Log::debug("Source is $sourceAttribute, target is $targetAttribute");
		if (uc($sourceAttribute) eq uc($primaryKey)) {
			#IF::Log::debug("Setting ".$targetAttribute." to ".$self->valueForKey($primaryKey));
			$object->setValueForKey($self->valueForKey($primaryKey), $targetAttribute);
			$object->_clearCachedEntitiesForRelationshipNamed($relationshipName);
			$object->save();
		} else {
			#IF::Log::debug("Setting self ".$sourceAttribute." to ".$object->valueForKey($objectPrimaryKey));
			$self->setValueForKey($object->valueForKey($objectPrimaryKey), $sourceAttribute);
			#IF::Log::debug("Self $sourceAttribute is now ".$self->valueForKey($sourceAttribute));
			$self->_clearCachedEntitiesForRelationshipNamed($relationshipName);
			$self->save();
		}
	}
}

sub _deprecated_addObjectToBothSidesOfRelationshipWithKeyAndCommitIfNeeded {
	my $self = shift;
	my $object = shift;
	my $relationshipName = shift;
	return $self->_deprecated_addObjectToBothSidesOfRelationshipWithKeyAndHintsAndCommitIfNeeded($object, $relationshipName, {});
}

# These are the newer versions of the methods:
sub addObjectToBothSidesOfRelationshipWithKey {
	my ($self, $object, $relationshipName) = @_;
	
	# I >think< this should blank out any previous relationship hints
	# if it has any:
	$object->_deprecated_setRelationshipHints() if $object;
	$self->addObjectToBothSidesOfRelationshipWithKeyAndHints($object, $relationshipName, {});
}

sub addObjectToBothSidesOfRelationshipWithKeyAndHints {
	my ($self, $object, $relationshipName, $hints) = @_;

	unless ($object && UNIVERSAL::isa($object, 'IF::Entity::Persistent')) {
		IF::Log::error("Invalid object passed to addObjectToBothSidesOfRelationshipWithKey: ". $object);
		return;
	}

	my $relationship = $self->relationshipNamed($relationshipName);
	return unless (IF::Log::assert($relationship, "Relationship $relationshipName exists"));

	if ($relationship->{TYPE} eq "TO_ONE") {
		$self->setValueOfToOneRelationshipNamed($object, $relationshipName);
		return;
	}
	
	# TODO un-deprecate this!
	$object->_deprecated_setRelationshipHints($hints);
	$self->_addCachedEntitiesToRelationshipNamed([$object], $relationshipName);
	
	# if the relationship requires a join table entry, stash the
	# hints as part of a to-be-created join table entry, and
	# we're done for now
	if ($relationship->{TYPE} eq "FLATTENED_TO_MANY") {
		$object->__setJoinRecordForEntityThroughFlattenedToManyRelationshipNamed($hints, $self, $relationshipName);
		return;
	}

	# if neither object has been committed, we're done for now
	return if ($self->hasNeverBeenCommitted() && $object->hasNeverBeenCommitted());
	
	# otherwise, let's figure out if we can set some IDs
	my $objectPrimaryKey = $object->entityClassDescription()->_primaryKey();
	my $primaryKey = $self->entityClassDescription()->_primaryKey();
	my $targetAttribute = $relationship->{TARGET_ATTRIBUTE};
	my $sourceAttribute = $relationship->{SOURCE_ATTRIBUTE};
		
	# this object has been committed
	unless ($self->hasNeverBeenCommitted()) {
		# TODO look up the primary key by *attribute* not column

		if (uc($primaryKey) eq uc($sourceAttribute)) {
			# This means this object is committed already *AND*
			# the other object is expecting the id of this one to
			# complete the relationship
			$object->setValueForKey($self->valueForKey($sourceAttribute), $targetAttribute);
		}
	}
	
	# related object has been committed
	unless ($object->hasNeverBeenCommitted()) {
		# TODO look up the primary key by *attribute* not column
		if (uc($primaryKey) ne uc($sourceAttribute)) {
			$self->setValueForKey($object->valueForKey($targetAttribute), $sourceAttribute);
		}
	}
}

sub removeObjectFromBothSidesOfRelationshipWithKey {
	my $self = shift;
	my $object = shift;
	my $relationshipName = shift;
	return $self->removeObjectFromBothSidesOfRelationshipWithKeyAndHints($object, $relationshipName, {});
}

sub removeObjectFromBothSidesOfRelationshipWithKeyAndHints {
	my $self = shift;
	my $object = shift;
	my $relationshipName = shift;
	my $hints = shift;
	my $relationship = $self->relationshipNamed($relationshipName);
	return unless $relationship;

	$self->_removeCachedEntitiesFromRelationshipNamed([$object], $relationshipName);
	my $objectPrimaryKey = $object->entityClassDescription()->_primaryKey();
	my $primaryKey = $self->entityClassDescription()->_primaryKey();

	if ($relationship->{TYPE} eq "FLATTENED_TO_MANY") {
		# make sure we have something to associate:
		return unless ($object->valueForKey($objectPrimaryKey));
		return unless ($self->valueForKey($primaryKey));

		my @qualifiers = ();
		push (@qualifiers, $relationship->{JOIN_TARGET_ATTRIBUTE}." = ".$self->valueForKey($primaryKey));
		push (@qualifiers, $relationship->{JOIN_SOURCE_ATTRIBUTE}." = ".$object->valueForKey($objectPrimaryKey));
		while (my ($key, $value) = each(%$hints)) {
			unless ($value =~ /^\d+$/) {
				$value = IF::DB::quote($value);
			}
			push (@qualifiers, $key." = ".$value);
		}
		if ($relationship->{JOIN_QUALIFIERS}) {
			while (my ($key, $value) = each(%{$relationship->{JOIN_QUALIFIERS}})) {
				unless ($value =~ /^\d+$/) {
					$value = IF::DB::quote($value);
				}
				push (@qualifiers, $key." = ".$value);
			}
		}
		my $sql = "DELETE FROM ".$relationship->{JOIN_TABLE}." WHERE ".join(" AND ", @qualifiers);
		IF::DB::executeArbitrarySQL($sql);
		eval {
		    my $e = IF::DB::dbConnection()->errstr;
		    IF::Log::error($e) if $e;
		};
		if ($object->__joinRecordForEntityThroughFlattenedToManyRelationshipNamed($object, $relationshipName)) {
			$object->__setJoinRecordForEntityThroughFlattenedToManyRelationshipNamed(undef, $object, $relationshipName);
			IF::Log::debug("Blanked out join record from $self to $object");
		}
	}
}

sub removeAllObjectsFromBothSidesOfRelationshipWithKey {
	my $self = shift;
	my $relationshipName = shift;
	my $relationship = $self->relationshipNamed($relationshipName);
	return unless $relationship;
	my $qualifiers = [];
	my $primaryKey = $self->entityClassDescription()->{PRIMARY_KEY}; # ouch!
		push (@$qualifiers, $relationship->{JOIN_TARGET_ATTRIBUTE}." = ".$self->valueForKey($primaryKey));
	if ($relationship->{JOIN_QUALIFIERS}) {
		while (my ($key, $value) = each(%{$relationship->{JOIN_QUALIFIERS}})) {
			unless ($value =~ /^\d+$/) {
				$value = IF::DB::quote($value);
			}
			push (@$qualifiers, $key." = ".$value);
		}
	}
	my $sql = "DELETE FROM ".$relationship->{JOIN_TABLE}." WHERE ".join(" AND ", @$qualifiers);
	IF::DB::executeArbitrarySQL($sql);
	$self->_clearCachedEntitiesForRelationshipNamed($relationshipName);
}

sub targetEntityClassForRelationshipNamed {
	my $self = shift;
	my $relationshipName = shift;
	my $relationship = $self->relationshipNamed($relationshipName);
	return $self->{_namespace}."::".$relationship->{TARGET_ENTITY};
}

sub _table {
	my $self = shift;
	return $self->entityClassDescription()->_table();
}

sub _entityClassName {
	my $self = shift;
	return $self->{_entityClassName};
}

sub countOfEntitiesForRelationshipNamed {
	my $self = shift;
	my $relationshipName = shift;
	my $relationship = $self->relationshipNamed($relationshipName);
	unless ($relationship) {
		IF::Log::warning("Can't find $relationshipName\n");
		return undef;
	}
	my $objectContext = IF::ObjectContext->new();
	my $fetchSpecification;
	if ($relationship->{TYPE} ne "FLATTENED_TO_MANY") {
		$fetchSpecification = $self->fetchSpecificationForToOneOrToManyRelationshipNamed($relationshipName);
	} else {
		$fetchSpecification = $self->fetchSpecificationForFlattenedToManyRelationshipNamed($relationshipName);
	}
	return 0 unless $fetchSpecification;
	return $objectContext->countOfEntitiesMatchingFetchSpecification($fetchSpecification);
}

sub entitiesForRelationshipNamed {
	my $self = shift;
	my $relationshipName = shift;
	my $relationship = $self->relationshipNamed($relationshipName);
	unless ($relationship) {
		IF::Log::warning("Can't find relationship named $relationshipName on entity class ".$self->entityClassDescription()->name()."\n");
		return undef;
	}
	my $objectContext = IF::ObjectContext->new();
	my $entities = [];	
	if ($relationship->{TYPE} ne "FLATTENED_TO_MANY") {
		# check for something we can short-cut
		if ($relationship->{TYPE} eq "TO_ONE") {
			my $targetEntityDescription = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($relationship->{TARGET_ENTITY});
			unless ($targetEntityDescription) {
			    die "Attempted to traverse relationship $relationshipName to non-existent entity $relationship->{TARGET_ENTITY}";
			}
			if (uc($relationship->{TARGET_ATTRIBUTE}) eq uc($targetEntityDescription->_primaryKey())) {
				#IF::Log::stack(4);
				#IF::Log::debug("TO_ONE relationship found with primary key as target, fetching with short-cut");
				return [$objectContext->entityWithPrimaryKey($relationship->{TARGET_ENTITY}, 
															$self->storedValueForRawKey(uc($relationship->{SOURCE_ATTRIBUTE})))];
			}
		}
			
		my $fsObject = $self->fetchSpecificationForToOneOrToManyRelationshipNamed($relationshipName);
		$entities = $objectContext->entitiesMatchingFetchSpecification($fsObject);
		return $entities;
	} else {
		my $fs = $self->fetchSpecificationForFlattenedToManyRelationshipNamed($relationshipName);
		return [] unless $fs;
		my $entities = $objectContext->entitiesMatchingFetchSpecification($fs);
		
		if ($relationship->{RELATIONSHIP_HINTS}) {
			# if a hint record showed up here, add a join record if appropriate
			foreach my $entity (@$entities) {
				my $hints = $entity->_deprecated_relationshipHints();
			
				if ($hints->{ID}) {
					IF::Log::debug("Fetched an entity with hints stored in db row with id ".$hints->{ID});
					$self->__setJoinRecordForEntityThroughFlattenedToManyRelationshipNamed(
						$hints, $entity, $relationshipName
					);
				}
			}
		}
		return $entities;
	}
}

sub fetchSpecificationForToOneOrToManyRelationshipNamed {
	my $self = shift;
	my $relationshipName = shift;
	my $relationship = $self->relationshipNamed($relationshipName);
	unless ($self->storedValueForRawKey($relationship->{SOURCE_ATTRIBUTE})) {
		#IF::Log::warning("Attempt to create fetch specification for relationship named \"$relationshipName\" on $self failed: source attribute ".$relationship->{SOURCE_ATTRIBUTE}." is null");
		return undef;
	}

	my $targetEntity = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($relationship->{TARGET_ENTITY});
	my $qualifiers = [];
	push (@$qualifiers, IF::Qualifier->key("$relationship->{TARGET_ATTRIBUTE} = %@", 
					$self->storedValueForRawKey($relationship->{SOURCE_ATTRIBUTE})));

	if ($relationship->{QUALIFIER}) {
		push (@$qualifiers, $relationship->{QUALIFIER});
	}

	push (@$qualifiers, @{$self->additionalQualifiersForRelationshipNamed($relationshipName)});
	my $fs = IF::FetchSpecification->new($relationship->{TARGET_ENTITY}, 
				IF::Qualifier->and($qualifiers),
				$relationship->{DEFAULT_SORT_ORDERINGS});
	$fs->setFetchLimit();
	return $fs;
}

sub additionalQualifiersForRelationshipNamed {
	my ($self, $relationshipName) = @_;
	return [];
}

sub entityForRelationshipNamed {
	my $self = shift;
	# TODO: This is shorthand, but I really should write a special
	# case for this.  Instead we need to rely on the return
	# values from entitiesForRelationshipNamed().
	my $result =  $self->entitiesForRelationshipNamed(@_);
	if (IF::Array::isArray($result)) {
		return $result->[0];
	}
	return $result;
}

sub entityWithIdInEntityArray {
	my $self = shift;
	my $id = shift;
	my $entityArray = shift;

	foreach my $entity (@$entityArray) {
		return $entity if ($entity->id() eq $id);
	}
	return undef;
}

sub faultEntityForRelationshipNamed {
	my $self = shift;
	my $relationshipName = shift;
	my $entities = $self->faultEntitiesForRelationshipNamed($relationshipName);
	IF::Log::assert(IF::Array::isArray($entities), "Relationship returned an array");
	return $entities->[0];

}

sub faultEntitiesForRelationshipNamed {
	my $self = shift;
	my $relationshipName = shift;
	unless ($self->_hasCachedEntitiesForRelationshipNamed($relationshipName)) {
		my $entities = $self->entitiesForRelationshipNamed($relationshipName);		
		$self->_setCachedEntitiesForRelationshipNamed($entities, $relationshipName);
	}
	return $self->_cachedEntitiesForRelationshipNamed($relationshipName);
}

sub invalidateEntitiesForRelationshipNamed {
	my $self = shift;
	my $relationshipName = shift;
	IF::Log::debug("Invalidating entities for faulted relationship $relationshipName");
	$self->_clearCachedEntitiesForRelationshipNamed($relationshipName);
}

# removes all entities for a given relationship
# ok, smartypants, don't try to optimise this by deleting rows
# directly from the tables; this is a generic deletion method
# that removes objects by calling their "deleteSelf" method.
# That's the only correct way to remove an object UNLESS you
# know something special about it.
sub deleteAllEntitiesForRelationshipNamed {
	my $self = shift;
	my $relationshipName = shift;

	my $entityArray = $self->entitiesForRelationshipNamed($relationshipName);
	return unless $entityArray;
	foreach my $entity (@$entityArray) {
		$entity->_deleteSelf();
	}
	$self->_clearCachedEntitiesForRelationshipNamed($relationshipName);
}

sub removeAllEntitiesForRelationshipDirectlyFromDatabase {
	my $self = shift;
	my $relationshipName = shift;
	my $relationship = $self->relationshipNamed($relationshipName);
	return unless $relationship;
	my $sourceAttribute = $self->storedValueForKey($relationship->{SOURCE_ATTRIBUTE});
	my $tecd = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($relationship->{TARGET_ENTITY});
	return unless $tecd;
	my $table = $tecd->_table();
	# The T0 is there to assist the SQL gen engine in the qualifier generation
	# if qualifiers are needed:
	my $query = "DELETE FROM $table WHERE ".$relationship->{TARGET_ATTRIBUTE}."=".IF::DB::quote($sourceAttribute); # TODO this will only ever work in MySQL
	if ($relationship->{QUALIFIER}) {
		my $q = $relationship->{QUALIFIER};
		$q->setEntity($self->entityClassDescription()->name());
		my $se = IF::SQLExpression->new();
		$se->addEntityClassDescription($self->entityClassDescription());
		my $goo = $q->sqlWithBindValuesForExpressionAndModel($se, IF::Model->defaultModel());

		# this hack is gnarly: we generate the SQL for the qualifier, then strip off the goo
		# pertaining to the table alias, since table aliases don't work in DELETE statements
		my $hack = $goo->{SQL};
		$hack =~ s/T[0-9]+\.//gio;
		$query = $query." AND ".$hack;
		
		IF::DB::rawRowsForSQLWithBindings({ SQL => $query, BIND_VALUES => $goo->{BIND_VALUES}});
		return;
	}
	IF::DB::executeArbitrarySQL($query);
}

sub save {
	my ($self, $when) = @_;
	$when = $when || "NOW";
	#IF::Log::debug("request to save $self $when");
	# These lines ensure that an object that is already in the "to-be-saved"
	# stack doesn't try to save itself again (which will catch circular
	# saves where A tries to save B, which tries to save A).
	#
	# TODO: this will only work when you have circular references that are
	# in-memory.  It won't work if the objects aren't "uniqued" correctly,
	# which could still happen easily.
	return if $self->__isMarkedForSave();
	$self->__setIsMarkedForSave(1);
	
	unless ($self->isValidForCommit()) {
		$self->__setIsMarkedForSave(0);
		return;
	}
	my $entityClassDescription = $self->entityClassDescription();
	
	# First, check all the cached related entities and see
	# if any of them need to be committed
	my $relationships = $entityClassDescription->relationships();
	my $primaryKey = $entityClassDescription->_primaryKey();
	#$DB::single = 1;
	foreach my $relationshipName (keys %$relationships) {
		my $relationship = $relationships->{$relationshipName};
		next if ($relationship->{IS_READ_ONLY});
		next unless ($relationship->{TYPE} eq "TO_ONE" &&
					 uc($relationship->{SOURCE_ATTRIBUTE}) ne uc($primaryKey));

		foreach my $entity (@{$self->_cachedEntitiesForRelationshipNamed($relationshipName)}) {
			unless ($entity) {
				IF::Log::error("Undefined entity in ".$relationshipName." on ".$entityClassDescription->name());
				next;
			}
			$entity->save();
			$self->setValueForKey($entity->valueForKey($relationship->{TARGET_ATTRIBUTE}), $relationship->{SOURCE_ATTRIBUTE});
		}
	}
					 
	# Allow the object a chance to react before being committed to the DB
	$self->prepareForCommit();
	$self->invokeNotificationFromObjectWithArguments("willBeSaved", $self);

	# we really need to have all field names
	# stored in the model so we can pull those and
	# ONLY those from the entity

	my $dataRecord = { $self->entityClassDescription()->_primaryKey() => 
								$self->valueForKey($self->entityClassDescription()->_primaryKey()) };
	
	foreach my $k (@{$entityClassDescription->allAttributeNames()}) {
		next unless $self->storedValueForKeyHasChanged($k);
		my $columnName = $entityClassDescription->columnNameForAttributeName($k);
		$dataRecord->{$columnName} = $self->storedValueForKey($k);
	}
	
	unless (scalar keys %$dataRecord == 1) {
	    $dataRecord->{_ecd} = $self->entityClassDescription();
		if ($when eq "LATER" && !$self->hasUnsavedRelatedEntities()) {
			IF::DB::updateRecordInDatabase(undef, $dataRecord, $self->_table(), "DELAYED");
		} else {
			IF::DB::updateRecordInDatabase(undef, $dataRecord, $self->_table());
		}
		$self->{_currentStoredRepresentation} = undef;
		$self->didCommit();
	    $self->invokeNotificationFromObjectWithArguments("wasSaved", $self);		
	
		# check for a new ID
		$self->setId($dataRecord->{ID}) unless ($self->id());
		$self->markAllStoredValuesAsClean();
	} else {
		IF::Log::debug($self->entityClassName().": save ignored, no attributes set.");
	}
	
	# now that we've committed the object, we can
	# fix relationships
	foreach my $relationshipName (keys %$relationships) {
		my $relationship = $relationships->{$relationshipName};
		#IF::Log::debug("Checking for entities to save across $relationshipName");		
		next if ($relationship->{IS_READ_ONLY});
		next if ($relationship->{TYPE} eq "TO_ONE" &&
					 uc($relationship->{SOURCE_ATTRIBUTE}) ne uc($primaryKey));
		#IF::Log::debug("Made it past the short circuits");
		foreach my $deletedEntity (@{$self->_deletedEntitiesForRelationshipNamed($relationshipName)}) {
			$deletedEntity->_deleteSelf(); # WRONG
		}

	    foreach my $entity (@{$self->_removedEntitiesForRelationshipNamed($relationshipName)}) {
		    IF::Log::debug("Should remove $entity");
		    if ($relationship->{TYPE} eq "TO_MANY") {
		        # if it's a to-many, we need to blank out the FK
            	if ($relationship->{TYPE} eq "TO_ONE" || $relationship->{TYPE} eq "TO_MANY") {
    				my $targetAttribute = $relationship->{TARGET_ATTRIBUTE};
    				my $sourceAttribute = $relationship->{SOURCE_ATTRIBUTE};

                    if (uc($relationship->{SOURCE_ATTRIBUTE}) eq uc($primaryKey)) {
    				    $entity->setValueForKey(undef, $targetAttribute);
    				    $entity->save(); # this should blank it out; you need to delete it yourself
    				} # TODO blank out to-one relationship here
    			} # elsif ($relationship->{TYPE} eq "FLATTENED_TO_MANY") {		        
		    }
		}		
		
		foreach my $entity (@{$self->_cachedEntitiesForRelationshipNamed($relationshipName)}) {
			#IF::Log::debug($entity);
			if ($relationship->{TYPE} eq "TO_ONE" || $relationship->{TYPE} eq "TO_MANY") {
				my $targetAttribute = $relationship->{TARGET_ATTRIBUTE};
				my $sourceAttribute = $relationship->{SOURCE_ATTRIBUTE};
				
				#IF::Log::debug("Setting ".$targetAttribute." to ".$self->valueForKey($sourceAttribute));
				$entity->setValueForKey($self->valueForKey($sourceAttribute), $targetAttribute);
				$entity->save($when);
			} elsif ($relationship->{TYPE} eq "FLATTENED_TO_MANY") {
				
				#IF::Log::debug("Checking if we need to commit entity $entity");
				# TODO fix this handling:  right now it automatically tries to commit
				# records here, even if they don't need to be committed
				if ($entity->hasNeverBeenCommitted()) {
					$entity->save();
				}
				# build a join record for the join table
				# this enhancement checks for the use of a primary key
				# and resolves it through the primary key object itself.
				# This is half-assed and we need a better way to do it
				# everywhere.
				my $joinTarget;
				my $joinSource;
				
				if ($relationship->{SOURCE_ATTRIBUTE} eq $primaryKey) {
					$joinTarget = $primaryKey->valueForEntity($self);
				} else {
					$joinTarget = $self->valueForKey($relationship->{SOURCE_ATTRIBUTE});
				}
				
				my $tecd = $entity->entityClassDescription();
				my $tpk  = $tecd->_primaryKey();
				
				if ($relationship->{TARGET_ATTRIBUTE} eq $tpk) {
					$joinSource = $tpk->valueForEntity($entity);
				} else {
					$joinSource = $entity->valueForKey($relationship->{TARGET_ATTRIBUTE});
				}
				
				# the join record should be updated if it already exists,
				# and inserted if it doesn't
				my $rh = $entity->_deprecated_relationshipHints();
				#IF::Log::dump($entity->{__joinRecordForRelationship});

				my $jr = $entity->__joinRecordForEntityThroughFlattenedToManyRelationshipNamed($self, $relationshipName);
				my $rhs = {
					%$jr,
					%$rh
				};
				
				#IF::Log::debug("Here are the hints:");
				#IF::Log::dump($rhs);
				
				my $record = {
					$relationship->{JOIN_TARGET_ATTRIBUTE} => $joinTarget,
					$relationship->{JOIN_SOURCE_ATTRIBUTE} => $joinSource,
					%$rhs,
				};
				IF::DB::updateRecordInDatabase(undef, $record, $relationship->{JOIN_TABLE});
				
				$entity->_deprecated_setRelationshipHints($record);
				
				if (scalar keys %{$rhs}) {
					# blank out the hints and push the join record into holding for later use if necessary.
					$self->_deprecated_setRelationshipHints();
					$entity->__setJoinRecordForEntityThroughFlattenedToManyRelationshipNamed($record, $self, $relationshipName);
				}
				# if this has a reciprocal relationship, we need to set it there too, in case
				# the other object gets saved separately.
				# WARNING: memory leak danger... these two objects will now
				# contain references to each other, and will not get garbage
				# collected when they go out of scope.
				if (my $rrn = $relationship->{RECIPROCAL_RELATIONSHIP_NAME}) {
					my $sc = $self->shallowCopy();
					$entity->_addCachedEntitiesToRelationshipNamed([$sc], $rrn);
					$sc->__setJoinRecordForEntityThroughFlattenedToManyRelationshipNamed($record, $entity, $relationship->{RECIPROCAL_RELATIONSHIP_NAME});
				}
			}
		}

		delete $self->{_relatedEntities}->{$relationshipName}->{removedEntities};
		delete $self->{_relatedEntities}->{$relationshipName}->{deletedEntities};	
	}
	$self->__setIsMarkedForSave(0);
}

# This is a very very internal piece of API
# used ONLY during the save() process
sub __isMarkedForSave {
	my $self = shift;
	return $self->{__isMarkedForSave};
}

sub __setIsMarkedForSave {
	my ($self, $value) = @_;
	$self->{__isMarkedForSave} = $value;
}

# This private API is so that an in-memory entity knows
# that it has been related to another entity while living
# in memory.  This >IS NOT< for determining database
# relationships, just whether or not the known relationship
# exists and has been established by being saved to the DB.
# Why?  Because if entity A is "added" to a relationship on
# entity B, and entity B is saved, entity A is saved too
# and a join record is created.  If entity B is saved again,
# entity A needs to know that it doesn't need to create
# a join record again.
# Furthermore, if entity A is related to both B and C, and
# entities B and C are BOTH related to entity D, then 
# entity D needs to know it's related to BOTH entities B
# and C even though they're all saved in the same call
# to save().

sub __joinRecordForEntityThroughFlattenedToManyRelationshipNamed {
	my ($self, $entity, $relationshipName) = @_;
	my $k = ref($entity).":".$entity->id();
	# if there's none for this entity, return one for an uncommitted entity
	# or an empty hash.
	return $self->{__joinRecordForRelationship}->{$relationshipName}->{$k}
		|| $self->{__joinRecordForRelationship}->{$relationshipName}->{ref($entity).":"}
		|| {};
}

sub __setJoinRecordForEntityThroughFlattenedToManyRelationshipNamed {
	my ($self, $joinRecord, $entity, $relationshipName) = @_;
	my $k = ref($entity).":".$entity->id();
	$self->{__joinRecordForRelationship}->{$relationshipName}->{$k} = $joinRecord;
}

sub hasUnsavedRelatedEntities {
	my ($self) = @_;
	my $ecd = $self->entityClassDescription();
	return unless $	ecd;
	
	my $relationships = $ecd->relationships();
	my $primaryKey = $ecd->_primaryKey();

	foreach my $relationshipName (keys %$relationships) {
		my $relationship = $relationships->{$relationshipName};
		next if ($relationship->{TYPE} eq "TO_ONE" &&
					 uc($relationship->{SOURCE_ATTRIBUTE}) ne uc($primaryKey));
			
		foreach my $entity (@{$self->_cachedEntitiesForRelationshipNamed($relationshipName)}) {
			if ($relationship->{TYPE} eq "TO_ONE" || $relationship->{TYPE} eq "TO_MANY") {
				return 1 if ($entity->hasChanged() || $entity->hasNeverBeenCommitted());
			} elsif ($relationship->{TYPE} eq "FLATTENED_TO_MANY") {
				return 1;
			}
		}
	}
	return 0;
}


# this should get overridden in a subclass
sub isValidForCommit {
	my $self = shift;
	return 1;
}

sub canBeDeleted {
	my ($self, $visitedObjects) = @_;
	
	$visitedObjects = {} unless $visitedObjects;
	$visitedObjects->{$self} = 1; # mark it as visited, to avoid infinite recursion
	foreach my $relationshipName (keys %{$self->entityClassDescription()->relationships()}) {
		my $relationship = $self->relationshipNamed($relationshipName);
		next unless $relationship && $relationship->{DELETION_RULE};
		if ($relationship->{DELETION_RULE} eq "DENY") {
			my $entities = $self->faultEntitiesForRelationshipNamed($relationshipName);
			if (scalar @$entities) {
				IF::Log::warning("Can't delete object $self because relationship $relationshipName contains entities");
				return 0;
			}
		} elsif ($relationship->{DELETION_RULE} eq "CASCADE") {
			my $entities = $self->faultEntitiesForRelationshipNamed($relationshipName);
			foreach my $entity (@$entities) {
				next if $visitedObjects->{$entity};
				next if $entity->canBeDeleted($visitedObjects);
				IF::Log::warning("Deletion of entity $self is not possible because related entity $entity cannot be deleted");
				return 0;
			}
		}
	}
	return 1;
}

sub willBeDeleted {
	my $self = shift;
	$self->invokeDelegateMethodNamed("willBeDeleted", @_);
}

# dangerous?  dunno
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
		next unless $relationship && $relationship->{DELETION_RULE};
		next if $relationship->{IS_READ_ONLY};
		IF::Log::debug(">>> deleting relationship $relationshipName");
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
	
	IF::Log::debug("==> _deleteSelf() called for ".ref($self).", destroying record with ID ".$self->valueForKey("ID")."\n");
	$self->willBeDeleted();
	IF::DB::deleteRecordInDatabase(undef, $self, $self->_table());
	$self->{_wasDeletedFromDataStore} = 1;
}

sub entitiesForDeletionByRules {
	my $self = shift;
	my $entitiesForDeletion = [];
	foreach my $relationshipName (keys %{$self->entityClassDescription()->relationships()}) {
		my $relationship = $self->relationshipNamed($relationshipName);
		next unless $relationship && $relationship->{DELETION_RULE};
		next unless ($relationship->{DELETION_RULE} eq "CASCADE");
		
		my $entities = $self->faultEntitiesForRelationshipNamed($relationshipName);
		if (@$entities) {
			push (@$entitiesForDeletion, @$entities);
		}
	}
	return $entitiesForDeletion;
}


sub creationDate {
	my $self = shift;	
	my $d = IF::Date::Unix->new($self->storedValueForKey("creationDate"));
	$d->_setOriginFormat($self->entityClassDescription()->attributeWithName("creationDate")->{TYPE});
	return $d;
}

sub setCreationDate {
	my ($self, $value) = @_;
	if (ref($value) && UNIVERSAL::isa($value, "IF::Date::Unix")) {
		$value = $value->utc();
	}
	$self->setStoredValueForKey($value, "creationDate");
}

sub modificationDate {
	my $self = shift;
	my $d = IF::Date::Unix->new($self->storedValueForKey("modificationDate"));
	$d->_setOriginFormat($self->entityClassDescription()->attributeWithName("modificationDate")->{TYPE});
	return $d;
}

sub _deprecated_setRelationshipHints {
	my $self = shift;
	$self->{_RELATIONSHIP_HINTS} = shift;
}

sub _deprecated_relationshipHints {
	my $self = shift;
	unless ($self->{_RELATIONSHIP_HINTS}) {
		$self->{_RELATIONSHIP_HINTS} = {};
	}
	return $self->{_RELATIONSHIP_HINTS};
}

sub _deprecated_relationshipHintForKey {
	my $self = shift;
	my $key = shift;
	return $self->_deprecated_relationshipHints()->{$key};
}

sub _deprecated_setRelationshipHintForKey {
	my ($self, $value, $key) = @_;
	$self->_deprecated_relationshipHints()->{$key} = $value;
}

sub entityClassDescription {
	my $self = shift;
	# don't cache this locally to keep our objects smaller when they're serialised
	return IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($self->entityClassName());
}

sub entityClassName {
	my $self = shift;
	return $self->{_entityClassName};
}

sub changeEntityClassToClassNamed {
	my ($self, $newEntityClassName)	= @_;
	bless $self, $newEntityClassName;
	my $namespace = $newEntityClassName;
	$namespace =~ s/::([A-Za-z0-9]*)$//g;
	$self->{_entityClassName} = $1;
	$self->{_namespace} = $namespace;
	return $self;
}

sub addEntitiesToRelationship {
	my ($self, $entities, $relationshipName) = @_;
	$self->_addCachedEntitiesToRelationshipNamed($entities, $relationshipName);	
}

sub addEntityToRelationship {
	my ($self, $entity, $relationshipName) = @_;
	$self->_addCachedEntitiesToRelationshipNamed([$entity], $relationshipName);
}

sub setValueOfToOneRelationshipNamed {
	my ($self, $entity, $relationshipName) = @_;
	my $relationship = $self->entityClassDescription()->relationshipWithName($relationshipName);
	return unless IF::Log::assert($relationship, "Relationship $relationshipName exists");
	
	my $targetEntityClass = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($relationship->{TARGET_ENTITY});
	my $objectPrimaryKey = $targetEntityClass->_primaryKey();
	my $primaryKey = $self->entityClassDescription()->_primaryKey();
	my $targetAttribute = $relationship->{TARGET_ATTRIBUTE};
	my $sourceAttribute = $relationship->{SOURCE_ATTRIBUTE};
	
	my $deletionRequired = (uc($primaryKey) eq uc($sourceAttribute));
	my $currentEntities = $self->entitiesForRelationshipNamed($relationshipName);
	
	if ($deletionRequired) {
		# move them to the "deleted" array
		my $deletedEntities = $self->_deletedEntitiesForRelationshipNamed($relationshipName);
		push (@$deletedEntities, @$currentEntities);
		$self->_setDeletedEntitiesForRelationshipNamed($deletedEntities, $relationshipName);
	} else {
		# move them to the "removed" array
		my $removedEntities = $self->_removedEntitiesForRelationshipNamed($relationshipName);
		push (@$removedEntities, @$currentEntities);
		$self->_setRemovedEntitiesForRelationshipNamed($removedEntities, $relationshipName);
	}
			
	# clear what's there and add the new one
	#$self->_clearCachedEntitiesForRelationshipNamed($relationshipName);
	$self->_setCachedEntitiesForRelationshipNamed([], $relationshipName);
	if ($entity) {
		$self->_addCachedEntitiesToRelationshipNamed([$entity], $relationshipName);
		
		# if neither object has been committed, we're done for now
		return if ($self->hasNeverBeenCommitted() && $entity->hasNeverBeenCommitted());
		
		# this object has been committed
		unless ($self->hasNeverBeenCommitted()) {
			# TODO look up the primary key by *attribute* not column
			if (uc($primaryKey) eq uc($sourceAttribute)) {
				# This means this object is committed already *AND*
				# the other object is expecting the id of this one to
				# complete the relationship
				$entity->setValueForKey($self->valueForKey($sourceAttribute), $targetAttribute);
			}
		}
		
		# related object has been committed
		unless ($entity->hasNeverBeenCommitted()) {
			# TODO look up the primary key by *attribute* not column
			if (uc($primaryKey) ne uc($sourceAttribute)) {
				$self->setValueForKey($entity->valueForKey($targetAttribute), $sourceAttribute);
			}
		}
	} else {
		unless ($deletionRequired) {
			$self->setValueForKey(undef, $sourceAttribute);
		}
	}
}

#----------------------------------------------
# This stuff needs some HEAVY optimisation
# and really should be abstracted somehow

sub initStoredValuesWithArray {
	my ($self, $storedValueArray) = @_;
	my $storedValues = {@$storedValueArray};
	
	# TODO : This is kinda a hack to get around inflation from
	# an existing entity.  When the entity is passed into the
	# constructor, it gets dereferenced and converted to a hash
	# so the best way to tell if it's an entity is to check for
	# its stored values.
	if ($storedValues->{__storedValues}) {
		# it's an entity already so grab its stored values
		$storedValues = $storedValues->{__storedValues};
		foreach my $key (keys %$storedValues) {
			$self->setStoredValueForRawKey($storedValues->{$key}->{v}, $key);
		}
	} else {
		foreach my $key (keys %$storedValues) {
			$self->setStoredValueForRawKey($storedValues->{$key}, $key);
		}
	}
}

sub storedKeys {
	my $self = shift;
	return [keys %{$self->{__storedValues}}];
}

sub storedValueForKey {
	my ($self, $key) = @_;
	if (my $c = $self->{_columnKeyMap}->{$key}) {
		return $self->storedValueForRawKey($c);
	}
	my $ecd = $self->entityClassDescription();
	unless ($ecd) {
		IF::Log::stack(4);
		return;
	}
	my $columnName = uc($ecd->columnNameForAttributeName($key));
	$self->{_columnKeyMap}->{$key} = $columnName;
	return $self->storedValueForRawKey($columnName);
}

sub storedValueForRawKey {
	my ($self, $key) = @_;
	return $self->{__storedValues}->{$key}->{v};
}

sub setStoredValueForKey {
	my ($self, $value, $key) = @_;
	if (my $c = $self->{_columnKeyMap}->{$key}) {
		$self->setStoredValueForRawKey($value, $c);
		return;
	}
	my $ecd = $self->entityClassDescription();
	unless ($ecd) {
		IF::Log::error("No entity class description found for $self trying to set key $key to value $value");
		IF::Log::stack(4);
		return;
	}
	my $columnName = $ecd->columnNameForAttributeName($key); # TODO why isn't this uc()?
	$self->{_columnKeyMap}->{$key} = uc($columnName);
	$self->setStoredValueForRawKey($value, $columnName);
}

sub setStoredValueForRawKey {
	my ($self, $value, $key) = @_;
	$key = uc($key);
	unless (exists($self->{__storedValues}->{$key}->{v}) && $value eq $self->{__storedValues}->{$key}->{v}) {
		#IF::Log::warning("Old value for $key: ".$self->{__storedValues}->{$key}->{v}." New value: $value");
		if (!exists($self->{__storedValues}->{$key}->{o}) &&
			exists($self->{__storedValues}->{$key}->{v})) {
			$self->{__storedValues}->{$key}->{o} = $self->{__storedValues}->{$key}->{v};
		}
		$self->{__storedValues}->{$key}->{v} = $value;
		$self->{__storedValues}->{$key}->{d} = 1;
	}
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

sub revertToSavedValueForKey {
	my ($self, $key) = @_;
	$self->revertToSavedValueForRawKey($key);
}

sub revertToSavedValueForRawKey {
	my ($self, $key) = @_;
	$key = uc($self->entityClassDescription()->columnNameForAttributeName($key));
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
	my $columnName = uc($self->entityClassDescription()->columnNameForAttributeName($key));
	return 0 unless $self->{__storedValues}->{$columnName}->{d};
	return 1;
}

sub keysForAllAlteredStoredValues {
	my $self = shift;
	my $alteredStoredValues = [];
	foreach my $key (@{$self->storedKeys()}) {
		if ($self->{__storedValues}->{$key}->{d}) {
			push (@$alteredStoredValues, $key);
		}
	}
	return $alteredStoredValues;
}

sub markAllStoredValuesAsClean {
	my $self = shift;
	foreach my $key (keys %{$self->{__storedValues}}) {
		delete $self->{__storedValues}->{$key}->{d};
	}
}

sub markAllStoredValuesAsDirty {
	my $self = shift;
	foreach my $key (@{$self->storedKeys()}) {
		$self->{__storedValues}->{$key}->{d} = 1;
	}
}

sub hasChanged {
	my $self = shift;
	#return $self->{__isDirty};
	foreach my $key (@{$self->storedKeys()}) {
		return 1 if ($self->{__storedValues}->{$key}->{d});
	}
	return 0;
}

sub shallowCopy {
	my $self = shift;
	my $keyValuePairs = {};
	foreach my $key (@{$self->storedKeys()}) {
		$keyValuePairs->{$key} = $self->{__storedValues}->{$key}->{v};
	}
	#my $copy = new(ref $self, %$keyValuePairs);
	my $copy = ref($self)->new(%$keyValuePairs);
	$copy->markAllStoredValuesAsDirty();
	return $copy;
}

# This method bypasses any caching and fetches the current
# stored state of this entity in the DB.  Useful for
# checking for changes, unindexing, etc.
sub currentStoredRepresentation {
	my $self = shift;
	return if $self->hasNeverBeenCommitted();
	return $self->{_currentStoredRepresentation} if $self->{_currentStoredRepresentation};
	my $objectContext = IF::ObjectContext->new();
	my $isUsingCache = $objectContext->shouldUseCache();
	$objectContext->setShouldUseCache(0);
	my $entity = $objectContext->entityWithPrimaryKey($self->{_entityClassName}, $self->id());
	$objectContext->setShouldUseCache($isUsingCache);
	$self->{_currentStoredRepresentation} = $entity;
	return $entity;
}

sub isPartiallyInflated {
	my $self = shift;
	return $self->{_isPartiallyInflated};
}

sub setIsPartiallyInflated {
	my ($self, $value) = @_;
	$self->{_isPartiallyInflated} = $value;
}

#-------- low level in-memory relationship management ------

sub _hasCachedEntitiesForRelationshipNamed {
	my ($self, $relationshipName) = @_;
	return 1 if (exists $self->{_relatedEntities}->{$relationshipName}->{entities} &&
			IF::Array::isArray($self->{_relatedEntities}->{$relationshipName}->{entities}) &&
			scalar @{$self->{_relatedEntities}->{$relationshipName}->{entities}} > 0);
	return 1 if (exists $self->{_relatedEntities}->{$relationshipName}->{removedEntities} &&
			IF::Array::isArray($self->{_relatedEntities}->{$relationshipName}->{removedEntities}) &&
			scalar @{$self->{_relatedEntities}->{$relationshipName}->{removedEntities}} > 0);
	return 0;
}

sub _cachedEntitiesForRelationshipNamed {
	my ($self, $relationshipName) = @_;
	return $self->{_relatedEntities}->{$relationshipName}->{entities} || [];
}

sub _setCachedEntitiesForRelationshipNamed {
	my ($self, $entities, $relationshipName) = @_;
	$self->{_relatedEntities}->{$relationshipName}->{entities} = $entities;
}

sub _clearCachedEntitiesForRelationshipNamed {
	my ($self, $relationshipName) = @_;
	delete $self->{_relatedEntities}->{$relationshipName};
}

sub _addCachedEntitiesToRelationshipNamed {
	my ($self, $entities, $relationshipName) = @_;
	unless ($self->{_relatedEntities}->{$relationshipName}->{entities}) {
		$self->{_relatedEntities}->{$relationshipName}->{entities} = [];
	}
	push (@{$self->{_relatedEntities}->{$relationshipName}->{entities}}, @$entities);
}

sub _removedEntitiesForRelationshipNamed {
	my ($self, $relationshipName) = @_;
	return $self->{_relatedEntities}->{$relationshipName}->{removedEntities} || []; 
}

sub _setRemovedEntitiesForRelationshipNamed {
	my ($self, $entities, $relationshipName) = @_;
	$self->{_relatedEntities}->{$relationshipName}->{removedEntities} = $entities;
}

sub _deletedEntitiesForRelationshipNamed {
	my ($self, $relationshipName) = @_;
	return $self->{_relatedEntities}->{$relationshipName}->{deletedEntities} || [];	
}

sub _setDeletedEntitiesForRelationshipNamed {
	my ($self, $entities, $relationshipName) = @_;
	$self->{_relatedEntities}->{$relationshipName}->{deletedEntities} = $entities;
}

sub _removeCachedEntitiesFromRelationshipNamed {
	my ($self, $entities, $relationshipName) = @_;
	my $filteredEntities = [];
	my $relatedEntities = $self->_cachedEntitiesForRelationshipNamed($relationshipName);
	my $removedEntities = $self->_removedEntitiesForRelationshipNamed($relationshipName);
	foreach my $entity (@$entities) {
		foreach my $relatedEntity (@$relatedEntities) {
			if ($relatedEntity == $entity || $entity->is($relatedEntity)) {
				push (@$removedEntities, $entity);
				next;
			}
			push (@$filteredEntities, $relatedEntity);
		}
		$relatedEntities = $filteredEntities;
		$filteredEntities = [];
	}
	$self->_setRemovedEntitiesForRelationshipNamed($removedEntities, $relationshipName);
	$self->_setCachedEntitiesForRelationshipNamed($relatedEntities, $relationshipName);	
}

#-------- notifications ----------
sub prepareForCommit {
	my $self = shift;
	$self->invokeDelegateMethodNamed("prepareForCommit", @_);
}

sub didCommit {
	my $self = shift;
	$self->invokeDelegateMethodNamed("didCommit", @_);
}

sub hasNeverBeenCommitted {
	my $self = shift;
	return 0 if $self->id();
	return 1;
}

sub wasDeletedFromDataStore {
	my $self = shift;
	return $self->{_wasDeletedFromDataStore};
}

1;