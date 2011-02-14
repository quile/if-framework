package IF::DB::SQLite;

use strict;
use base qw(
    IF::Entity::Transient
);

sub do {
    my ($self, $dbh, $sql) = @_;
    # insert statements need to be treated differently
    # because we need to fetch back the rowid of the new
    # row.
    if ($sql =~ /^insert/i) {
        # get the write default - we have to do this
        # so we can get the last insert id back.     
        my $dbh = $dbh->defaultWriteDataSource()->{DBH};
        $dbh->do($sql);
        $self->{_lastInsertId} = $dbh->func('last_insert_rowid');
        return "0E0";
    } else {
        return $dbh->do($sql);
    }
}

sub descriptionOfTable {
    my ($self, $tableName) = @_;
    my $sql = "pragma table_info ($tableName)";
    my $results = [];
    my $dbh = IF::DB::dbConnection();
    my $sth = $dbh->prepare($sql);
    
    $sth->execute();
    if ($dbh->errstr) {
        IF::Log::error($dbh->errstr);
        return [];
    }
    my $columns = [];
    while (my $result = $sth->fetchrow_arrayref()) {
        my ($index, $field, $type, $what, $default, $isPk) = @$result;
        if ($type eq "INTEGER") {
            $type = "INT(11)";
        }
        my $col = {
            FIELD => $field,
            TYPE => $type,
            DEFAULT => $default,
        };
        push @$results, $col;
    }
    return $results;
}

sub lastInsertId {
    my ($self) = @_;
    return $self->{_lastInsertId};
}

sub countUsingSQL {
    my ($self, $sql) = @_;
    my $dbh = IF::DB::dbConnection();
    my $sth = $dbh->prepare($sql->{SQL});
    my $bvs = $sql->{BIND_VALUES} || [];    
    $sth->execute(@$bvs);
    if ($dbh->errstr) {
        IF::Log::error($dbh->errstr);
        return 0;
    }
    my $row = $sth->fetch;
    my $result = $row->[0];
    return [
        { COUNT => $result },
    ];
}


sub nextNumberForSequence {
    my ($self, $sequenceName) = @_;
    
    my $nextId;
    my $dbh = IF::DB::dbConnection();
    return undef unless $dbh;

    my $sequenceTable = IF::Application->systemConfigurationValueForKey("SEQUENCE_TABLE");

    my $fetchStatementHandle = $dbh->prepare("SELECT NEXT_ID FROM $sequenceTable WHERE NAME = ?");
    if ($fetchStatementHandle->execute($sequenceName)) {
        ($nextId) = $fetchStatementHandle->fetchrow_array;
        $fetchStatementHandle->finish();
        unless ($nextId) {
            # insert the sequence
            $dbh->do("INSERT INTO $sequenceTable (NAME, NEXT_ID) VALUES (".$dbh->quote($sequenceName).", 1)");                
            $nextId = 1;
        }
        # update key
        $dbh->do("UPDATE $sequenceTable SET NEXT_ID=NEXT_ID+1 WHERE NAME=" . $dbh->quote($sequenceName));
    }
    return $nextId;    
}

1;