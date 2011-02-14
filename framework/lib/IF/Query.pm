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

package IF::Query;

use strict;
use base qw(
    IF::Entity::Transient
);
use IF::DB;
use IF::Log;
use IF::Array;
use IF::ObjectContext;

sub new {
    my ($className, $entityClassName) = @_;
    my $self = $className->SUPER::new();
    $self->{_entityClassName} = $entityClassName;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{_dbh} = IF::DB::dbConnection();
    $self->{_qualifiers} = [];
    $self->{_sth} = undef;
    $self->{_fetchLimit} = 0;
    $self->{_fetchCount} = 0;
    $self->{_startIndex} = 0;
    $self->{_sortOrderings} = [];
    $self->{_prefetchingRelationships} = [];
    $self->{_readAhead} = undef;
    $self->{_isComplete} = 0;
    return $self;
}

sub reset {
    my ($self) = @_;
    $self->{_isComplete} = 0;
    $self->{_sth} = undef;
    $self->{_fs}  = undef;
    $self->{_readAhead} = undef;
    $self->{_fetchCount} = 0;
    return $self;
}

sub limit {
    my ($self, $limit) = @_;
    $self->{_fetchLimit} = $limit;
    return $self->_me();
}

sub offset {
    my ($self, $offset) = @_;
    $self->{_startIndex} = $offset;
    return $self->_me();
}

sub orderBy {
    my ($self, $orderBy) = @_;
    $orderBy = IF::Array->arrayFromObject($orderBy);
    #push @{$self->{_sortOrderings}}, @$orderBy;
    $self->{_sortOrderings} = $orderBy;
    return $self->_me();
}

sub prefetch {
    my ($self, $relationship) = @_;
    $relationship = IF::Array->arrayFromObject($relationship);
    push @{$self->{_prefetchingRelationships}}, @$relationship;
    return $self->_me();
}

sub filter {
    my ($self, $condition, $bindValues) = @_;
    my $q;
    if ($bindValues) {
        $q = IF::Qualifier->key($condition, $bindValues);
    } else {
        $q = IF::Qualifier->key($condition);
    }
    push (@{$self->{_qualifiers}}, $q);
    return $self->_me();
}

sub qualifier {
    my ($self, $q) = @_;
    push (@{$self->{_qualifiers}}, $q);
    return $self->_me();
}

sub fetchSpecification {
    my ($self) = @_;
    my $q = IF::Qualifier->and($self->{_qualifiers});
    my $fs = IF::FetchSpecification->new($self->{_entityClassName}, $q);
    #$fs->setFetchLimit($self->{_fetchLimit});
    $fs->setFetchLimit();
    $fs->setStartIndex($self->{_startIndex});
    $fs->setSortOrderings($self->{_sortOrderings});
    # You can't prefetch if you are using startIndex.
    $fs->setPrefetchingRelationships($self->{_prefetchingRelationships}) unless $self->{_startIndex};
    return $fs;
}

sub _execute {
    my ($self) = @_;
    my $fs = $self->fetchSpecification();
    return unless $fs;
    $self->{_fs} = $fs;
    $self->{_sth} = $self->_statementHandleForSQLExpressionWithBindings($fs->toSQLFromExpression());
}

# This is mostly duplicated from IF::DB; it should
# get folded back in there ultimately.
sub _statementHandleForSQLExpressionWithBindings {
    my ($self, $sqlExpression) = @_;
    my $sql = $sqlExpression->{SQL};

    my $bindValues = $sqlExpression->{BIND_VALUES} || [];
    # In-place filter them to change undefs into empty strings.
    foreach my $bv (@$bindValues) {
        if (!defined($bv)) {
            $bv = '';
        }
    }
    IF::Log::database("[".$sql."]\n with bindings [".join(", ", @{$bindValues})."]\n");
    my $sth = $self->{_dbh}->prepare($sql);
    unless ($sth) {
        IF::Log::error(ref($self)." failed to prepare query: $sql");
        return undef;
    }

    #IF::Log::dump($bindValues);
    if (my $rv = $sth->execute(@$bindValues)) {
        #IF::Log::error("RV: $rv SQL: ".substr($sql, 0, 30));
        return $sth;
    }
    IF::Log::warning("Failed to execute query $sql");
    return undef;
}

sub _close {
    my ($self) = @_;
    if ($self->{_sth}) {
        $self->{_sth}->finish();
    }
    $self->{_isComplete} = 1; # I hate this.
    $self->{_readAhead} = undef;
}

