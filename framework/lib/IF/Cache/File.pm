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

package IF::Cache::File;

use strict;
use IF::Cache;
use IF::Interface::Cache;
use File::Basename;
use File::Path qw(mkpath);
use IO::File;
use Time::HiRes qw(usleep);
use Fcntl qw(:flock);
use base qw(IF::Interface::Cache);
# this will hopefully get perl to treat the code/literals
# eval'ed by the do call below to as utf8
use utf8;

my $DEFAULT_CACHE_SIZE = 60; # only store 60 entries
my $CACHE_DIRECTORY = "/tmp/if-cache";
my $DEFAULT_CACHE_FILE_EXTENSION = ".cache";
my $MAX_LOCK_TRIES = 100;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->setCacheSize($DEFAULT_CACHE_SIZE);
    $self->{_cache} = {};
    my $cd = $self->cacheDirectory();
    IF::Log::debug("Initialising file cache in '$cd' with name $self->{NAME}");
    my $error;
    unless (-d $cd) {
        if (system("mkdir -p $cd")) {
            $error = "Couldn't create $cd";
        }
    }
    unless (-d "$cd/$self->{NAME}") {
        mkdir  $cd."/".$self->{NAME} or $error = "Couldn't create $cd/$self->{NAME}";
    }
    return $self unless $error;
    IF::Log::error($error);
    return undef;   # TODO what about $error?
}

sub hasCachedValueForKey {
    my $self = shift;
    my $key = shift;
    return 1 if $self->{_cache}->{$key};
    my $cacheFile = $self->cacheFileForKey($key);
    if (-f $cacheFile) {
        my $value = $self->cachedValueForKey($key); # fault it in
        return 0 unless $value;
        return 1;
    }
    return 0;
}

sub cachedValueForKey {
    my $self = shift;
    my $key = shift;
    my $cacheEntry;
    my $cacheFile = $self->cacheFileForKey($key);
    if (my $lock = $self->getReadLock($cacheFile)) {
        IF::Log::debug("Faulting in $cacheFile");
        $cacheEntry = do "$cacheFile"; # oy vay
        if (! $cacheEntry && $!) {
            IF::Log::warning("File does not exist in file-backed cache for key $key: $!");
            $self->releaseLock($lock);
            return;
        }
        elsif (! $cacheEntry && $@) {
            IF::Log::error("Error loading cached value from file-backed cache for key $key: $@");
            $self->releaseLock($lock);
            return;
        }
        $self->releaseLock($lock);
    }
    if ($cacheEntry) {
        my $now = time;
        unless ($now > ($cacheEntry->{TIMESTAMP} + $cacheEntry->{TIMEOUT})) {
            IF::Log::debug("Cache hit for key $key");
            my $value = $cacheEntry->{VALUE};
            $self->{_cache}->{$key} = {
                TIMEOUT => $cacheEntry->{TIMEOUT},
                TIMESTAMP => $cacheEntry->{TIMESTAMP},
            };
            return $value;
        }
        IF::Log::debug("Stale value found for key $key, expiring");
        $self->deleteCachedValueForKey($key);
    }
    #IF::Log::debug("Cache miss for key $key");
    return;
}

sub setCachedValueForKey {
    my $self = shift;
    return $self->setCachedValueForKeyWithTimeout(@_, $self->cacheTimeout());
}

sub _checkAndCreatePath {
    my $path = shift;
    my $dir = dirname($path);
    unless (-f $dir) {
        #(my $quotedDir = $dir) =~ s/ /\\ /g;
        #system("mkdir -p $quotedDir");
        eval { mkpath($dir); };
        if ($@) {
            IF::Log::error("Failed to create cache directory $dir : $@");
        } else {
            IF::Log::debug("Created cache directory $dir");
        }
    }

}

