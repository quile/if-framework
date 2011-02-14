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

package IF::DB;

use strict;
use IF::Array;
use IF::Application;
use IF::MultipleDataSourceAdaptor;
use IF::DB::MySQL;
use IF::DB::SQLite;
#====================================
use IF::Config;
#====================================

# Static DB handle:

my $_connectionDictionary = {};
our $_dbh;

sub updateRecordInDatabase {
    my $context = shift;
    my $record = shift;
    my $table = shift;
    my $when = shift;
    my $sql;

    my $dbh = dbConnection();
    return undef unless $dbh;

    my $id = _valueForPrimaryKeyInRecord($record);

    # This is very lame and bug-prone: FIX! HACK
    if ($id) {
        # already has a primary key so
        # we're updating it in the db

        $sql = buildUpdateStatementForRecordInTable($record, $table, $dbh);
    } else {
        $sql = buildInsertStatementForRecordInTable($record, $table, $dbh, $when);
    }
    IF::Log::database("$sql\n");

    # execute it and grab the insert id if it's available
    #my $rows = $dbh->do($sql);
    my $rows = _driver()->do($dbh, $sql);

    unless ($rows) {
        IF::Log::error($dbh->errstr." : ".$sql);
    }

    unless ($id) {
        $id = _driver()->lastInsertId();
        #$id = $dbh->dbiHandleForDataSourceWithID($dbh->lastUsedDataSource())->{'mysql_insertid'};
        _setValueForPrimaryKeyInRecord($id, $record);
        IF::Log::debug("Inserted new record with ID $id\n");
    }
}

sub buildInsertStatementForRecordInTable {
    my $record = shift;
    my $table = shift;
    my $dbh = shift;
    my $when = shift;

    my $statement;

#    if ($when eq "DELAYED") {
#        $statement = "INSERT DELAYED INTO $table ";
#    } else {
        $statement = "INSERT INTO $table ";
#    }

    my @keys;
    my @values;

    # mark the creation time (although can't MYSQL do this?)
    $record->{CREATION_DATE} ||= IF::Date::Unix->new(time);
    $record->{MODIFICATION_DATE} ||= IF::Date::Unix->new(time);

    # lame
    my $dm = IF::Model->defaultModel();
    my $ecd;
    if ($dm) {
        $ecd = $dm->entityClassDescriptionForTable($table);
    }
    foreach my $key (keys %$record) {
        next if ($key eq "ID");
        next if ($key =~ /^_/);
        next unless defined $record->{$key};
        push (@keys, '`'.$key.'`');
        my $value = $record->{$key};
        if (ref($value) eq "IF::Date::Unix" && $ecd) {
            my $attribute = $ecd->attributeWithName($key);
            my $at = uc($attribute->{TYPE});
            if ($at eq "DATETIME" || $at eq "TIMESTAMP") {
                $value = $value->sqlDateTime();
            } elsif ($at eq "INT") {
                $value = $value->utc();
            }
        }
        push (@values, $dbh->quote($value));
    }
    $statement .= "(".join(", ", @keys).") values (".join(", ", @values).")";
    return $statement;
}

sub buildUpdateStatementForRecordInTable {
    my $record = shift;
    my $table = shift;
    my $dbh = shift;

    my $statement = "UPDATE $table SET ";
    my $id = _valueForPrimaryKeyInRecord($record);
    $record->{MODIFICATION_DATE} = IF::Date::Unix->new(CORE::time());
    my @keyValuePairs = ();
    # lame
    my $dm = IF::Model->defaultModel();
    my $ecd;
    if ($dm) {
        $ecd = $dm->entityClassDescriptionForTable($table);
    }
    foreach my $key (keys %$record) {
        next if ($key eq "ID");
        next if ($key =~ /^_/);

        my $value;
        # check for multi-valued records
        my @multiValues = split("\0", $record->{$key});
        if (scalar @multiValues != 1) {
            $value = join("\t", @multiValues);
        } else {
            $value = $record->{$key};
        }

        if (ref($value) eq "IF::Date::Unix" && $ecd) {
            my $attribute = $ecd->attributeWithName($key);
            my $at = uc($attribute->{TYPE});
            if ($at eq "DATETIME" || $at eq "TIMESTAMP") {
                $value = $value->sqlDateTime();
            } elsif ($at eq "INT") {
                $value = $value->utc();
            }
        }

        push (@keyValuePairs, '`'.$key.'`'."=". $dbh->quote($value));
    }
    $statement .= join(", ", @keyValuePairs);
    $statement .= " WHERE ID=".$id;

    return $statement;
}

