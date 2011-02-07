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

package IF::Cache::Failover;

# TODO
# This is scarily rough; ideally it should have a list of caches and
# iterate over them until one of them responds.  The fastest and most
# efficient cache is always first.  If that fails, it should
# gracefully fail to the next one, etc. without the consumer
# ever knowing.
# The problem right now is that the caches that fail need to throw
# exceptions back to this one, so it knows they're not available
# any more.

use strict;
use vars qw(@ISA);
use IF::Cache;
use base 'IF::Interface::Cache';

# Hack HARDCODE WARNING TODO TODO
my $DEFAULT_CACHE_TIMEOUT = 3600;


sub init {
	my $self = shift;
	$self->SUPER::init(@_);
	$self->{_caches} = [
		IF::Cache::cacheOfTypeWithName("Memcached", $self->name()),
		IF::Cache::cacheOfTypeWithName("File",      $self->name()),   #... any others?
		];
	return $self;
}

sub hasCachedValueForKey {
	my ($self, $key) = @_;
	foreach my $c (@{$self->{_caches}}) {
		next unless $c;
		return $c->hasCachedValueForKey($key);
	}
}

sub cachedValueForKey {
	my ($self, $key) = @_;

	foreach my $c (@{$self->{_caches}}) {
		next unless $c;
		IF::Log::debug("Getting cache value for key $key from cache $c");
		my $cv = $c->cachedValueForKey($key);
		return $cv if $cv;
	}
	return;
}

# how inefficient is it to cache values in all available caches?

sub setCachedValueForKey {
	my ($self, $value, $key) = @_;
	foreach my $c (@{$self->{_caches}}) {
		next unless $c;
		IF::Log::debug("Setting cache value for key $key in cache $c");
		last if $c->setCachedValueForKey($value, $key);
	}
	return;
}

sub setCachedValueForKeyWithTimeout {
	my ($self, $value, $key, $timeout) = @_;
	foreach my $c (@{$self->{_caches}}) {
		next unless $c;
		IF::Log::debug("Setting cache value for key $key in cache $c with timeout $timeout");
		last if $c->setCachedValueForKeyWithTimeout($value, $key, $timeout);
	}
}

sub allKeys {
	my ($self) = @_;
	foreach my $c (@{$self->{_caches}}) {
		next unless $c;
		return $c->allKeys();
	}
	return;
}

# TODO needs to know if parent throws
sub cachedValueForKeyHasExpired {
	my ($self, $key) = @_;
	foreach my $c (@{$self->{_caches}}) {
		next unless $c;
		return $c->cachedValueForKeyHasExpired($key);
	}
	return;
}

# delete it from all caches
sub deleteCachedValueForKey {
	my ($self, $key) = @_;
	foreach my $c (@{$self->{_caches}}) {
		next unless $c;
		$c->deleteCachedValueForKey($key);
	}
	return;
}

sub setCacheTimeout {
	my ($self, $timeout) = @_;
	foreach my $c (@{$self->{_caches}}) {
		next unless $c;
		$c->setCacheTimeout($timeout);
	}
	$self->{cacheTimeout} = $timeout;
}

1;