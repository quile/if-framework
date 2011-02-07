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
# Qualifier
# Abstracts SQL qualifiers
# into a tree-based system of
# related qualifiers

package IF::Qualifier;

use strict;
use vars qw($QUALIFIER_TYPES @QUALIFIER_OPERATORS $QUALIFIER_REGEX);
use base qw(
	IF::Interface::SQLGeneration
);
use IF::Log;
use IF::DB;
use IF::Model;
use IF::Relationship::Derived;
use IF::Relationship::Modelled;
use IF::Utility;

$QUALIFIER_TYPES = {
	"AND" => 1,
	"OR"  => 2,
	"KEY" => 3,
	"SQL" => 4,
	"MATCH" => 5,
	};

@QUALIFIER_OPERATORS = (
	"=",
	'>=',
	'<=',
	'<>',
	'>',
	'<',
	'!=',
	'LIKE',
	'REGEXP',
	'IN',
	'NOT IN',
	'IS',
	'IS NOT',
	);

$QUALIFIER_REGEX = "(".join("|", @QUALIFIER_OPERATORS).")";

# Class Methods

sub new {
	my $className = shift;
	my $qualifierType = shift;

	# decide if the type's valid

	return undef unless ($QUALIFIER_TYPES->{$qualifierType});

	my $self = {
		type => $qualifierType,
		_bindValues => [],
		_requiresRepeatedJoin => 0,
	};

	if ($qualifierType eq "KEY") {
		$self->{condition} = shift;
		# this is bogus because there can only be one bindvalue per qualifier
		foreach my $bindValue (@_) {
			push (@{$self->{_bindValues}}, $bindValue);
		}
	} elsif ($qualifierType eq "AND" || $qualifierType eq "OR" || $qualifierType eq "NOT") {
		my $qualifiers = shift;
		return undef unless $qualifiers;
		return $qualifiers->[0] unless (scalar @$qualifiers > 1);
		my $validQualifiers = [];
		foreach my $q (@$qualifiers) {
			next unless $q;
			push @$validQualifiers, $q;
		}
		$self->{subQualifiers} = $validQualifiers;
	} elsif ($qualifierType eq "SQL") {
		$self->{condition} = shift;
	} elsif ($qualifierType eq "MATCH") {

	    # form is
	    # IF::Qualifier->match("attribute, attribute, ...", "terms")
	    # where, if the attribute list is empty, we'll use all text attributes
	    # in the entity.  "terms" must be present and can use boolean
	    # terms (in the expected MySQL format).

	    $self->{_attributes} = [split(/,\s*/, shift)];
	    $self->{_terms} = shift;
	}

	return bless $self, $className;
}

# helper constructors:
# these should clean up the consumers a tad

sub key {
	my $className = shift;
	return $className->new("KEY", @_);
}
sub and {
	my $className = shift;
	return $className->new("AND", @_);
}
sub or {
	my $className = shift;
	return $className->new("OR", @_);
}
sub not {
	my $className = shift;
	return $className->new("NOT", @_);
}
sub sql {
	my $className = shift;
	return $className->new("SQL", @_);
}
sub match {
    my $className = shift;
    return $className->new("MATCH", @_);
}

#--- instance methods ----

sub requiresRepeatedJoin {
    my ($self) = @_;
    $self->{_requiresRepeatedJoin} = 1;
    return $self;
}

sub setEntity {
	my $self = shift;
	my $entity = shift;
	foreach my $subQualifier (@{$self->{subQualifiers}}) {
		$subQualifier->setEntity($entity);
	}
	$self->{entity} = $entity;
}

sub entity {
	my $self = shift;
	return $self->{entity};
}

sub sqlWithBindValuesForExpressionAndModel {
	my ($self, $sqlExpression, $model) = @_;
	return $self->sqlWithBindValuesForExpressionAndModelAndClause($sqlExpression, $model, "WHERE");
}