sub setCachedValueForKeyWithTimeout {
    my $self = shift;
    my $value = shift;
    my $key = shift;
    my $timeout = shift;

    IF::Log::debug("Caching value for key $key");
    my $cacheFile = $self->cacheFileForKey($key);
    if ($key =~ /\// && $key !~ /\.\./) {
        # make sure directory exists for cached value:
        _checkAndCreatePath($cacheFile);
    }
    my $time = time;
    my $cacheRecord = { VALUE => $value, TIMEOUT => $timeout, TIMESTAMP => $time };
    my $data = Data::Dumper->Dump([$cacheRecord], [qw($cacheRecord)]);
    if (my $lock = $self->getWriteLock($cacheFile)) {
        if (open(CACHE, "> $cacheFile")) {
            print CACHE $data;
            close (CACHE);
        } else {
            IF::Log::error("IF::Cache - Error opening $cacheFile for writing: $!");
        }
        $self->releaseLock($lock);
    }
    $self->{_cache}->{$key} = {
        TIMEOUT => $timeout,
        TIMESTAMP => $time,
    };
    return 1;
}

sub allKeys {
    my $self = shift;
    my $cd = $self->cacheDirectory();
    my $prefix = "$cd/$self->{NAME}/";
    open (DIR, "find $prefix -name '*.cache' -print |");
    my @cachedValues = <DIR>;
    close (DIR);
    foreach my $cacheFile (@cachedValues) {
        chomp($cacheFile);
        $cacheFile =~ s/$DEFAULT_CACHE_FILE_EXTENSION$//;
        $cacheFile =~ s/$prefix//;
        $cacheFile =~ s/^\///g;
    }
    return [@cachedValues];
}

sub deleteCachedValueForKey {
    my $self = shift;
    my $key = shift;
    my $cacheFile = $self->cacheFileForKey($key);
    if (my $lock = $self->getWriteLock($cacheFile)) {
        delete $self->{_cache}->{$key};
        unlink $cacheFile;
        $self->releaseLock($lock);
        return 1;
    }
    return;
}

sub cacheFileForKey {
    my $self = shift;
    my $key = shift;
    my $cd = $self->cacheDirectory();
    return $cd."/".$self->{NAME}."/".$key.$DEFAULT_CACHE_FILE_EXTENSION;
}

sub cachedValueForKeyHasExpired {
    my $self = shift;
    my $key = shift;
    my $now = time;
    return 0 unless $self->hasCachedValueForKey($key);
    unless ($self->{_cache}->{$key}) {
        my $value = $self->cachedValueForKey($key); # fault it in
    }
    return 1 if ($self->{_cache}->{$key} &&
                 $now > ($self->{_cache}->{$key}->{TIMESTAMP} + $self->{_cache}->{$key}->{TIMEOUT}));
    return 0;
}

# File locking mechanism:
sub getWriteLock {
    my $self = shift;
    my $cacheFile = shift;
    return $self->_getLock($cacheFile, LOCK_EX);
}

sub getReadLock {
    my $self = shift;
    my $cacheFile = shift;
    return $self->_getLock($cacheFile, LOCK_SH);
}

sub releaseLock {
    my $self = shift;
    my $fh = shift;
    unless ((defined $fh) && (ref($fh) eq "IO::File")) {
        IF::Log::error("IF::Cache - releaseLock called with an invalid file handle");
        return;
    }
    flock($fh,LOCK_UN);
    IF::Log::debug("IF::Cache - Released lock on ".$self->{locks}->{$fh->fileno});
    undef $fh;
    return 1;
}

sub _getLock {
    my $self = shift;
    my $cacheFile = shift;
    my $lockType = shift;
    my $lockFile = $cacheFile.'.lock';
    my $lockTryCount = 0;
    _checkAndCreatePath($lockFile);
    my $fh = new IO::File "> $lockFile";
    unless (defined $fh) {
        IF::Log::error("IF::Cache - can't open $lockFile\n");
        return;
    }
    $self->{locks}->{$fh->fileno} = $cacheFile;
    while (! (flock($fh,$lockType|LOCK_NB) || ($lockTryCount++ >= $MAX_LOCK_TRIES))) {
        usleep(10000);  # 10 ms
    }
    if ($lockTryCount >= $MAX_LOCK_TRIES) {
        IF::Log::error("IF::Cache - can't get a LOCK_EX on $lockFile\n");
        return;
    }

    IF::Log::debug("IF::Cache - Locked file $cacheFile type $lockType");
    return $fh;
}

sub cacheDirectory {
    my $self = shift;
    unless ($self->{_cacheDirectory}) {
        $self->{_cacheDirectory} = IF::Application->systemConfigurationValueForKey("CACHE_DIRECTORY") || $CACHE_DIRECTORY;
    }
    return $self->{_cacheDirectory};
}

1;
