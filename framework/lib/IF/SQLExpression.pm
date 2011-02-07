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

package IF::SQLExpression;

# Perhaps we need to rename this to QueryBuilder or something
#
# this should be subclassed to provide
# custom behaviour for different DBs
use strict;
use IF::DB;
use IF::Qualifier;
use IF::Relationship::Derived;
use IF::Relationship::Modelled;

sub new {
	my $className = shift;
	my $self = {};
	bless $self, $className;
	$self->init();
	return $self;
}

sub init {
	my $self = shift;
	my $empty = {
		_entityClassDescriptions => {},
		_tables => {},
		_tablesInFetch => {},
		_columns => {},
		_summaryAttributes => {},
		_aliasCounter => 0,
		_repeatedJoinCounts => {},
		_tableAliasMap => {},
		_qualifierBindValues => [],
		_derivedBindValues => [],
		_qualifier => "",
		_sortOrderings => [],
		_groupBy => [],
		_fetchLimit => undef,
		_startIndex => 0,
		_traversedRelationships => {},
		_prefetchedRelationships => {},
		_dynamicRelationships => {},
		_defaultTable => '',
		_doNotFetch => {},
		_onlyFetch => {},
		_columnAndSummaryAliases => {},
	};
	# I'm sure there's ugly-ass perl shorthand for this but:
	foreach my $key (keys %$empty) {
		$self->{$key} = $empty->{$key};
	}
}

sub tables {
	my $self = shift;
}

sub tablesAsSQL {
	my $self = shift;
	my $tables = [];
	foreach my $tableName (sort {$a <=> $b} keys %{$self->{_tables}}) {
		next if ($tableName eq $self->{_defaultTable} &&
				scalar keys %{$self->{_prefetchedRelationshipClause}} > 0);
		my $table = $self->{_tables}->{$tableName};
		if ($self->isDerivedTable($table)) {
			push (@$tables, "(".$table->{EXPANSION}->{SQL}.") ".$self->aliasForTable($tableName));
		} else {
			unless ($self->{_prefetchedRelationshipClause}->{$tableName}) {
			    my $tn = $table->{NAME};
			    # XXX Kludge! XXX
        		$tn =~ s/_XXX_[0-9]+$//g;
        		# XXX End kludge! XXX
				push (@$tables, $tn." ".$self->aliasForTable($tableName));
			} else {
				push (@$tables, $self->{_prefetchedRelationshipClause}->{$tableName});
			}
		}
	}
	return join(", ", @$tables);
}

sub addTable {
	my ($self, $table) = @_;
	return if ($self->tableWithName($table));
	$self->addRelatedTable($table);
	unless ($self->{_defaultTable}) {
		$self->{_defaultTable} = $table;
	}
}

# This is the same as the previous method but does
# not set the table as a default.  This is key
# because sometimes you want to dangle a table
# off to the side for a purpose, but not have it
# part of the fetch, or indeed part of the model
# at all
sub addRelatedTable {
	my ($self, $table) = @_;
	return if $self->tableWithName($table);

	$self->{_tables}->{$table} = {
		NAME => $table,
		ALIAS => $self->{_aliasCounter},
	};
	$self->{_tableAliasMap}->{int($self->{_aliasCounter}).""} = $table;
	$self->{_aliasCounter}++;
}

sub addRepeatedTable {
    my ($self, $tn) = @_;
    $self->{_repeatedJoinCounts}->{$tn}++;

    # Create a fake table name
    $tn .= "_XXX_".$self->{_repeatedJoinCounts}->{$tn};

    # add that to the fetch representation
    $self->addRelatedTable($tn);

    # This hack is necessary to inform the qualifier that its table name has changed
    return $tn;
}

