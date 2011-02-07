package IF::DB::MySQL;

use strict;
use base qw(
    IF::Entity::Transient
);

sub do {
    my ($self, $dbh, $sql) = @_;
    return $dbh->do($sql);
}

sub descriptionOfTable {
    my ($self, $tableName) = @_;
    my $sql = "SHOW COLUMNS FROM ".$tableName;
    my $results = [];
    ($results, undef) = IF::DB::rawRowsForSQL($sql);
    return $results;
}

sub lastInsertId {
    my ($self) = @_;
    my $dbh = IF::DB::dbConnection();
    return $dbh->dbiHandleForDataSourceWithID($dbh->lastUsedDataSource())->{'mysql_insertid'};
}

sub countUsingSQL {
    my ($self, $sql) = @_;
    return IF::DB::rawRowsForSQLWithBindings($sql);
}

sub nextNumberForSequence {
    my ($self, $sequenceName) = @_;
    
	my $nextId;
	my $dbh = IF::DB::dbConnection();
	return undef unless $dbh;

	my $sequenceTable = IF::Application->systemConfigurationValueForKey("SEQUENCE_TABLE");
    my $sth = $dbh->prepare("LOCK TABLES $sequenceTable WRITE");
    
    if ($sth->execute()) {
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
			$dbh->do("UNLOCK TABLES");
		}
		$sth->finish();  	
	}
	return $nextId;    
}

1;