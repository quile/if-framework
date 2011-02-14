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

package IF::MultipleDataSourceAdaptor;

#
# Mimics DBI's calling conventions of a DBI handle while transparently
# routing queries to one of several configured actual DBI handles
# based on configured options.
#
#  SW
#  Feb 8-10, 2005

## private package wrapper for sth's in mode where we detect
##  lock / prepare pitfalls

use strict;
use DBI;
use IF::Log;
use Storable qw(dclone);
use Data::Dumper;

# I would prefer these to be constants, but they don't
#   interpolate into regex's correctly :(
our $Q_READ = 0;
our $Q_WRITE = 1;
our $Q_LOCK = 2;
our $Q_UNLOCK = 3;

our $STRICT_CHECKING=1;        # anal mode
our $WRITE_TO_READ_ONLY_IS_FATAL=1;

our $DEFAULT_COUPLED_THRESHOLD=0;

sub connect {
    my $classname = shift;
    my $dsns = shift;
    my $config = shift;
    my $dsn_count = scalar keys(%$dsns);

   ($dsns and UNIVERSAL::isa($dsns, "HASH")) or
                        die "connect: first arg is not a hashref";
   ($config and UNIVERSAL::isa($config, "HASH")) or
                        die "connect: second arg is not a hashref";

    my $self = bless {
        _COUPLED_THRESHOLD => $DEFAULT_COUPLED_THRESHOLD,

    }, $classname;

    # make the dbi connections
     foreach my $dsn_id (keys %$dsns) {
        my $dsn = $dsns->{$dsn_id};
        my $dbh = DBI->connect($dsn->{dbString},$dsn->{dbUsername},$dsn->{dbPassword},$dsn->{dbArgs} || {}) or
                    die "connect: Failed to connected db handle $dsn_id: $DBI::errstr";
        # copy the flags hashref to use for the basis of the handle hash

        $self->{_DB_HANDLES}->{$dsn_id} = ($dsn->{flags} ? dclone($dsn->{flags}) : {});;
        my $dsn_entry = $self->{_DB_HANDLES}->{$dsn_id};
        $dsn_entry->{DBH} = $dbh;
        $dsn_entry->{ID} = $dsn_id;
    }

    $self->setDefaultWriteDataSource($self->_chooseDefaultDataSource('WRITE_DEFAULT',
                    $config->{'WRITE_DEFAULT'}, 'READ_ONLY'));
    $self->setDefaultReadDataSource($self->_chooseDefaultDataSource('READ_DEFAULT',
                    $config->{'READ_DEFAULT'}, 'WRITE_ONLY'));
    if (not $config->{'LOCK_DEFAULT'}) {
        $self->setDefaultLockDataSource($self->defaultWriteDataSource());
    } else {
        $self->setDefaultLockDataSource($self->_chooseDefaultDataSource('LOCK_DEFAULT',
                    $config->{'LOCK_DEFAULT'}, 'READ_ONLY'));
    }

    # fallback pairs
    #if ($config->{'FALLBACK_PAIRS'}) {
    #    foreach my $pair (@$config->{'FALLBACK_PAIRS'}) {
    #        $self->{_DB_HANDLES}->{$pair->[0]}->{'FALLBACK'} = $pair->[1];
    #    }
    #}

    # coupled query monitoring setup.
    #  if the config var MONITOR_FOR_COUPLED_QUERIES is set, we monitor
    #  those (disable with []), otherwise we choose all the writeable
    #  sources


    if (exists $config->{MONITOR_FOR_COUPLED_QUERIES}) {
        $self->setDataSourcesToMonitorForCoupledQueries(
                $config->{MONITOR_FOR_COUPLED_QUERIES});
    } else {
        $self->setDataSourcesToMonitorForCoupledQueries(
                $self->_getWriteableDataSources());
    }


    return  $self;
}

sub do {
    my $self = shift;
    my $query = shift;

    my $dbh = $self->_chooseSourceForQuery($query)->{DBH};
    return $dbh->do($query, @_);
}

sub selectall_arrayref {
    my $self = shift;
    my $query = shift;

    my $dbh = $self->_chooseSourceForQuery($query)->{DBH};
    return $dbh->selectall_arrayref($query, @_);
}

sub selectall_hashref {
    my $self = shift;
    my $query = shift;

    my $dbh = $self->_chooseSourceForQuery($query)->{DBH};
    return $dbh->selectall_hashref($query, @_);
}

sub selectcol_arrayref {
    my $self = shift;
    my $query = shift;

    my $dbh = $self->_chooseSourceForQuery($query)->{DBH};
    return $dbh->selectcol_arrayref($query, @_);
}

# check return v
sub selectrow_array {
    my $self = shift;
    my $query = shift;

    my $dbh = $self->_chooseSourceForQuery($query)->{DBH};
    return ($dbh->selectrow_array($query, @_));
}