# when adding a derived source, you need to name it, although the name
# will never show in the resulting SQL; it's for internal use only.
sub addDerivedDataSourceWithDefinitionAndName {
	my ($self, $fetchSpecification, $name) = @_;
	return if ($self->tableWithName($name));

	$self->{_tables}->{$name} = {
		NAME => $name,
		ALIAS => $self->{_aliasCounter},
		DEFINITION => $fetchSpecification,
		EXPANSION => $fetchSpecification->toSQLFromExpression(),
	};

	$self->{_tableAliasMap}->{int($self->{_aliasCounter}).""} = $name;
	unless ($self->{_defaultTable}) {
		$self->{_defaultTable} = $name;
	}

	# drop the bind values in.  These need to appear BEFORE the bind values
	# that are bound into the WHERE clause.
	$self->appendDerivedBindValues($self->{_tables}->{$name}->{EXPANSION}->{BIND_VALUES});

	$self->{_aliasCounter}++;
}

sub derivedDataSourceWithName {
	my ($self, $name) = @_;
	my $t = $self->tableWithName($name);
	if ($t && $self->isDerivedTable($t)) {
		return IF::Relationship::Derived->newFromFetchSpecificationWithName($t->{DEFINITION}, $name);
	}
	return undef;
}

sub tableWithName {
	my ($self, $name) = @_;
	return $self->{_tables}->{$name};
}

sub aliasForTable {
	my $self = shift;
	my $name = shift;
	my $table = $self->tableWithName($name);
	# XXX hack - failover to the table alias
	# that is there because it's a repeated join.
	unless ($table) {
	    my $jc = $self->{_repeatedJoinCounts}->{$name};
	    if ($jc) {
	        $table = $self->tableWithName($name."_XXX_".$jc);
	    }
	}
	# End XXX Hack
	return unless $table;
	if ($self->isDerivedTable($table)) {
		return "D".int($table->{ALIAS});
	}
	return "T".int($table->{ALIAS});
}

sub isDerivedTable {
	my ($self, $table) = @_;
	if ($table->{EXPANSION}) {
		return 1;
	}
	return 0;
}

sub addTableToFetch {
	my $self = shift;
	my $tableName = shift;
	$self->{_tablesInFetch}->{$tableName} = 1;
}

sub addRepeatedTraversedRelationshipOnEntity {
    my ($self, $relationshipName, $entityClassDescription) = @_;
    $self->addTraversedRelationshipOnEntity($relationshipName, $entityClassDescription, 1);
}

# TODO refactor this... it needs to call something called
# "qualifierForTraversedRelationshipOnEntity" to generate
# the SQL