sub sqlWithBindValuesForExpressionAndModelAndClause {
	my ($self, $sqlExpression, $model, $clause) = @_;


    # This whole thing needs to be refactored
	if ($self->{type} eq "AND" || $self->{type} eq "OR") {
		#IF::Log::debug("Found AND or OR qualifier");
		my $subQualifierSQL = [];
		my $subQualifierBindValues = [];
		foreach my $subQualifier (@{$self->{subQualifiers}}) {
			my $subQualifierSQLWithBindValues =
					$subQualifier->sqlWithBindValuesForExpressionAndModelAndClause(
						$sqlExpression, $model, $clause
					);
			push (@$subQualifierSQL, $subQualifierSQLWithBindValues->{SQL});
			push (@$subQualifierBindValues, @{$subQualifierSQLWithBindValues->{BIND_VALUES}});
		}
		my $qualifierAsSQL = "(".join (" ".$self->{type}." ", @$subQualifierSQL).")";
		if ($self->isNegated()) {
			$qualifierAsSQL = " NOT ($qualifierAsSQL) ";
		}
		return {
			SQL => $qualifierAsSQL,
			BIND_VALUES => $subQualifierBindValues,
		};
	}

	if ($self->{type} eq "KEY" || $self->{type} eq "SQL") {
		if ($clause eq "HAVING") {
			return $self->translateIntoHavingSQLExpressionForModel($sqlExpression, $model);
		}
		return $self->translateConditionIntoSQLExpressionForModel($sqlExpression, $model);
	}

	# hacking the match type in here.  see the note above about
	# this needing to be refactored.
	if ($self->{type} eq "MATCH") {
		return $self->translateConditionIntoMatchExpressionForModel($sqlExpression, $model);
	}
}

# What a friggin mouthful.  I just had to pull this crap out
# and isolate it from the rest of the goop.  This will get
# rewritten at a later date...
sub _translateQualifierWithGoo {
	my ($self, $qualifierKey, $relationship, $targetEntity, $model, $sqlExpression, $operator, $value) = @_;

	my $aggregatorOperator;
	my $qualifierOperator;
	if ($operator eq "<>") {
		$aggregatorOperator = "NOT IN";
		$qualifierOperator = "=";
	} elsif ($operator eq "IS NOT") {
		$aggregatorOperator = "NOT IN";
		$qualifierOperator = "IS";
	} else {
		$aggregatorOperator = "IN";
		$qualifierOperator = $operator;
	}

	my $qualifiers = [];

	if ($relationship->qualifier()) {
		push (@$qualifiers, $relationship->qualifier());
	}

	my $rsa = $relationship->sourceAttribute();
	my $rta = $relationship->targetAttribute();

	my $groupingQualifier;
	if ($qualifierKey eq "creationDate" || $qualifierKey eq "modificationDate") {
		$groupingQualifier = IF::Qualifier->key($rsa." $aggregatorOperator %@",
								IF::FetchSpecification->new($targetEntity->name(),
									IF::Qualifier->and([
										@$qualifiers,
										IF::Qualifier->key("$qualifierKey $qualifierOperator $value"),
									]),
								)->subqueryForAttributes([$rta])
							);
	} else {
		$groupingQualifier = IF::Qualifier->key($rsa." $aggregatorOperator %@",
								IF::FetchSpecification->new($targetEntity->name(),
									IF::Qualifier->and([
										@$qualifiers,
										IF::Qualifier->key($targetEntity->aggregateKeyName()." = %@", $qualifierKey),
										IF::Qualifier->key($targetEntity->aggregateValueName()." $qualifierOperator $value"),
									]),
								)->subqueryForAttributes([$rta])
							);
	}
	$groupingQualifier->setEntity($self->entity());
	my $bindValues = $self->{_bindValues};
	my $subquery = $groupingQualifier->translateConditionIntoSQLExpressionForModel($sqlExpression, $model);
	return {
		SQL => $subquery->{SQL},
		BIND_VALUES => [ @{$subquery->{BIND_VALUES}}, @{$self->{_bindValues}}],
	};
}

# this breaks down the keypath by traversing it from relationship
# to relationship, and returns the target ecd and attribute
# TODO rewrite the translation code to use this.  That's a bit
# tricky because it'll require some stuff to be done during keypath
# traversal