sub selectrow_arrayref {
    my $self = shift;
    my $query = shift;

    my $dbh = $self->_chooseSourceForQuery($query)->{DBH};
    return $dbh->selectrow_arrayref($query, @_);
}

sub selectrow_hashref {
    my $self = shift;
    my $query = shift;

    my $dbh = $self->_chooseSourceForQuery($query)->{DBH};
    return $dbh->selectrow_hashref($query, @_);
}

sub prepare {
    my $self = shift;
    my $query = shift;

    my $dbh = $self->_chooseSourceForQuery($query)->{DBH};
    return $dbh->prepare($query, @_);
}

sub prepare_cached {
    my $self = shift;
    my $query = shift;

    my $dbh = $self->_chooseSourceForQuery($query)->{DBH};
    return $dbh->prepare_cached($query, @_);
}

sub begin_work {
    my $self = shift;

    # for our purposes, beginning a transaction is equivalent to beginning a locked
    # block ...
    my $src = $self->_chooseSourceForQuery("LOCK");
    $self->_setLockedToDataSource($src);
    IF::Log::database("Transaction begin");
    return $src->{DBH}->begin_work();
}

sub commit {
    my $self = shift;

    # for our purposes, commiting a transaction is equivalent to ending a locked
    # block ...
    my $src = $self->_chooseSourceForQuery("UNLOCK");
    $self->_setLockedToDataSource();
    IF::Log::database("Transaction commit");
    return $src->{DBH}->commit();
}

sub rollback {
    my $self = shift;

    my $rc = $self->_lockedToDataSource()->rollback();
    $self->_setLockedToDataSource();
    IF::Log::database("Transaction rolled back");
    return $rc;
}

sub quote {
    my $self = shift;
    # don't care about the choice of handle
    return $self->{_READ_DEF_SRC}->{DBH}->quote(@_);
}

sub err {
    my $self = shift;
    return $self->{_LAST_SRC_CHOSEN}->{DBH}->err();
}

sub errstr {
    my $self = shift;
    return $self->{_LAST_SRC_CHOSEN}->{DBH}->errstr();
}

sub state {
    my $self = shift;
    return $self->{_LAST_SRC_CHOSEN}->{DBH}->begin_query();
}

sub disconnect {
    my $self = shift;
    foreach my $src_id (keys %{$self->{_DB_HANDLES}}) {
        $self->{_DB_HANDLES}->{$src_id}->{DBH}->disconnect();
        delete $self->{_DB_HANDLES}->{$src_id};
    }
    return 1;
}

# currently this ors together the result of pinging all the
#  data sources.

sub ping {
    my $self = shift;
    my $livecount = 0;
    foreach my $id (keys %{$self->{_DB_HANDLES}}) {
        $livecount += $self->{_DB_HANDLES}->{$id}->{DBH}->ping();
    }
    if ($livecount == scalar keys %{$self->{_DB_HANDLES}}) {
        return 1;
    } else {
        return undef;
    }
}

# source specified versions of above
# SRC_ID is always first argument

sub doUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    $self->_checkQueryTypeIsValid($_[0], $src_id) if $STRICT_CHECKING;

    return $dbh->do(@_);
}

sub selectall_arrayrefUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    $self->_checkQueryTypeIsValid($_[0], $src_id) if $STRICT_CHECKING;

    return $dbh->selectall_arrayref(@_);
}

sub selectall_hashrefUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    $self->_checkQueryTypeIsValid($_[0], $src_id) if $STRICT_CHECKING;

    return $dbh->selectall_hashref(@_);
}

sub selectcol_arrayrefUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    $self->_checkQueryTypeIsValid($_[0], $src_id) if $STRICT_CHECKING;

    return $dbh->selectcol_arrayref(@_);
}

sub selectrow_arrayUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    $self->_checkQueryTypeIsValid($_[0], $src_id) if $STRICT_CHECKING;

    return ($dbh->selectrow_array(@_));
}

sub selectrow_arrayrefUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    $self->_checkQueryTypeIsValid($_[0], $src_id) if $STRICT_CHECKING;

    return $dbh->selectrow_arrayref(@_);
}

sub selectrow_hashrefUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    $self->_checkQueryTypeIsValid($_[0], $src_id) if $STRICT_CHECKING;

    return $dbh->selectrow_hashref(@_);
}

sub prepareUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    $self->_checkQueryTypeIsValid($_[0], $src_id) if $STRICT_CHECKING;

    return $dbh->prepare(@_);
}

sub prepare_cachedUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    $self->_checkQueryTypeIsValid($_[0], $src_id) if $STRICT_CHECKING;

    return $dbh->prepare_cached(@_);
}