sub addTraversedRelationshipOnEntity {
	my ($self, $relationshipName, $entityClassDescription, $shouldTraverseToRepeatedTable) = @_;

	if (!$shouldTraverseToRepeatedTable && $self->{_traversedRelationships}->{$relationshipName}) {
		return;
	}
	my $relationship = $entityClassDescription->relationshipWithName($relationshipName) || $self->dynamicRelationshipWithName($relationshipName);
	return unless $relationship;

	my $model = IF::Model->defaultModel();
	my $targetEntityName = $relationship->targetEntity();
	my $targetEntity = $relationship->targetEntityClassDescription($model);
	my $sourceTable = $entityClassDescription->_table();
	#IF::Log::debug("source table is $sourceTable");
	#IF::Log::dump($self->{_tables});
	my $sourceTableAlias = $self->aliasForTable($sourceTable);
	my $targetTable = $targetEntity->_table();

	# XXX HAck!
	if ($shouldTraverseToRepeatedTable) {
	    $self->{_traversedRelationshipCounts}->{$relationshipName}++;
	    #IF::Log::debug("Traversing to table $targetTable once more");
	    my $newTableName = $targetTable."_XXX_".$self->{_repeatedJoinCounts}->{$targetTable};
	    #IF::Log::debug("Should traverse to $newTableName");
	    if (IF::Log::assert($self->tableWithName($newTableName), "$newTableName is already registered")) {
	        $targetTable = $newTableName;
	    }
	}
	# End XXX Hack!

	#IF::Log::debug($targetEntityName, $sourceTable, $sourceTableAlias, $targetTable);
	unless ($self->tableWithName($targetTable)) {
		$self->addTable($targetTable);
		$self->{_entityClassDescriptions}->{$targetEntityName} = $targetEntity;
	}
	my $targetTableAlias = $self->aliasForTable($targetTable);
	#IF::Log::debug("Alias for $targetTable is $targetTableAlias");
	my $sourceAttribute = $relationship->sourceAttribute();
	my $targetAttribute = $relationship->targetAttribute();
	my $qualifiers = [];
	if ($relationship->type() eq "FLATTENED_TO_MANY") {
		my $joinTable = $relationship->joinTable();

		# XXX hack!
		if ($shouldTraverseToRepeatedTable) {
		    $joinTable = $self->addRepeatedTable($joinTable);
		}
		unless ($self->tableWithName($joinTable)) {
			$self->addTable($joinTable);
		}
		my $joinTableAlias = $self->aliasForTable($joinTable);
		push (@$qualifiers, "$sourceTableAlias.$sourceAttribute = $joinTableAlias.".$relationship->joinTargetAttribute());
		push (@$qualifiers, "$joinTableAlias.".$relationship->joinSourceAttribute()." = $targetTableAlias.$targetAttribute");

        # Hmmmm, why are join qualifiers added in here?
        if ($relationship->joinQualifiers()) {
            foreach my $k (keys %{$relationship->joinQualifiers()}) {
                my $v = $relationship->joinQualifiers()->{$k};
                push (@$qualifiers, "$joinTableAlias.$k = ".IF::DB::quote($v));
            }
        }
	} else {
		push (@$qualifiers, "$sourceTableAlias.$sourceAttribute = $targetTableAlias.$targetAttribute");
	}
	# there is a potential "loop" here, not sure how to trap it (where
	# this is called by translateCondition...() which in turn calls translateCondition...())
	if ($relationship->qualifier()) {
		my $q = $relationship->qualifier();
		$q->setEntity($targetEntityName);
		my $c = $relationship->qualifier()->translateConditionIntoSQLExpressionForModel($self, $model);

		if (scalar @{$c->{BIND_VALUES}}) {
			# tricky case, where there's a bind value in the qualifier that's
			# being injected, but there's no way to pass that bind value out
			# and insert it into the ordering
			# For now we are going to >assume< we can quote values, and insert them
			# directly in place of the '?'s.
			my $s = $c->{SQL};
			foreach my $b (@{$c->{BIND_VALUES}}) {
				my $qb = IF::DB::quote($b);
				$s =~ s/\?/$qb/;
			}
			push (@$qualifiers, $s);
		} else {
			push (@$qualifiers, $c->{SQL});
		}
	}

	# XXX HACK!
	if ($shouldTraverseToRepeatedTable) {
	    $relationshipName .= "_XXX_".$self->{_traversedRelationshipCounts}->{$relationshipName};
	    #IF::Log::debug("Added $relationshipName to traversal");
	}
	$self->{_traversedRelationships}->{$relationshipName} = join(" AND ", @$qualifiers);
}

sub addPrefetchedRelationshipOnEntity {
	my $self = shift;
	my $relationshipName = shift;
	my $entityClassDescription = shift;
	$self->addEntityClassDescription($entityClassDescription);
	my $model = IF::Model->defaultModel();
	my $relationship = $entityClassDescription->relationshipWithName($relationshipName) || $self->dynamicRelationshipWithName($relationshipName);
	return unless $relationship;

	my $targetEntityClass = $relationship->targetEntityClassDescription($model);
	$self->addEntityClassDescription($targetEntityClass);
	$self->addTraversedRelationshipOnEntity($relationshipName, $entityClassDescription);
	$self->{_prefetchedRelationships}->{$relationship->targetEntity()} = $relationshipName;
	$self->addTableToFetch($targetEntityClass->_table());
}

sub relationshipNameForEntityType {
	my $self = shift;
	my $entityType = shift;
	my $r = $self->{_prefetchedRelationships}->{$entityType};
	return $r if $r;
	foreach my $dr (keys %{$self->{_dynamicRelationships}}) {
		next unless $dr->targetEntityClassDescription()->name() eq $entityType;
		return $dr->name();
	}
	return undef;
}

sub dynamicRelationshipWithName {
	my ($self, $relationshipName) = @_;
	return $self->{_dynamicRelationships}->{$relationshipName};
}