sub buildDeleteStatementForRecordWithPrimaryKeyInTable {
    my $id = shift;
    my $table = shift;
    my $sql = "DELETE FROM $table WHERE ID=$id";
    return $sql;
}

sub deleteRecordInDatabase {
    my $context = shift;
    my $record = shift;
    my $table = shift;

    my $pk = _valueForPrimaryKeyInRecord($record);
    if ($pk) {
        my $sql = buildDeleteStatementForRecordWithPrimaryKeyInTable(
                            $pk, $table);
        IF::Log::database("$sql\n");
        my $dbh = dbConnection();
        return undef unless $dbh;
        my $rows = $dbh->do($sql);
        IF::Log::database("$rows row(s) deleted.");
    }
}

sub rawRowsForSQL {
    my $sql = shift;
    my $dbh = shift || dbConnection();
    return undef unless $dbh;

    IF::Log::database($sql."\n");
    my @resultset;
    my $sth = $dbh->prepare($sql);
    do {
        IF::Log::error("IF::DB::rawRowsForSQL failed to prepare query: $sql");
        return undef;
    } unless $sth;

    if ($sth->execute()) {
        while (my $row = $sth->fetchrow_hashref()) {
            foreach my $k (keys %$row) {
                $row->{uc $k} = $row->{$k};
                if ($k !~ /^[A-Z0-9_]+$/) {
                    delete $row->{$k};
                }
            }
            push (@resultset, $row);
        }
        $sth->finish();
    } else {
        IF::Log::error($dbh->errstr." : ".$sql);
    }
    IF::Log::database("Fetched ".scalar(@resultset)." row(s)\n");
    return (\@resultset, $dbh);
}

sub rawRowsForSQLWithBindings {
    my $sqlExpression = shift;
    my $dbh = shift || dbConnection();
    return undef unless $dbh;

    my $sql = $sqlExpression->{SQL};
    #IF::Log::dump($sqlExpression);
    my $bindValues = $sqlExpression->{BIND_VALUES} || [];
    # In-place filter them to change undefs into empty strings.
    foreach my $bv (@$bindValues) {
        if (!defined($bv)) {
            $bv = '';
        }
    }
    IF::Log::database("[".$sql."]\n with bindings [".join(", ", @{$bindValues})."]\n");
    my @resultset;
    my $sth = $dbh->prepare($sql);
    unless ($sth) {
        IF::Log::error("IF::DB::rawRowsForSQLWithBindings failed to prepare query: $sql");
        return undef;
    }

    if (my $rv = $sth->execute(@$bindValues)) {
        #IF::Log::error("RV: $rv SQL: ".substr($sql, 0, 30));
        #if ($rv > 0) {
            if ($sql =~ /^DELETE/ || $sql =~ /^INSERT/ || $sql =~ /^UPDATE/) {
                # wtf to do here?
                return [];
            }
            while (my $row = $sth->fetchrow_hashref()) {
                foreach my $k (keys %$row) {
                    $row->{uc $k} = $row->{$k};
                    if ($k !~ /^[A-Z0-9_]+$/) {
                        delete $row->{$k};
                    }
                }
                push (@resultset, $row);
            }
        #} else {
        #    IF::Log::debug("Zero rows affected");
        #}
        $sth->finish();
    } else {
        my $trace = IF::Log->getStackTrace();
        IF::Log::error($sth->errstr." : $sql \n".join("\n",@$trace)."\n");
    }
    IF::Log::database("Fetched ".scalar(@resultset)." row(s)\n");
    return \@resultset;
}