sub begin_workUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";

    return $dbh->begin_work();
}

sub commitUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";

    return $dbh->commit();
}

sub rollbackUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";

    return $dbh->rollback();
}

sub errUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    return $dbh->err();
}

sub errstrUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    return $dbh->errstr();
}

sub stateUsingDataSource {
    my $self = shift;
    my $src_id = shift;

    my $dbh = $self->{_DB_HANDLES}->{$src_id}->{DBH} or
                    die "Data Source $src_id does not exist";
    return $dbh->state();
}

# useful for eg. ->mysql_insertid()

sub lastUsedDataSource  {
    my $self = shift;

    return $self->{_LAST_SRC_CHOSEN}->{ID};
}

sub dbiHandleForDataSourceWithID {
    my $self = shift;
    my $id = shift;

    return $self->{_DB_HANDLES}->{$id}->{DBH};
}

sub runMethodOnDataSourceHandle {
    my $self = shift;
    my $methodName = shift;
    my $sourceID = shift;

    return $self->{_DB_HANDLES}->{$sourceID}->{DBH}->$methodName(@_);
}

# instrospection

sub defaultWriteDataSource {
    my ($self) = @_;
    return $self->{_WRITE_DEF_SRC};
}

sub defaultWriteDataSourceId {
    my $self = shift;
    return $self->{_WRITE_DEF_SRC}->{ID};
}

sub setDefaultWriteDataSource {
    my $self = shift;
    my $src = shift;
    $self->{_WRITE_DEF_SRC} = $src;
}

sub defaultReadDataSource {
    my ($self) = @_;
    return $self->{_READ_DEF_SRC};
}

sub defaultReadDataSourceId {
    my $self = shift;
    return $self->{_READ_DEF_SRC}->{ID};
}

sub setDefaultReadDataSource {
    my $self = shift;
    my $src = shift;
    $self->{_READ_DEF_SRC} = $src;
}

sub defaultLockDataSource {
    my ($self) = @_;
    return $self->{_LOCK_DEF_SRC};
}

sub defaultLockDataSourceId {
    my $self = shift;
    return $self->{_LOCK_DEF_SRC}->{ID};
}

sub setDefaultLockDataSource {
    my $self = shift;
    my $src = shift;
    $self->{_LOCK_DEF_SRC} = $src;
}

# config

sub setDataSourcesToMonitorForCoupledQueries {
    my $self = shift;
    my $list = shift;

    while (my ($dsrc_id,$dsrc) = each %{$self->{_DB_HANDLES}}) {
        foreach (@$list) {
            $dsrc->{MONITOR_COUPLED} = ($_ eq $dsrc_id ? 1 : undef);
        }
    }
}

sub dataSourcesToMonitorForCoupledQueries {
    my $self = shift;
    my $list = [];

    while (my ($dsrc,$dsrc_id) = each %{$self->{_DB_HANDLES}}) {
        push @$list, $dsrc_id if $dsrc->{MONITOR_COUPLED};
    }
    return $list;
}

sub setTimeThresholdForCoupledQueries {
    my $self = shift;
    my $thresh = shift;

    die "bad time threshold argument" unless $thresh > 0;
    $self->{_COUPLED_THRESHOLD} = $thresh;
}

sub timeThresholdForCoupledQueries {
    my $self = shift;
    return $self->{_COUPLED_THRESHOLD};
}

# For external use, to lock handle to a particular db connection
# for a long time.
sub setLockedToDataSourceWithId {
    my ($self, $srcId) = @_;
    $self->{_IS_EXTERNALLY_LOCKED} = ($srcId ? 1 : undef);
     $self->{_LOCKED_TO_SRC} = $self->_sourceWithId($srcId);
}

sub lockedToDataSourceId {
    my ($self) = @_;
    return $self->_lockedToDataSource()->{ID} if $self->{_IS_EXTERNALLY_LOCKED};
}

# conveniences
sub setLockedToDefaultWriteDataSource {
    my ($self) = @_;
    $self->setLockedToDataSourceWithId($self->defaultWriteDataSourceId());
}

sub releaseDataSourceLock {
    my ($self) = @_;
    $self->setLockedToDataSourceWithId();
}

# internal

# For internal use, within a series of queries involving locks
# or transaction this gets toggled as necessary.
sub _setLockedToDataSource {
    my ($self, $src) = @_;
     $self->{_LOCKED_TO_SRC} = $src unless $self->{_IS_EXTERNALLY_LOCKED};
}

sub _lockedToDataSource {
    my ($self) = @_;
    return $self->{_LOCKED_TO_SRC};
}