sub addDynamicRelationship {
	my ($self, $dr) = @_;
	return unless IF::Log::assert($dr, "Adding dynamic relationship");
	# Want to be able to do this:
	my $defaultTable = $self->{_defaultTable};
	if ($defaultTable) {
		$dr->setEntityClassDescription($self->entityClassDescriptionForTableNamed($defaultTable));
	}
	$self->{_dynamicRelationships}->{$dr->name()} = $dr;
}

sub dynamicRelationshipNames {
	my ($self) = @_;
	return [keys %{$self->{_dynamicRelationships}}];
}

sub removeTableWithName {
	my $self = shift;
	my $name = shift;
	my $aliasForTable = $self->aliasForTable($name);
	delete $self->{_tables}->{$name};
	delete $self->{_tableAliasMap}->{$aliasForTable};
	delete $self->{_tablesInFetch}->{$name};
}

sub columns {
	my $self = shift;
	return $self->{_columns};
}

sub addColumnForTable {
	my ($self, $column, $table) = @_;
	my $tableEntry = $self->tableWithName($table);
	return unless $tableEntry;
	$self->addColumnForTableWithAlias($column, $table, $self->aliasForTable($table)."_$column");
}

sub addColumnForTableWithAlias {
	my ($self, $column, $table, $alias) = @_;
	$self->{_columns}->{$table}->{$column} = {
		NAME => $column,
		ALIAS => $alias,
		TABLE => $table,
	};
	$self->{_columnAndSummaryAliases}->{uc($alias)} = $self->{_columns}->{$table}->{$column};
}

sub removeColumnForTable {
	my ($self, $column, $table) = @_;
	return unless $self->tableWithName($table);
	delete $self->{_columns}->{$table}->{$column};
}

sub addSummaryAttributeForTable {
	my ($self, $summary, $table) = @_;
	my $tableEntry = $self->tableWithName($table);
	return unless $tableEntry;
	$self->addSummaryAttributeForTableWithAlias($summary, $table, $self->aliasForTable($table)."_".$summary->name());
}

sub addSummaryAttributeForTableWithAlias {
	my ($self, $summary, $table, $alias) = @_;
	$self->{_summaryAttributes}->{$table}->{$summary->name()} = {
		NAME => $summary->name(),
		SUMMARY => $summary,
		ALIAS => $alias,
		TABLE => $table,
	};
	$self->{_columnAndSummaryAliases}->{uc($alias)} = $self->{_summaryAttributes}->{$table}->{$summary->name()};
}

sub hasSummaryAttributeForTable {
	my ($self, $summaryName, $tableName) = @_;
	return exists($self->{_summaryAttributes}->{$tableName}->{$summaryName});
}

sub aliasForSummaryAttributeOnTable {
	my ($self, $summaryName, $tableName) = @_;
	return $self->{_summaryAttributes}->{$tableName}->{$summaryName}->{ALIAS}
}

sub hasColumnForTable {
	my ($self, $column, $tableName) = @_;
	return exists($self->{_columns}->{$tableName}->{$column});
}

sub aliasForColumnOnTable {
	my ($self, $column, $tableName) = @_;
	return $self->{_columns}->{$tableName}->{$column}->{ALIAS};
}

sub columnsAsSQL {
	my $self = shift;
	my $columns = [];
	foreach my $tableName (keys %{$self->{_tablesInFetch}}) {
		my $table = $self->{_columns}->{$tableName};
		my $tableAlias = $self->aliasForTable($tableName);
		foreach my $column (keys %$table) {
			next unless $self->shouldFetchColumnForTable($column, $tableName);
			push (@$columns, $tableAlias.".".$table->{$column}->{NAME}." AS ".$table->{$column}->{ALIAS});
		}
		$table = $self->{_summaryAttributes}->{$tableName};
		foreach my $summaryName (keys %$table) {
			next unless $self->shouldFetchSummaryAttributeForTable($summaryName, $tableName);
			push (@$columns, $table->{$summaryName}->{SUMMARY}->translateSummaryIntoSQLExpression($self)." AS ".$table->{$summaryName}->{ALIAS});
		}
	}
	return join(", ", @$columns);
}