sub executeArbitrarySQL {
    my $sql = shift;
    my $dbh = shift || dbConnection();
    return undef unless $dbh;

    IF::Log::database("$sql\n");
    return unless ($dbh);
    my $rows = $dbh->do($sql);
    IF::Log::database("$rows rows affected");
    return $rows; # isn't this the right thing to do here?
}

my $_driver;
sub _driver {
    return $_driver if $_driver;
    my $writeDefaultName = $_connectionDictionary->{DATA_SOURCE_CONFIG}->{WRITE_DEFAULT};
    my $writeDefault = $_connectionDictionary->{DATA_SOURCES}->{$writeDefaultName};
    if ($writeDefault && $writeDefault->{dbString}) {
        if ($writeDefault->{dbString} =~ /SQLite/) {
            $_driver = IF::DB::SQLite->new();
        }
    }
    $_driver ||= IF::DB::MySQL->new();
    return $_driver;
}

sub dbConnection {
    if ($_dbh and $_dbh->ping()) {
        return $_dbh;
    } else {
        $_dbh = IF::MultipleDataSourceAdaptor->connect($_connectionDictionary->{DATA_SOURCES},
                            $_connectionDictionary->{DATA_SOURCE_CONFIG});
        die "Database connection failed, ".DBI::errstr() unless ($_dbh);
        # my $writeDefaultName = $_connectionDictionary->{DATA_SOURCE_CONFIG}->{WRITE_DEFAULT};
        # my $writeDefault = $_connectionDictionary->{DATA_SOURCES}->{$writeDefaultName};
        # if ($writeDefault && $writeDefault->{dbString}) {
        #     if ($writeDefault->{dbString} =~ /SQLite/) {
        #         $_driver = IF::DB::SQLite->new();
        #     }
        # }
        # $_driver ||= IF::DB::MySQL->new();
    }
    return $_dbh;
}

sub releaseConnection {
    $_dbh = undef;
}

sub setDatabaseInformation {
    my $dataSources = shift;
    my $dataSourceConfig = shift;

    if ($_connectionDictionary->{DATA_SOURCES}) {
        IF::Log::warning("Overwriting existing connection dictionary information");
    }
    $_connectionDictionary = {
        DATA_SOURCES => $dataSources,
        DATA_SOURCE_CONFIG => $dataSourceConfig,
    };
}

sub nextNumberForSequence {
    my $sequenceName = shift;
    return _driver()->nextNumberForSequence($sequenceName);
}

sub tables {
    my $dbhCached = dbConnection();
    return undef unless $dbhCached;

    my ($rows, $dbh) = rawRowsForSQL("SHOW TABLES");
    my $tables = [];

    foreach my $row (@$rows) {
        foreach my $key (%$row) {
            next unless $row->{$key};
            push (@$tables, $row->{$key});
        }
    };
    return $tables;
}

sub quote {
    my $string = shift;
    my $dbh = dbConnection();
    return undef unless $dbh;

    return $string unless $dbh;
    return $dbh->quote($string);
}

sub descriptionOfTable {
    my ($tableName) = @_;
    # my $_driver = _driver();
    # unless ($_driver) {
    #     dbConnection();
    #     $_driver = _driver();
    # }
    return _driver()->descriptionOfTable($tableName);
}

# HACK: figure out the pk field of
# a record - only using this until
# we come up with a better way
# to do it.

sub _valueForPrimaryKeyInRecord {
    my ($record) = @_;

    if (UNIVERSAL::isa($record, "IF::Entity::Persistent")) {
        my $ecd = $record->entityClassDescription();
        if ($ecd) {
            my $pk = $ecd->_primaryKey();
            if ($pk) {
                return $pk->valueForEntity($record);
            }
        }
    }

    return $record->{ID} || $record->{id}; # YIKES
}

sub _setValueForPrimaryKeyInRecord {
    my ($value, $record) = @_;

    if (UNIVERSAL::isa($record, "IF::Entity::Persistent")) {
        my $ecd = $record->entityClassDescription();
        if ($ecd) {
            my $pk = $ecd->_primaryKey();
            if ($pk) {
                $pk->setValueForEntity($value, $record);
            }
        }
    }

    $record->{ID} = $value; # YIKES; fall-back position
}


1;