sub _parseKeyPathOnEntityClassDescriptionWithSQLExpressionAndModel {
	my ($self, $keyPath, $ecd, $sqlExpression, $model) = @_;

	my $oecd = $ecd;  # original ecd
	my $cecd = $ecd;  # current ecd

	# Figure out the target ecd for the qualifier by looping through the keys in the path

	my $bits = [split(/\./, $keyPath)];

	if (scalar @$bits == 0) {
		$bits = [$keyPath];
	}
	my $qualifierKey;
	#$DB::single = 1;

	for my $i (0..$#$bits) {
		$qualifierKey = $bits->[$i];
		#IF::Log::debug("Checking $qualifierKey");
		# if it's the last key in the path, bail now
		last if ($i >= $#$bits);

		# otherwise, look up the relationship
		my $relationship = $cecd->relationshipWithName($qualifierKey);

		# if there's no such relationship, it might be a derived data source
		# so check for that
		unless ($relationship) {
			#IF::Log::debug("Grabbing derived source with name $qualifierKey");
			$relationship = $sqlExpression->derivedDataSourceWithName($qualifierKey);
		}

		unless (IF::Log::assert($relationship, "Relationship $qualifierKey exists on entity ".$cecd->name())) {
			$relationship = $sqlExpression->dynamicRelationshipWithName($qualifierKey);
			#IF::Log::error("Using dynamic relationship");
		}

		unless ($relationship) {
			return {};
		}

		my $tecd = $relationship->targetEntityClassDescription($model);

		return {} unless (IF::Log::assert($tecd, "Target entity class ".$relationship->targetEntity()." exists"));

		if ($tecd->isAggregateEntity()) {
			# We just bail on it if it's aggregate
			# TODO see if there's a way to insert an aggregate qualifier into the key path
			return {};
		}
		# follow it
		$cecd = $tecd;
	}
	#IF::Log::debug("Returning ".$cecd->name()." with attribute $qualifierKey");
	return {
		TARGET_ENTITY_CLASS_DESCRIPTION => $cecd,
		TARGET_ATTRIBUTE => $qualifierKey,
	};
}

# This is a bit of a mess because it actually assumes that the
# derived source is >first< right now, as in
# "DerivedSource.foo = id" whereas it should allow the
# derived source to be anywhere in the key path.

sub translateDerivedRelationshipQualifierIntoSQLExpressionForModel {
	my ($self, $relationship, $sqlExpression, $model) = @_;

	my ($sourceKeyPath, $operator, $subqueryOperator, $targetKeyPath) =
		($self->{condition} =~ /^\s*([\w\._-]+)\s*$QUALIFIER_REGEX\s*(ANY|ALL|SOME)?(.*)$/i);

	my $recd = $model->entityClassDescriptionForEntityNamed($self->{entity});
	my $sourceGoo = $self->_parseKeyPathOnEntityClassDescriptionWithSQLExpressionAndModel(
								$sourceKeyPath,
								$recd,
								$sqlExpression,
								$model);

	my $rhs = $targetKeyPath;

	if (IF::Utility::expressionIsKeyPath($targetKeyPath)) {
		my $targetGoo = $self->_parseKeyPathOnEntityClassDescriptionWithSQLExpressionAndModel(
								$targetKeyPath,
								$recd,
								$sqlExpression,
								$model);

		if (my $rtecd = $targetGoo->{TARGET_ENTITY_CLASS_DESCRIPTION}) {
			# create SQL for the qualifier on >that< entity
			my $tableName = $rtecd->_table();
			my $columnName = $rtecd->columnNameForAttributeName($targetGoo->{TARGET_ATTRIBUTE});
			if ($sqlExpression->hasSummaryAttributeForTable($targetGoo->{TARGET_ATTRIBUTE}, $tableName)) {
				$columnName = $sqlExpression->aliasForSummaryAttributeOnTable($targetGoo->{TARGET_ATTRIBUTE}, $tableName);
			}
			IF::Log::debug("Right target table name is $tableName");
			my $tableAlias = $sqlExpression->aliasForTable($tableName);

			$rhs = $tableAlias.".".$columnName;
		}
	}

	my $secd = $sourceGoo->{TARGET_ENTITY_CLASS_DESCRIPTION};

	#my $tableName = $secd->_table();
	#my $columnName = $secd->columnNameForAttributeName($sourceGoo->{TARGET_ATTRIBUTE});
	#if ($sqlExpression->hasSummaryAttributeForTable($sourceGoo->{TARGET_ATTRIBUTE}, $tableName)) {
	#	$columnName = $sqlExpression->aliasForSummaryAttributeOnTable($sourceGoo->{TARGET_ATTRIBUTE}, $tableName);
	#}
	my $tableAlias = $sqlExpression->aliasForTable($relationship->name());
	my $itn = $relationship->fetchSpecification()->entityClassDescription()->_table();
	IF::Log::debug("Looking for $sourceGoo->{TARGET_ATTRIBUTE} on $itn");
	my $columnName = $relationship->fetchSpecification()->entityClassDescription()->columnNameForAttributeName($sourceGoo->{TARGET_ATTRIBUTE});
	$columnName = $relationship->fetchSpecification()->sqlExpression()->aliasForColumnOnTable(
			$columnName,
			$itn
		);
	unless ($columnName) {
		if ($relationship->fetchSpecification()->sqlExpression()->hasSummaryAttributeForTable(
				$sourceGoo->{TARGET_ATTRIBUTE},
				$relationship->fetchSpecification()->entityClassDescription()->_table())) {
				$columnName = $relationship->fetchSpecification()->sqlExpression()->aliasForSummaryAttributeOnTable(
					$sourceGoo->{TARGET_ATTRIBUTE},
					$relationship->fetchSpecification()->entityClassDescription()->_table());
		} else {
			IF::Log::debug("Couldn't find alias for column $sourceGoo->{TARGET_ATTRIBUTE}");
		}
	}
	my $lhs = $tableAlias.".".$columnName;

	return { SQL => join(" ", $lhs, $operator, $subqueryOperator, $rhs), BIND_VALUES => $self->{_bindValues} };
}

# TODO move this method into a subclass of IF::Qualifier
# for match qualifiers
sub translateConditionIntoMatchExpressionForModel {
    my ($self, $sqlExpression, $model) = @_;

	my $ecd = $model->entityClassDescriptionForEntityNamed($self->{entity});
	return {} unless (IF::Log::assert($ecd, "Entity class description exists for $self->{entity}"));
	my $oecd = $ecd;  # original ecd
	my $cecd = $ecd;  # current ecd

    # figure out the attributes
    my $attributes = $self->{_attributes} || [];

    if (scalar @$attributes == 0) {
        foreach my $attribute (@{$oecd->allAttributes()}) {
            next unless $attribute->{TYPE} =~ /(CHAR|TEXT|BLOB)/i;
            push @$attributes, $attribute->{NAME};
        }
    }

    my $mappedAttributes = [];

    # calculate attributes by walking the key paths... is this even valid?

    foreach my $attributeName (@$attributes) {
        my $targetGoo = $self->_parseKeyPathOnEntityClassDescriptionWithSQLExpressionAndModel(
                            $attributeName, $oecd, $sqlExpression, $model);
    	if (my $tecd = $targetGoo->{TARGET_ENTITY_CLASS_DESCRIPTION}) {
			my $tableName = $tecd->_table();
			my $columnName = $tecd->columnNameForAttributeName($targetGoo->{TARGET_ATTRIBUTE});
            # if ($sqlExpression->hasSummaryAttributeForTable($targetGoo->{TARGET_ATTRIBUTE}, $tableName)) {
            #   $columnName = $sqlExpression->aliasForSummaryAttributeOnTable($targetGoo->{TARGET_ATTRIBUTE}, $tableName);
            # }
			#IF::Log::debug("Full-text match target table name is $tableName, column is $columnName");
			my $tableAlias = $sqlExpression->aliasForTable($tableName);

            push @$mappedAttributes, "$tableAlias.$columnName";
		}
    }

    IF::Log::dump("Matching on ".join(", ", @$mappedAttributes));
    # TODO escape terms here.
    my $terms = [split(/\s+/, $self->{_terms})];

    return {
        SQL => "MATCH(".join(", ", @$mappedAttributes).") AGAINST (? IN BOOLEAN MODE)",
        BIND_VALUES => [join(" ", @$terms)],
    };
}

# This is truly a rat's nest.  I need to gut and rewrite this
# ASAP...
sub translateConditionIntoSQLExpressionForModel {
	my ($self, $sqlExpression, $model) = @_;

	# short-circuit qualifiers that don't need to be translated.
	# TODO : rework the SQL in these to use the table aliases
	if ($self->{type} eq "SQL") {
		return {
			SQL => $self->{condition},
			BIND_VALUES => [],
		};
	}

	# There are three parts to a key-qualifier:
	# 1. key path
	# 2. operator
	# 3. values

	my ($keyPath, $operator, $subqueryOperator, $value) = ($self->{condition} =~ /^\s*([\w\._-]+)\s*$QUALIFIER_REGEX\s*(ANY|ALL|SOME)?(.*)$/i);

	my $ecd = $model->entityClassDescriptionForEntityNamed($self->{entity});
	return {} unless (IF::Log::assert($ecd, "Entity class description exists for $self->{entity} for $self->{condition}"));
	my $oecd = $ecd;  # original ecd
	my $cecd = $ecd;  # current ecd

	# Figure out the target ecd for the qualifier by looping through the keys in the path

	my $bits = [split(/\./, $keyPath)];

	#IF::Log::debug("Bits from $keyPath");
	#IF::Log::dump($bits);

	if (scalar @$bits == 0) {
		$bits = [$keyPath];
	}
	my $qualifierKey;
    my $deferredJoins = [];

	for my $i (0..$#$bits) {
		$qualifierKey = $bits->[$i];

		# if it's the last key in the path, bail now
		last if ($i >= $#$bits);

		# otherwise, look up the relationship
		my $relationship = $cecd->relationshipWithName($qualifierKey);

		# if there's no such relationship, it might be a derived data source
		# so check for that
		unless ($relationship) {
			$relationship = $sqlExpression->derivedDataSourceWithName($qualifierKey);
			# short circuit the rest of the loop if it's a derived
			# relationship because we don't need to add any
			# relationship traversal info to the sqlExpression
			if ($relationship) {
				return $self->translateDerivedRelationshipQualifierIntoSQLExpressionForModel($relationship, $sqlExpression, $model);
			}
		}

		unless ($relationship) {
			$relationship = $sqlExpression->dynamicRelationshipWithName($qualifierKey);
			#IF::Log::debug("Using dynamic relationship");
		}
		unless (IF::Log::assert($relationship, "Relationship $qualifierKey exists on entity ".$cecd->name())) {
			return {
				SQL => "", BIND_VALUES => [],
			};
		}
		my $tecd = $relationship->targetEntityClassDescription($model);

		return {} unless (IF::Log::assert($tecd, "Target entity class ".$relationship->targetEntity()." exists"));

		if ($tecd->isAggregateEntity()) {
			# We just bail on it if it's aggregate
			# TODO see if there's a way to insert an aggregate qualifier into the key path
			return $self->_translateQualifierWithGoo(
					$bits->[$i+1],
					$relationship,
					$tecd,
					$model,
					$sqlExpression,
					$operator,
					$value
				);
		}

		# add traversed relationships to the SQL expression
		if ($self->{_requiresRepeatedJoin}) {
		    push (@$deferredJoins, { ecd => $cecd, key => $qualifierKey });
		} else {
		    $sqlExpression->addTraversedRelationshipOnEntity($qualifierKey, $cecd);
        }

		# follow it
		$cecd = $tecd;
	}

	# create SQL for the qualifier on >that< entity
	my $tableName = $cecd->_table();

	my $columnName = $cecd->columnNameForAttributeName($qualifierKey);
	if ($sqlExpression->hasSummaryAttributeForTable($qualifierKey, $tableName)) {
		$columnName = $sqlExpression->aliasForSummaryAttributeOnTable($qualifierKey, $tableName);
	}

    my $tn = $tableName;
    # XXX! Kludge! XXX!
	if ($self->{_requiresRepeatedJoin}) {
	    $tn = $sqlExpression->addRepeatedTable($tn);
    }
	my $tableAlias = $sqlExpression->aliasForTable($tn);
	IF::Log::assert($tableAlias, "Alias for table $tn is $tableAlias");

	my $conditionInSQL;
	my $bindValues;

	if ($self->hasSubQuery()) {
		my $subquery = $value;
		my $sqlWithBindValues = $self->subQuery()->toSQLFromExpression();
		$subquery =~ s/\%\@/\($sqlWithBindValues->{SQL}\)/;
		$conditionInSQL = "$tableAlias.$columnName $operator $subqueryOperator $subquery";
		$bindValues = $sqlWithBindValues->{BIND_VALUES};
	} else {
		my $aggregateColumns = {
			uc($oecd->aggregateKeyName()) => 1,
			uc($oecd->aggregateValueName()) => 1,
			"creationDate" => 1,
			"modificationDate" => 1,
		};
		if ($oecd->isAggregateEntity()
			&& !$aggregateColumns->{uc($columnName)}
			&& !$oecd->_primaryKey()->hasKeyField(uc($columnName))) {
			$conditionInSQL = "$tableAlias.".$oecd->aggregateKeyName().
							" = %@ AND $tableAlias.".$oecd->aggregateValueName().
							" $operator $value";
			$bindValues = [$columnName, @{$self->{_bindValues}}];
		} else {
		    #IF::Log::debug("MEOW $value");
		    # TODO... I am pretty sure this code is redundant now;
		    # the code above takes care of resolving the key paths now.
			if (IF::Utility::expressionIsKeyPath($value)) {
				IF::Log::debug("key path");
				my $targetGoo = $self->_parseKeyPathOnEntityClassDescriptionWithSQLExpressionAndModel(
										$value,
										$ecd,
										$sqlExpression,
										$model);
				my $tecd = $targetGoo->{TARGET_ENTITY_CLASS_DESCRIPTION};
				my $ta = $targetGoo->{TARGET_ATTRIBUTE};
				if ($tecd) {
				    my $tn = $ecd->_table();

				    # XXX! Kludge! XXX!
                	if ($self->{_requiresRepeatedJoin}) {
                        # add that to the fetch representation
                        $tn = $sqlExpression->addRepeatedTable($tn);
                    }

					my $targetTableAlias = $sqlExpression->aliasForTable($tn);
					my $targetColumnName = $sqlExpression->aliasForColumnOnTable($ta, $ecd->_table());

					$value = "$targetTableAlias.$targetColumnName";
				}
			}
			$conditionInSQL = "$tableAlias.$columnName $operator $value";
			$bindValues = $self->{_bindValues};
		}
		$conditionInSQL =~ s/\%\@/\?/g;
	}

    # hack to add a join to a repeated qualifier
	foreach my $j (@$deferredJoins) {
	    IF::Log::debug("Adding repeated join on ".$j->{ecd}->name()." with key $j->{key}");
	    $sqlExpression->addRepeatedTraversedRelationshipOnEntity($j->{key}, $j->{ecd});
	}

	return {
		SQL => $conditionInSQL,
		BIND_VALUES => $bindValues,
	};
}

# TODO: Slated for rewrite to bring it up to date with
# the method above.

sub translateIntoHavingSQLExpressionForModel {
	my $self = shift;
	my $sqlExpression = shift;
	my $model = shift;
	if ($self->{type} eq "SQL") {
		return {
			SQL => $self->{condition},
			BIND_VALUES => [],
		};
	}
	my $conditionInSQL = "";
	my $bindValues;

	foreach my $operator (@QUALIFIER_OPERATORS) {
		next unless ($self->{condition} =~ /^\s*([\w\.]+)\s*$operator\s*(ANY|ALL|SOME)?(.*)$/i);

		my $key = $1;
		my $subqueryOperator = $2;
		my $value = $3;

		# check key for compound construct

		my @keyPathElements = split (/\./, $key);
		my $entityClassDescription = $model->entityClassDescriptionForEntityNamed($self->{entity});
		if ($entityClassDescription->isAggregateEntity()) {
			$entityClassDescription = $entityClassDescription->aggregateEntityClassDescription();
		}
		my ($tableName, $columnName, $columnAlias);
		if ($#keyPathElements > 0) {
			# traversing a relationship
			my $relationshipName = $keyPathElements[0];
			my $relationshipKey = $keyPathElements[1];
			IF::Log::debug("Relationship is named $relationshipName, entity is $self->{entity}");
			my $relationship = $model->relationshipWithNameOnEntity($relationshipName, $self->{entity});
			#IF::Log::dump($relationship);
			my $targetEntity = $model->entityClassDescriptionForEntityNamed($relationship->{TARGET_ENTITY});
			unless ($targetEntity) {
				IF::Log::error("No target entity found for qualifier $self->{condition} on $self->{entity}");
				last;
			}
			if ($targetEntity->isAggregateEntity()) {
				IF::Log::debug("Target entity is aggregate");
				my $aggregatorOperator;
				my $qualifierOperator;
				if ($operator eq "<>") {
					$aggregatorOperator = "NOT IN";
					$qualifierOperator = "=";
				} elsif ($operator eq "IS NOT") {
					$aggregatorOperator = "NOT IN";
					$qualifierOperator = "IS";
				} else {
					$aggregatorOperator = "IN";
					$qualifierOperator = $operator;
				}

				my $groupingQualifier = IF::Qualifier->key($relationship->{SOURCE_ATTRIBUTE}." $aggregatorOperator %@",
											IF::FetchSpecification->new($targetEntity->name(),
												IF::Qualifier->and([
													IF::Qualifier->key($targetEntity->aggregateKeyName()." = %@", $relationshipKey),
													IF::Qualifier->key($targetEntity->aggregateValueName()." $qualifierOperator $value"),
												]),
											)->subqueryForAttributes([$relationship->{TARGET_ATTRIBUTE}])
										);

				$groupingQualifier->setEntity($self->entity());
				my $bindValues = $self->{_bindValues};
				my $subquery = $groupingQualifier->translateConditionIntoSQLExpressionForModel($sqlExpression, $model);
				return {
					SQL => $subquery->{SQL},
					BIND_VALUES => [ @{$subquery->{BIND_VALUES}}, @{$self->{_bindValues}}],
				};
			} else {
				$sqlExpression->addTraversedRelationshipOnEntity($relationshipName, $entityClassDescription);
				$tableName = $targetEntity->_table();
				$columnName = $targetEntity->columnNameForAttributeName($relationshipKey);
			}
		} else {
			$columnName = $entityClassDescription->columnNameForAttributeName($key);
			$tableName = $entityClassDescription->_table();
		}

		if ($sqlExpression->hasColumnForTable($columnName, $tableName)) {
			$columnAlias = $sqlExpression->aliasForColumnOnTable($columnName, $tableName);
		} elsif ($sqlExpression->hasSummaryAttributeForTable($columnName, $tableName)) {
			$columnAlias = $sqlExpression->aliasForSummaryAttributeOnTable($columnName, $tableName);
		} else {
			IF::Log::error("Can't locate attribute $columnName for table $tableName");
		}

		if ($self->hasSubQuery()) {
			my $subquery = $value;
			my $sqlWithBindValues = $self->subQuery()->toSQLFromExpression();
			$subquery =~ s/\%\@/\($sqlWithBindValues->{SQL}\)/;
			$conditionInSQL = "$columnAlias $operator $subqueryOperator $subquery";
			$bindValues = $sqlWithBindValues->{BIND_VALUES};
		} else {
			$conditionInSQL = "$columnAlias $operator $value";
			$conditionInSQL =~ s/\%\@/\?/g;
			$bindValues = $self->{_bindValues};
		}

		last;
	}
	return {
		SQL => $conditionInSQL,
		BIND_VALUES => $bindValues,
	};
}

sub subQualifiers {
	my $self = shift;
	return $self->{subQualifiers};
}

sub setSubQualifiers {
	my $self = shift;
	$self->{subQualifiers} = shift;
}

sub condition {
	my $self = shift;
	return $self->{condition};
}

sub setCondition {
	my $self = shift;
	$self->{condition} = shift;
}

sub isNegated {
	my $self = shift;
	return $self->{isNegated};
}

sub setIsNegated {
	my $self = shift;
	$self->{isNegated} = shift;
}

sub hasSubQuery {
	my $self = shift;
	return ($self->subQuery()?1:0);
}

sub subQuery {
	my $self = shift;
	foreach my $bv (@{$self->{_bindValues}}) {
		return $bv if UNIVERSAL::isa($bv, "IF::FetchSpecification");
	}
	return undef;
}

#----------------------------------------------------
# class methods

sub orQualifierFromMultipleValuesForExpression {
	my $values = shift;
	my $expression = shift;
	return unless (IF::Array::isArray($values) && scalar @$values > 0);
	my $qualifiers = [];
	foreach my $value (@$values) {
		push (@$qualifiers, IF::Qualifier->key($expression, $value));
	}
	if (scalar @$values == 1) {
		return $qualifiers->[0];
	}
	return IF::Qualifier->or($qualifiers);
}

1;