sub shouldFetchColumnForTable {
	my ($self, $column, $table) = @_;
	return 1 if exists ($self->{_onlyFetch}->{$table}->{columns}->{$column});
	return 0 if (scalar keys %{$self->{_onlyFetch}->{$table}->{columns}});
	return 1 unless exists($self->{_doNotFetch}->{$table}->{columns}->{$column});
	return 0;
}

sub shouldFetchSummaryAttributeForTable {
	my ($self, $summaryAttribute, $table) = @_;
	return 1 if exists ($self->{_onlyFetch}->{$table}->{summaryAttributes}->{$summaryAttribute});
	return 0 if (scalar keys %{$self->{_onlyFetch}->{$table}->{summaryAttributes}});
	return 1 unless exists($self->{_doNotFetch}->{$table}->{summaryAttributes}->{$summaryAttribute});
	return 0;
}

sub doNotFetchColumnForTable {
	my ($self, $column, $table) = @_;
	$self->{_doNotFetch}->{$table}->{columns}->{$column} = 1;
}

sub doNotFetchSummaryAttributeForTable {
	my ($self, $summaryAttributes, $table) = @_;
	$self->{_doNotFetch}->{$table}->{summaryAttributes}->{$summaryAttributes} = 1;
}

sub onlyFetchColumnForTable {
	my ($self, $column, $table) = @_;
	$self->{_onlyFetch}->{$table}->{columns}->{$column} = 1;
}

sub onlyFetchSummaryAttributeForTable {
	my ($self, $summaryAttributes, $table) = @_;
	$self->{_onlyFetch}->{$table}->{summaryAttributes}->{$summaryAttributes} = 1;
}

sub bindValues {
	my $self = shift;
	return [@{$self->{_derivedBindValues}}, @{$self->{_qualifierBindValues}}];
}

sub setQualifierBindValues {
	my $self = shift;
	$self->{_qualifierBindValues} = shift;
}

sub appendDerivedBindValues {
	my ($self, $values) = @_;
	$self->{_derivedbindValues} ||= [];
	push (@{$self->{_derivedBindValues}}, @$values);
}

sub qualifier {
	my $self = shift;
	return $self->{_qualifier};
}

sub setQualifier {
	my $self = shift;
	$self->{_qualifier} = shift;
}

sub summaryQualifier {
	my $self = shift;
	return $self->{_summaryQualifier};
}

sub setSummaryQualifier {
	my $self = shift;
	$self->{_summaryQualifier} = shift;
}

sub hasSummaryQualifier {
	my $self = shift;
	return exists($self->{_summaryQualifier});
}

sub distinct {
	my ($self) = @_;
	return $self->{distinct};
}

sub setDistinct {
	my ($self, $value) = @_;
	$self->{distinct} = $value;
}

# TODO: Implement default sort orderings?
sub sortOrderings {
	my $self = shift;
	return $self->{_sortOrderings};
}

sub setSortOrderings {
	my $self = shift;
	$self->{_sortOrderings} = shift;
}

sub groupBy {
	my $self = shift;
	return $self->{_groupBy};
}

sub setGroupBy {
	my $self = shift;
	$self->{_groupBy} = shift;
}

