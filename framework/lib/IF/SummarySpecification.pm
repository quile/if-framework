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

package IF::SummarySpecification;
use strict;
use base qw(IF::FetchSpecification);

# ++++ instance methods ++++

sub setGroupBy {
    my ($self, $value) = @_;
    $self->{_groupBy} = IF::Array->arrayFromObject($value);
}

sub groupBy {
    my $self = shift;
    return $self->{_groupBy};
}

sub buildSQLExpression {
    my $self = shift;
    # Call the parent to initialise the sqlExpression object
    $self->SUPER::buildSQLExpression();

    my $model = IF::Model->defaultModel();

    # call SQLExpression to add the groupBy stuff
    if (IF::Array->arrayHasElements($self->groupBy())) {
        $self->sqlExpression()->setGroupBy($self->groupBy());
    }

    # add the summary attributes to the sqlExpression
    if (IF::Array->arrayHasElements($self->summaryAttributes())) {
        my $summaryAttributes = [];
        my $ecd = $model->entityClassDescriptionForEntityNamed($self->{entity});
        foreach my $summaryAttribute (@{$self->summaryAttributes()}) {
            $self->sqlExpression()->addSummaryAttributeForTable($summaryAttribute, $ecd->_table());
        }
    }

    # if there is a summary qualifier, evaluate those and add them
    if ($self->hasSummaryQualifier()) {
        my $sqlQualifier = $self->summaryQualifier()->sqlWithBindValuesForExpressionAndModelAndClause($self->sqlExpression(), $model, "HAVING");
        IF::Log::debug("[ Summary Qualifier: ".$sqlQualifier->{SQL}." Bind values: ".join(", ", @{$sqlQualifier->{BIND_VALUES}})." ]");
        $self->sqlExpression()->setSummaryQualifier($sqlQualifier->{SQL});
        my $newBindValues = IF::Array->arrayFromObject($sqlQualifier->{BIND_VALUES});
        if (scalar @$newBindValues) {
            my $bindValues = $self->sqlExpression()->bindValues();
            push (@$bindValues, @$newBindValues);
            $self->sqlExpression()->setQualifierBindValues($bindValues);
        }
    }
}

sub summaryAttributes {
    my $self = shift;
    return $self->{_summaryAttributes};
}

# TODO this has a side-effect of setting the entity on the
# submitted objects... maybe change its name?
sub setSummaryAttributes {
    my ($self, $value) = @_;
    $self->{_summaryAttributes} = IF::Array->arrayFromObject($value);
    foreach my $summaryAttribute (@{$self->{_summaryAttributes}}) {
        $summaryAttribute->setEntity($self->{entity});
    }
}

sub initWithSummaryAttributes {
    my ($self, $summaryAttributes) = @_;
    $self->setSummaryAttributes($summaryAttributes);
    return $self;
}

sub summaryQualifier {
    my $self = shift;
    return $self->{_summaryQualifier};
}

sub setSummaryQualifier {
    my $self = shift;
    $self->{_summaryQualifier} = shift;
    $self->{_summaryQualifier}->setEntity($self->{entity});
}

sub hasSummaryQualifier {
    my $self = shift;
    return exists($self->{_summaryQualifier});
}

sub unpackResultsIntoDictionaries {
    my ($self, $results) = @_;
    my $unpackedResults = {};

    my $primaryKey = uc($self->{_entityClassDescription}->_primaryKey()->stringValue());
    my $objectContext = IF::ObjectContext->new();
    #IF::Log::debug("::: will be hashing the entities by $primaryKey");
    my $dictionaries = [];
    foreach my $result (@$results) {
        push (@$dictionaries, $self->sqlExpression()->dictionaryFromRawRow($result));
    }
    return $dictionaries;
}

sub toCountSQLFromExpression {
    my $self = shift;

    my $fl = $self->fetchLimit();
    $self->setFetchLimit();
    $self->buildSQLExpression();
    $self->setFetchLimit($fl);

    # Generate the SQL for the whole statement, and return it and
    # the bind values ready to be passed to the DB
    return {
        SQL => "SELECT COUNT(*) AS COUNT FROM (".$self->sqlExpression()->selectStatement().") AS CT",
        BIND_VALUES => $self->sqlExpression()->bindValues(),
    };
}


1;