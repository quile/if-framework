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

package IF::Cache::SharedMemory;

use strict;
use IF::Cache;
use IPC::Shareable;
use base qw(IF::Interface::Cache);

my $DEFAULT_CACHE_SIZE = 60; # only store 60 entries
my $DEFAULT_CACHE_TIMEOUT = 3600;
my %OPTIONS = (
	create => 'yes',
	exclusive => 0,
	mode => 0644,
	destroy => 'yes', # careful with this
	size => 64 * 1024, #
);
my %CACHE;
my $_cachedKeys = {};

sub init {
	my $self = shift;
	$self->setCacheSize($DEFAULT_CACHE_SIZE);
	$self->setCacheTimeout($DEFAULT_CACHE_TIMEOUT);
	unless ($self->{NAME}) {
		IF::Log::error("Cannot connect to un-named cache");
		return;
	}
	IF::Log::debug("Initialising shared memory cache with glue '$self->{NAME}'");
	tie %CACHE, 'IPC::Shareable', $self->{NAME}, { %OPTIONS } or IF::Log::error("Failed to connect to shared memory cache named $self->{NAME}");
	return $self;
}

sub hasCachedValueForKey {
	my $self = shift;
	my $key = shift;
	return 1 if $_cachedKeys->{$key};
	if ($CACHE{$key}) {
		$_cachedKeys->{$key} = 1;
		return 1;
	}
	return 0;
}

sub cachedValueForKey {
	my $self = shift;
	my $key = shift;
	my $cacheEntry = $CACHE{$key};
	return unless $cacheEntry;
	if ($self-> cachedValueForKeyHasExpired($key)) {
		IF::Log::warning("Accessing stale value for key $key");
	}
	$_cachedKeys->{$key} = 1;
	return $cacheEntry->{VALUE};
}

sub setCachedValueForKey {
	my $self = shift;
	return $self->setCachedValueForKeyWithTimeout(@_, $self->cacheTimeout());
}

sub setCachedValueForKeyWithTimeout {
	my $self = shift;
	my $value = shift;
	my $key = shift;
	my $timeout = shift;
	IF::Log::debug("Setting cache value for key $key");
	$CACHE{$key} = { VALUE => $value, TIMEOUT => $timeout, TIMESTAMP => time };
	$_cachedKeys->{$key} = 1;
}

sub allKeys {
	my $self = shift;
	return [keys %CACHE];
}

sub deleteCachedValueForKey {
	my $self = shift;
	my $key = shift;
	delete $CACHE{$key};
	delete $_cachedKeys->{$key};
}

sub cachedValueForKeyHasExpired {
	my $self = shift;
	my $key = shift;
	my $cacheEntry = $CACHE{$key};
	return 1 unless $cacheEntry;
	my $time = time;
	if ($time - $cacheEntry->{TIMEOUT} > $cacheEntry->{TIMESTAMP}) {
		IF::Log::debug("Cache entry for $key has expired");
		return 1;
	}
	return 0;
}

1;