# TODO: implement this so it can walk relationships
sub sortOrderingsAsSQL {
	my $self = shift;
	my $orderColumns = [];
	if ($self->shouldFetchRandomly()) {
		push(@$orderColumns, "RAND() ASC");
	}
	my $defaultTableAlias = $self->aliasForTable($self->{_defaultTable});
	my $defaultEntityClass = $self->entityClassDescriptionForTableWithName($self->{_defaultTable});
	foreach my $ordering (@{$self->{_sortOrderings}}) {
		my $columnName = $ordering;
		my $tableAlias;
		my $orderBy;
		if ($defaultEntityClass) {
			my ($attributeName, $direction) = split(/[ ]+/, $columnName, 2);
			if ($attributeName =~ /\./) {
				my ($relationshipName, $attributeName) = split(/\./, $attributeName, 2);
				if ($self->{_traversedRelationships}->{$relationshipName}) {
					my $relationship = $defaultEntityClass->relationshipWithName($relationshipName) || $self->dynamicRelationshipWithName($relationshipName);
					if ($relationship) {
						my $targetEntityClassDescription = $self->{_entityClassDescriptions}->{$relationship->{TARGET_ENTITY}};
						if ($targetEntityClassDescription) {
							$tableAlias = $self->aliasForTable($targetEntityClassDescription->_table());
							$columnName = $targetEntityClassDescription->columnNameForAttributeName($attributeName);
							$orderBy = "$tableAlias.$columnName";
						}
					}
				}
			} else {
				$tableAlias = $defaultTableAlias;
				if ($self->{_summaryAttributes}->{$self->{_defaultTable}}->{$attributeName}) {
					#IF::Log::debug("Using attribute for ordering!");
					$columnName = $self->{_summaryAttributes}->{$self->{_defaultTable}}->{$attributeName}->{ALIAS};
					$orderBy = $columnName;
				} else {
					my $columnNameForAttributeName = $defaultEntityClass->columnNameForAttributeName($attributeName);
					$columnName = $columnNameForAttributeName || $attributeName;
					$orderBy = "$tableAlias.$columnName";
				}
			}
			if ($direction) {
				$orderBy .= " $direction";
			}
		}
		push (@$orderColumns, $orderBy);
	}
	return join(", ", @$orderColumns);
}

# This is also a rehash of the same code that's used in Qualifier to generate
# SQL... and also in IF::SummaryAttribute to generate its SQL too.  We can almost
# certainly rework it to share the same parsing code.

sub groupByAsSQL {
	my $self = shift;
	my $groupColumns = [];
	my $defaultTableAlias = $self->aliasForTable($self->{_defaultTable});
	my $defaultEntityClass = $self->entityClassDescriptionForTableWithName($self->{_defaultTable});
	#IF::Log::debug("doing groupings for table $self->{_defaultTable}...");
	foreach my $grouping (@{$self->{_groupBy}}) {
		#IF::Log::debug("Checking for grouping $grouping");
		my $tableAlias;
		my $columnName;
		my $groupBy;
		if ($defaultEntityClass) {
			my $attributeName = $grouping;
			if ($attributeName =~ /\./) {
				my ($relationshipName, $attributeName) = split(/\./, $attributeName, 2);
				if ($self->{_traversedRelationships}->{$relationshipName} || $self->dynamicRelationshipWithName($relationshipName)) {
					my $relationship = $defaultEntityClass->relationshipWithName($relationshipName)
										|| $self->dynamicRelationshipWithName($relationshipName);
					if ($relationship) {
						my $targetEntityClassDescription = $relationship->targetEntityClassDescription()
															|| $self->{_entityClassDescriptions}->{$relationship->{TARGET_ENTITY}};
						if (IF::Log::assert($targetEntityClassDescription, "Located target entity class description for $relationshipName")) {
							# This is crappy.  All of this needs to be refactored.
							unless ($self->{_traversedRelationships}->{$relationshipName}) {
								$self->addTraversedRelationshipOnEntity($relationshipName, $defaultEntityClass);
							}
							$tableAlias = $self->aliasForTable($targetEntityClassDescription->_table());
							$columnName = $targetEntityClassDescription->columnNameForAttributeName($attributeName);
							if (IF::Log::assert($tableAlias && $columnName, "We have a target table and column")) {
								$groupBy = "$tableAlias.$columnName";
							}
						}
					} else {
						IF::Log::error("Didn't find relationship $relationshipName");
					}
				} else {
					# maybe it's an explicit table name or table alias:
					#IF::Log::debug("Checking for table or alias name for $relationshipName");
					my $tableName = $self->aliasForTable($relationshipName) || $relationshipName;
					my $columnName = $self->aliasForColumnOnTable($attributeName, $tableName) || $attributeName;
					if ($tableName && $columnName) {
						$groupBy = $tableName.".".$columnName;
					}
					#IF::Log::debug("....... grouping by $groupBy");
				}
			} else {
				#IF::Log::debug("Grouping by a straight attribute");
				$tableAlias = $defaultTableAlias;
				# check for summary attributes with this name
				if ($self->{_summaryAttributes}->{$self->{_defaultTable}}->{$attributeName}) {
					$columnName = $self->{_summaryAttributes}->{$self->{_defaultTable}}->{$attributeName}->{ALIAS};
					$groupBy = $columnName;
				} else {
					my $columnNameForAttributeName = $defaultEntityClass->columnNameForAttributeName($attributeName);
					$groupBy = "$tableAlias.$columnNameForAttributeName";
				}
			}
		}
		push (@$groupColumns, $groupBy);
	}
	return join(", ", @$groupColumns);
}