sub _chooseSourceForQuery {
    my $self = shift;
    my $query = shift;
    my $selected_src;

    my $query_type = _classifyQuery($query);
    my $src;
    SWITCH: for ($query_type) {
        /$Q_READ/    && do {     $src = ($self->_lockedToDataSource()
                                        ? $self->_lockedToDataSource()
                                        : $self->defaultReadDataSource() );
                                    if (my $diverted_src_id = $self->_checkCoupledTimers($src)) {
                                        my $diverted_src = $self->{_DB_HANDLES}->{$diverted_src_id};
                                        IF::Log::debug("Coupled query diverted from ".
                                                     "$src->{ID} to $diverted_src->{ID} (".
                                                      substr($query,0,50)."...)");
                                        $src = $diverted_src;
                                    }
                                    last SWITCH;
                                };
        /$Q_WRITE/    && do {     $src = ($self->_lockedToDataSource()
                                        ? $self->_lockedToDataSource()
                                        : $self->defaultWriteDataSource() );
                                     if ( exists $src->{MONITOR_COUPLED} ) {
                                            $self->{_TIMERS}->{$src->{ID}} =
                                                        time() + $self->{_COUPLED_THRESHOLD};
                                     }
                                    last SWITCH;
                                };
        /$Q_LOCK/    && do { $src = $self->defaultLockDataSource();
                                    $self->_setLockedToDataSource($src); last SWITCH; };
        /$Q_UNLOCK/    && do { $src = $self->defaultLockDataSource();
                                    $self->_setLockedToDataSource(); last SWITCH; };
    }
    die "_chooseSourceForQuery came back with an empty handle" unless $src;
    IF::Log::database("Query sent to ".$src->{ID});

    $self->{_LAST_SRC_CHOSEN} = $src;
    return $src;
}

sub _checkCoupledTimers {
    my $self = shift;
    my $found_current_timers = [];

    return unless $self->{_TIMERS};
    foreach my $dsrc_id (keys %{$self->{_TIMERS}}) {
        if (time() > $self->{_TIMERS}->{$dsrc_id}) {
            delete $self->{_TIMERS}->{$dsrc_id};
        } else {
            push @$found_current_timers, $dsrc_id;
        }
    }
    delete $self->{_TIMERS} unless values %{$self->{_TIMERS}};

    if (@$found_current_timers > 1) {
        die "Multiple coupled timers found: ".join(' ',@$found_current_timers);
    }
    return $found_current_timers->[0];
}

sub _chooseDefaultDataSource {
    my $self = shift;
    my $name = shift;                   # ie. WRITE_DEFAULT
    my $config_v = shift;
    my $flag_disqualifies = shift;  # ie. READ_ONLY disqualifies a handle as write def
    my $choice;

    if (not $config_v) {
        my $count=0;
        foreach my $dsh_id (keys %{$self->{_DB_HANDLES}}) {
            my $dsh = $self->{_DB_HANDLES}->{$dsh_id};
            if (not $dsh->{$flag_disqualifies}) {
                $choice = $dsh;
                $count++;
            }
        }
        if (! $count) { die "connect: no data sources eligible as $name"; }
        if ($count > 1) {
            die "connect: source for $name is ambigious";
        }
    } else {
        $choice = $self->{_DB_HANDLES}->{$config_v};
        if (not $choice) {
            die "connect: $name handle $config_v does not exist";
        }
    }
    return $choice;
}

sub _classifyQuery {
    my $query = shift;
    my $type = 0;

    SWITCH: for ($query) {
                    $type = $Q_READ,   last SWITCH if /^SELECT/i;
                    $type = $Q_LOCK,   last SWITCH if /^LOCK/i;
                    $type = $Q_UNLOCK, last SWITCH if /^UNLOCK/i;
                    # anything else is considered write
                    $type = $Q_WRITE;
    }
    return $type;
}

sub _checkQueryTypeIsValid {
    my $self = shift;
    my $query = shift;
    my $src_id = shift;

    my $type = _classifyQuery($query);
    my $dsrc = $self->{_DB_HANDLES}->{$src_id};

    if ($dsrc->{READ_ONLY} && $type != $Q_READ) {
        if ($WRITE_TO_READ_ONLY_IS_FATAL) {
            die "Write query sent to read only database";
        } else {
            IF::Log::warning("Write query sent to read only database");
        }
    }

    if ($dsrc->{WRITE_ONLY} && $type == $Q_READ) {
        IF::Log::warning("Read query sent to write only db: $query");
    }

    return 1;
}

# util stuff
sub _sourceWithId {
    my ($self, $srcId) = @_;
    return $self->{_DB_HANDLES}->{$srcId};
}

sub _getWriteableDataSources {
    my $self = shift;
    my $list = [];

    foreach my $dsrc (values %{$self->{_DB_HANDLES}}) {
        push @$list, $dsrc->{ID} if not $dsrc->{READ_ONLY};
    }

    return $list;
}

1;

