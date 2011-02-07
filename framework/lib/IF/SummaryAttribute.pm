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

package IF::SummaryAttribute;

use strict;
use IF::Log;
use IF::DB;
use IF::Model;

sub new {
	my $className = shift;
	my $name = shift;
	my $summary = shift;
	my @attributes = @_;

	my $self = {
		_name => $name,
		_summary => $summary,
		_attributes => \@attributes,
		_qualifiers => [],
	};
	bless $self, $className;
	return $self;
}

sub name {
	my $self = shift;
	return $self->{_name};
}

sub setName {
	my ($self, $value) = @_;
	$self->{_name} = $value;
}

sub entity {
	my $self = shift;
	return $self->{_entity};
}

sub setEntity {
	my ($self, $value) = @_;
	$self->{_entity} = $value;
}

sub summary {
	my $self = shift;
	return $self->{_summary};
}

sub setSummary {
	my $self = shift;
	$self->{_summary} = shift;
}

sub attributes {
	my $self = shift;
	return $self->{_attributes};
}

sub setAttributes {
	my ($self, $attributes) = @_;
	$self->{_attributes} = IF::Array->arrayFromObject($attributes);
}

# yikes, need to parse this the same way as
# we do with qualifiers... any way to share the code?

sub translateSummaryIntoSQLExpression {
	my ($self, $sqlExpression) = @_;

	# TODO this is cheezy but:
	my $model = IF::Model->defaultModel();
	my $summaryInSQL = $self->summary();
	foreach my $attribute (@{$self->attributes()}) {
		IF::Log::debug("Attribute: $attribute");
		# check key for compound construct

		my @keyPathElements = split (/\./, $attribute);

		my $entityClassDescription = $model->entityClassDescriptionForEntityNamed($self->entity());
		if ($entityClassDescription->isAggregateEntity()) {
			$entityClassDescription = $entityClassDescription->aggregateEntityClassDescription();
		}
		my $tableAlias;
		my $columnName;
		# TODO fix this nested logic nastiness
		if ($#keyPathElements > 0) {
			# traversing a relationship
			my $relationshipName = $keyPathElements[0];
			my $relationshipKey = $keyPathElements[1];
			IF::Log::debug("Relationship is named $relationshipName, entity is ".$self->entity());
			my $relationship = $model->relationshipWithNameOnEntity($relationshipName, $self->entity());

			if ($relationship) {

				my $targetEntity = $model->entityClassDescriptionForEntityNamed($relationship->{TARGET_ENTITY});
				unless ($targetEntity) {
					IF::Log::error("No target entity found for qualifier $self->{condition} on ".$self->entity());
					last;
				}
				if ($targetEntity->isAggregateEntity()) {
					IF::Log::debug("Target entity is aggregate");
					IF::Log::debug("Need to add qualifiers...");
#				my $groupingQualifier = IF::Qualifier->key($relationship->{SOURCE_ATTRIBUTE}." $aggregatorOperator %@",
#											IF::FetchSpecification->new($targetEntity->name(),
#												IF::Qualifier->and([
#													IF::Qualifier->key($targetEntity->aggregateKeyName()." = %@", $relationshipKey),
#													IF::Qualifier->key($targetEntity->aggregateValueName()." $qualifierOperator $value"),
#												]),
#											)->subqueryForAttributes([$relationship->{TARGET_ATTRIBUTE}])
#										);
#
#				$groupingQualifier->setEntity($self->entity());
#				my $bindValues = $self->{_bindValues};
#				my $subquery = $groupingQualifier->translateConditionIntoSQLExpressionForModel($sqlExpression, $model);
#				return {
#					SQL => $subquery->{SQL},
#					BIND_VALUES => [ @{$subquery->{BIND_VALUES}}, @{$self->{_bindValues}}],
#				};
				} else {
					$sqlExpression->addTraversedRelationshipOnEntity($relationshipName, $entityClassDescription);
					my $tableName = $targetEntity->_table();
					$columnName = $targetEntity->columnNameForAttributeName($relationshipKey);
					$tableAlias = $sqlExpression->aliasForTable($tableName);
				}
			} else {
				if ($relationshipName =~ /^[DT][0-9]+$/) {
					# it's a table alias so use it:
					$tableAlias = $relationshipName;
					$columnName = $relationshipKey;
				} else {
					# maybe it's a table name?
					$tableAlias = $sqlExpression->aliasForTable($relationshipName) || $relationshipName;
					$columnName = $sqlExpression->aliasForColumnOnTable($relationshipName, $relationshipKey) || $relationshipKey;
				}
			}
		} else {
			$columnName = $entityClassDescription->columnNameForAttributeName($attribute);
			my $tableName = $entityClassDescription->_table();
			$tableAlias = $sqlExpression->aliasForTable($tableName);
		}

		my $columnDefinition = "$tableAlias.$columnName";
		$summaryInSQL =~ s/\%\@/$columnDefinition/; # only replace the first instance of %@
	}
	return $summaryInSQL;

}

sub qualifiers {
	my $self = shift;

}

1;