sub fetchLimit {
	my $self = shift;
	return $self->{_fetchLimit};
}

sub setFetchLimit {
	my $self = shift;
	$self->{_fetchLimit} = shift;
}

sub startIndex {
	my $self = shift;
	return $self->{_startIndex};
}

sub setStartIndex {
	my $self = shift;
	$self->{_startIndex} = shift;
}

sub shouldFetchRandomly {
	my ($self) = @_;
	return $self->{shouldFetchRandomly};
}

sub setShouldFetchRandomly {
	my ($self, $value) = @_;
	$self->{shouldFetchRandomly} = $value;
}

sub inflateAsInstancesOfEntityNamed {
	my ($self) = @_;
	return $self->{inflateAsInstancesOfEntityNamed};
}

sub setInflateAsInstancesOfEntityNamed {
	my ($self, $value) = @_;
	$self->{inflateAsInstancesOfEntityNamed} = $value;
}

sub selectStatement {
	my $self = shift;

	my $sql = "SELECT ";
	if ($self->distinct()) {
		$sql .= "DISTINCT ";
	}
	$sql .= $self->columnsAsSQL();
	$sql .= " FROM ";
	$sql .= $self->tablesAsSQL();
	$sql .= $self->whereClause();
	if (IF::Array->arrayHasElements($self->groupBy())) {
		$sql .= " GROUP BY ";
		$sql .= $self->groupByAsSQL();

		if ($self->hasSummaryQualifier()) {
			$sql .= $self->havingClause();
		}
	}
	if (($self->sortOrderings() && scalar @{$self->sortOrderings()} > 0) || $self->shouldFetchRandomly()) {
		$sql .= " ORDER BY ";
		$sql .= $self->sortOrderingsAsSQL();
	}
	if ($self->fetchLimit()) {
		$sql .= " LIMIT ".int($self->startIndex()).", ".int($self->fetchLimit());
	}
	return $sql;
}

sub selectCountStatement {
	my $self = shift;

	my $sql;
	# TODO NBNBNB This will not work if the table aliasing is changed!
	my $rootEntityClassDescription = $self->entityClassDescriptionForTableWithName(
										$self->tableNameForAlias("0")
									);

	if ($rootEntityClassDescription) {
		my $primaryKey = $rootEntityClassDescription->_primaryKey();
		$sql = "SELECT COUNT(DISTINCT T0.$primaryKey) AS COUNT FROM ";
	} else {
		$sql = "SELECT COUNT(*) AS COUNT FROM ";
	}
	$sql .= $self->tablesAsSQL();
	$sql .= $self->whereClause();
	if (IF::Array->arrayHasElements($self->groupBy())) {
		$sql .= " GROUP BY ";
		$sql .= $self->groupByAsSQL();

		if ($self->hasSummaryQualifier()) {
			$sql .= $self->havingClause();
		}
	}
	return $sql;
}

sub whereClause {
	my $self = shift;
	my $sql = $self->qualifier();
	my @traversedRelationshipQualifiers = values %{$self->{_traversedRelationships}};
	if (scalar @traversedRelationshipQualifiers > 0) {
		if ($sql ne "") {
			$sql .= " AND ";
		}
		$sql .= join(" AND ", @traversedRelationshipQualifiers);
	}
	if ($sql ne "") {
		return " WHERE $sql";
	}
	return "";
}

sub havingClause {
	my $self = shift;
	my $sql = $self->summaryQualifier();
	if ($sql ne "") {
		return " HAVING $sql";
	}
	return "";
}

# Convenience methods:

sub addTableAndColumnsForEntityClassDescription {
	my $self = shift;
	my $entityClassDescription = shift;

	my $table = $entityClassDescription->_table();
	return unless $table;
	$self->addTable($table);

	while (my ($attributeName, $attribute) =  each %{$entityClassDescription->attributes()}) {
		$self->addColumnForTable($attribute->{COLUMN_NAME}, $table);
	}
}

sub addEntityClassDescription {
	my $self = shift;
	my $entityClassDescription = shift;
	$self->addTableAndColumnsForEntityClassDescription($entityClassDescription);
	$self->{_entityClassDescriptions}->{$entityClassDescription->name()} = $entityClassDescription;
	# set the reverse-mapping:
	my $tableName = $entityClassDescription->_table();
	my $table = $self->tableWithName($tableName);
	return unless $table;
	$table->{ENTITY_CLASS} = $entityClassDescription;
}

# This is used for subqueries only:
sub addEntityClassDescriptionWithColumns {
	my ($self, $ecd, $columns) = @_;
	my $table = $ecd->_table();
	return unless $table;
	$self->addTable($table);
	foreach my $columnName (@$columns) {
		$self->addColumnForTable($columnName, $table);
	}
}

sub entityClassDescriptionForTableWithName {
	my $self = shift;
	my $tableName = shift;
	my $table = $self->tableWithName($tableName);
	#IF::Log::dump($table);
	return unless $table;
	return $table->{ENTITY_CLASS};
}

sub tableNameForAlias {
	my $self = shift;
	my $alias = shift;
	return $self->{_tableAliasMap}->{$alias};
}

# perhaps this should be outside this class?
# TODO: allow table alias format to be set rather than
# hardcoded as t*
sub dictionaryOfEntitiesFromRawRow {
	my $self = shift;
	my $row = shift;

	my $tables = {};
	my $entities = {};
	my $objectContext = IF::ObjectContext->new();
	#IF::Log::dump($row);
	foreach my $key (keys %$row) {
		next unless $key =~ /^T([0-9]+)_([A-Za-z0-9_]+)$/;
		my $tableAlias = $1;
		my $columnName = $2;
		my $tableName = $self->tableNameForAlias($tableAlias);
		$tables->{$tableName}->{$columnName} = $row->{$key};
	}
	#IF::Log::dump($tables);
	foreach my $tableName (keys %$tables) {
		#IF::Log::debug($tableName);
		my $entityClassDescription = $self->entityClassDescriptionForTableWithName($tableName);
		#IF::Log::debug($entityClassDescription);
		if ($entityClassDescription) {
			my $entityName;
			if ($entityClassDescription->isAggregateEntity()) {
				$entities->{"IF::_AggregatedKeyValuePair"} = IF::_AggregatedKeyValuePair->new(%{$tables->{$tableName}});
				$entities->{"IF::_AggregatedKeyValuePair"}->setEntityClassDescription($entityClassDescription);
			} else {
				if ($tableName eq $self->{_defaultTable}) {
					$entityName = $self->inflateAsInstancesOfEntityNamed();
				}
				$entityName ||= $entityClassDescription->name();
				$entities->{$entityName} = $objectContext->entityFromHash($entityName, $tables->{$tableName});
			}
		} else {
			$entities->{_RELATIONSHIP_HINTS} = $tables->{$tableName};
		}
	}
	return $entities;
}


sub dictionaryFromRawRow {
	my ($self, $row) = @_;

	my $dictionary = IF::Dictionary->new();
	foreach my $key (keys %$row) {
		my $mappedKey = $key;
		my $alias = $self->{_columnAndSummaryAliases}->{uc($key)};
		if ($alias) {
			if ($alias->{SUMMARY}) {
				$mappedKey = $alias->{NAME};
			} else {
				my $ecd = $self->entityClassDescriptionForTableWithName($alias->{TABLE});
				if ($ecd) {
					$mappedKey = $ecd->attributeNameForColumnName($alias->{NAME});
				}
			}
		}
		$dictionary->setObjectForKey($row->{$key}, $mappedKey);
	}
	return $dictionary;
}

1;