# we could always make this a shallow copier if we want
sub _me {
    my ($self) = @_;
    return $self;
}

sub all {
    my ($self) = @_;
    my $results = [];
    my $result;
    my $c = 0;
    while ($result = $self->next()) {
        push (@$results, $result);
        $c++; # is a shit language
    }
    $self->reset();
    IF::Log::database("Fetched $c results");
    return $results;
}

sub first {
    my ($self) = @_;
    $self->_execute();
    my $result = $self->next();
    $self->_close();
    return $result;
}

sub one {
    my ($self) = @_;
    $self->_execute();
    my $result = $self->next();
    if ($self->{_readAhead}) {
        IF::Log::error("Expected one result, got > 1");
        # yack here?
    }
    return $result;
}

# TODO Should probably optimise this to store the value
# so that it doesn't fire off this query every time count()
# is called.
sub count {
    my ($self) = @_;
    return IF::ObjectContext->new()->countOfEntitiesMatchingFetchSpecification($self->fetchSpecification());
}

sub next {
    my ($self) = @_;
    unless ($self->{_sth}) {
        $self->_execute();
    }
    return unless IF::Log::assert($self->{_sth} && $self->{_fs}, "Statement handle and fetch spec are present");
    my $rows = $self->_readRowsForSingleResult();
    return undef unless ($rows && scalar @$rows > 0);
    my $unpackedResults = $self->{_fs}->unpackResultsIntoEntities($rows);
    IF::Log::assert(scalar @$unpackedResults == 1, "Got one result back");
    $self->{_fetchCount}++;
    if ($self->{_fetchLimit} > 0 && $self->{_fetchCount} >= $self->{_fetchLimit}) {
        #IF::Log::debug("Reached fetch count, closing fetch");
        $self->_close();
    }
    return $unpackedResults->[0];
}

# this gets called once per next() because
# sometimes we need to read multiple rows to retrieve
# a single entity; for example, when prefetching on
# a relationship, or qualifying across a relationship
sub _readRowsForSingleResult {
    my ($self) = @_;
    my $rowBuffer = [];
    # grab a row that we read ahead if there is one
    if ($self->{_readAhead}) {
        push @$rowBuffer, $self->{_readAhead};
        $self->{_readAhead} = undef;
    } else {
        #IF::Log::debug("No readahead, so it's either the beginning or the end");
    }
    my $row;
    # our conditions for exiting the loop are:
    # * we are finished fetching all rows
    # * we fetch a row with a different PK value
    # * there's an error

    # TODO refactor; this can all be done once on _execute()
    my $se = $self->{_fs}->sqlExpression();
    my $defaultTable = $se->{_defaultTable};
    IF::Log::assert($defaultTable, "Using default table");
    my $defaultTableAlias = $se->aliasForTable($defaultTable);
    IF::Log::assert($defaultTableAlias, "Using default table alias");
    my $ecd = $se->entityClassDescriptionForTableWithName($defaultTable);
    IF::Log::assert($ecd, "Using ecd");
    my $pkColumnName = $defaultTableAlias."_".$ecd->_primaryKey();
    my $pkValue;
    if (scalar @$rowBuffer) {
        $pkValue = $rowBuffer->[0]->{$pkColumnName};
        #IF::Log::debug("Using PK value $pkValue from last fetch");
    }
    while ($row = $self->_readRow()) {
        unless ($pkValue) {
            $pkValue = $row->{$pkColumnName};
        }
        my $currentPkValue = $row->{$pkColumnName};

        if ($pkValue ne $currentPkValue) {
            # on exit, if we read a row and it's not processed yet,
            # put it into $self->{_readAhead} for processing
            # next time
            $self->{_readAhead} = $row;
            #IF::Log::debug("Found different pk value $currentPkValue, exiting");
            last;
        }

        #IF::Log::debug("PK value is $currentPkValue for $pkColumnName");
        push @$rowBuffer, $row;
    }

    return $rowBuffer;
}

sub _readRow {
   my ($self) = @_;
   return undef if $self->{_isComplete};
   my $row;
   unless ($row = $self->{_sth}->fetchrow_hashref()) {
       # we're at the end of the fetch so close it out
       $self->_close();
       return undef;
    }
   foreach my $k (keys %$row) {
        $row->{uc $k} = $row->{$k};
        if ($k !~ /^[A-Z0-9_]+$/) {
            delete $row->{$k};
        }
    }
    return $row;
}

1;