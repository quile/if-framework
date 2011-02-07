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

package IFTest::TestStash;

# This test depends on the standard memcached to be
# running according to settings in ACTIVE/IF.conf

use strict;
use base qw(
    Test::Class
);

use Test::More;
use IFTest::Application;

sub setUp : Test(startup => 1) {
    my ($self) = @_;

    # MEMCACHED_PATH => "$FRAMEWORK_ROOT/bin/support/osx/memcached",
    # MEMCACHED_PID => $FRAMEWORK_ROOT.'/logs/memcached.pid',
    # MEMCACHED_SIZE => 32, # MB
    # MEMCACHED_PORT => 9999,
    # MEMCACHED_DEBUG => 1,

    #------------------------------------
    $self->{debug} = 0;
    $self->{port} = IF::Application->systemConfigurationValueForKey("MEMCACHED_PORT") || 11211;
    my $memcachedPath = IF::Application->systemConfigurationValueForKey("MEMCACHED_PATH")
                        || `which memcached` || '/usr/local/bin/memcached';
    chomp $memcachedPath;
    my $memcachedFlags = " -p $self->{port} ";

    IF::Log::setLogMask(0x20);
    if ($self->{debug}) {
    	IF::Log::setLogMask(0xffff);
    	$memcachedFlags .= " -vv ";
    }

    # -------
    use IF::Cache::Memcached;

    diag("Firing up memcached at $memcachedPath on port $self->{port}");
    $self->{pid} = fork();
    if (not defined $self->{pid}) {
    	print "fork failed.\n";
    } elsif ($self->{pid} == 0) {
    	# child
    	exec("$memcachedPath $memcachedFlags")
                           or die "Can’t start memcached: $!";
    	print "Should not get here!\n";
    	exit(0);
    } else {
        ok(1, "forked off memcached process");
    }
}

sub tearDown : Test(shutdown => 1) {
    my ($self) = @_;

	kill 15, $self->{pid};
	waitpid($self->{pid}, 0);
	ok(1, "Memcached shut down");
	diag "Waiting for memcached to shut down";
	sleep(5);
}


# These will all fail if you're not running memcached
# with the settings in IF.conf
sub test_stash : Test(18) {
    my ($self) = @_;

    my $stasher = QA::Stasher->new();
    ok($stasher->isa("IF::Interface::Stash"), "Created an object implementing IF::Interface::Stash");

    ok($stasher->_sharedCache()->isa("IF::Cache::Memcached"), "Stasher is backed by a memcache cache");

    {
    		$stasher->setStashedValueForKey("bar", "foo");
    		ok($stasher->stashedValueForKey("foo") eq "bar", "Set and retrieved a key in the stash");

    		$stasher->deleteStashedValueForKey('foo');
    		ok(! $stasher->stashedValueForKey('foo'), "Deleted entry from stash.");
    }

    {
    		$stasher->setStashedValueForKey({ 'foo' => 'bar', 'bah' => 'pez' }, 'obj');
    		my $rv = $stasher->stashedValueForKey('obj');
    		ok($rv && $rv->{foo} eq 'bar', "Set and retrieved an object in the stash");

    		$stasher->deleteStashedValueForKey('obj');
    		ok(! $stasher->stashedValueForKey('obj'), "Deleted object from stash.");
    }

    {
    		$stasher->setStashedValueForKeyWithTimeout('bar', 'footime', 2);
    		ok($stasher->stashedValueForKey('footime') eq 'bar', "Set and retrieved a key in the stash with timeout");

    		sleep(2);
    		ok(! $stasher->stashedValueForKey('footime'), "Entry expired correctly via timeout.");
    }

    {
    		$stasher->setStashedValueForKeyWithTimeout('bar', 'foolocal');
    		my $internalKey = $stasher->_stashKeyForLocalKey('foolocal');
    		ok(! $stasher->_localCache()->cachedValueForKey($internalKey), "KVP IS NOT in local storage");

    		$stasher->setShouldCacheLocally(1);
    		ok($stasher->stashedValueForKey('foolocal') eq 'bar', "Retrieved a key from the stash with local storage set");
    		my $rv = $stasher->_localCache()->cachedValueForKey($internalKey);
    		ok($rv eq 'bar', "KVP IS now in local storage");
    		$stasher->setShouldCacheLocally(0);
    }

    {
    		$stasher->setShouldCacheLocally(1);
    		$stasher->setStashedValueForKeyWithTimeout('bar', 'foolocal2');
    		ok($stasher->stashedValueForKey('foolocal2') eq 'bar', "Set and retrieved a key in the stash with local storage set");

    		my $internalKey = $stasher->_stashKeyForLocalKey('foolocal2');
    		ok($stasher->_localCache()->cachedValueForKey($internalKey) eq 'bar', "KVP is in local storage");
    		my $rv = $stasher->_sharedCache()->cachedValueForKey($internalKey);
    		ok($rv && $rv->{v} eq 'bar', "KVP is in shared storage");
    		$stasher->setShouldCacheLocally(0);
    }

    {
    		$stasher->setShouldCacheLocally(1);
    		$stasher->setStashedValueForKeyWithTimeout({ 'local' => 'yokel' }, 'foolocalcomplex');
    		my $rv = $stasher->stashedValueForKey('foolocalcomplex');
    		ok($rv && $rv->{'local'} eq 'yokel', "Set and retrieved a complex value in the stash with local storage set");
    		$stasher->setShouldCacheLocally(0);
    }

    {
    		$stasher->setShouldCacheLocally(0);
    		$ENV{'STASH_CACHE_ALL_LOCALLY'} = 1;
    		$stasher->setStashedValueForKeyWithTimeout('bar', 'foolocal3');
    		ok($stasher->stashedValueForKey('foolocal3') eq 'bar', "Set and retrieved a key in the stash with local storage set via ENV");

    		my $internalKey = $stasher->_stashKeyForLocalKey('foolocal3');
    		ok($stasher->_localCache()->cachedValueForKey($internalKey) eq 'bar', "KVP is in local storage");
    		delete $ENV{'STASH_CACHE_ALL_LOCALLY'};
    }


    {
        $stasher->setStashedValueForKeyWithTimeout("foo", "United States", 5);
        ok($stasher->stashedValueForKey("United States") eq "foo", "Coped with a key having whitespace in it");
    }

}


# -------
package QA::Stasher;

use base qw(IF::Interface::Stash);

sub new {
	my $className = shift;
	return bless {}, $className;
}

sub shouldCacheLocally {
	my $self = shift;
	return $self->{_shouldCacheLocally} || $self->SUPER::shouldCacheLocally();
}

sub setShouldCacheLocally {
	my ($self, $value) = @_;
	$self->{_shouldCacheLocally} = $value;
}



1;
