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

package IF::Cache::Memcached;

use strict;
use Memcached::libmemcached;
use Time::HiRes qw(usleep);
use base qw(IF::Interface::Cache);
#use Encode ();
use Storable ();
use Compress::Zlib qw(compress uncompress);
use Data::Dumper qw(Dumper);

my $caches = {};

if ($ENV{'MOD_PERL'}) {
	_preload();
}

my $STORABLE_FLAG = 1;
my $COMPRESS_FLAG = 2;

# above 200k compress the value
my $COMPRESSION_THRESHOLD = 200000;

# ====== class =======

sub _preload {
	my $config = IF::Application->systemConfigurationValueForKey("MEMCACHED_SERVERS") || {};
	foreach my $server (keys %$config) {
		_memcachedWithName($server);
	}
}

sub refreshAllCacheHandles {
    $caches = {};
}

sub sanityCheckMode {
	my $self = shift;
	return $self->{_sanity_check};
}

sub setSanityCheckMode {
	my ($self, $value) = @_;
	$self->{_sanity_check} = $value;
}

# used in production - tied to config files
sub _memcachedWithName {
	my $name = shift;
	my $mc = $caches->{$name};

	if ($mc) {
#		unless (ping($memcached)) {
#			IF::Log::warning("MemCached does not appear to be running for $name.");
#		} else {
#			return $memcached;
#		}
		return $mc;
	}
	my $configs = IF::Application->systemConfigurationValueForKey("MEMCACHED_SERVERS");
	my $thisConfig = $configs->{$name};
	unless ($thisConfig) {
		IF::Log::error("No config found for memcached named $name.  Add it to your IF::Config.");
		return;
	}
	$mc = Memcached::libmemcached->memcached_create();
	for my $server (@$thisConfig) {
		# parts[0] = hostname, parts[1] = port
 		# 127.0.0.1:9999
		my @parts = split(':', $server);
		unless ($mc->memcached_server_add( $parts[0], $parts[1] )) {
			IF::Log::error("Error adding memcached server $server: ".$mc->errstr());
		}
	}
	#unless (ping($memcached)) {
	#	IF::Log::warning("MemCached does not appear to be running for $name.");
	#	return undef;
	#}
	$caches->{$name} = $mc;
	IF::Log::debug("Returning cached named $name");
	return $mc;
}

# used in testing - completely programmatic
sub instanceForIpAndPort {
	my ($className, $ip, $port, $debug) = @_;
	my $memcached = Memcached::libmemcached->memcached_create();
	$memcached->memcached_server_add($ip,$port);
	# not sure about the values for this param
	$memcached->memcached_verbosity(9) if $debug;
	my $mc = $className->new();
	$mc->_setMemcached($memcached);
	$mc->init();
	return $mc;
}

sub ping {
	my $memcached = shift;
	my $pingString = "zugzug";
	$memcached->memcached_set("ping", $pingString);
	my $test = $memcached->memcached_get("ping");
	unless ($test eq $pingString) {
		return 0;
	}
	return 1;
}

# ======== instance ========

sub init {
	my $self = shift;
	$self->SUPER::init(@_);
	$self->_setMemcached(_memcachedWithName($self->name())) unless $self->{_memcached};
	return $self;
}

sub hasCachedValueForKey {
	my ($self, $key) = @_;
	return 1;   # this is bogus but better to assume it's cached than not
}

# Because decode_utf8 can't operate on complex data
# structure, we encode/decode a dumper output when
# storing / retrieving anything that's a reference.
#
# The dumper output is wrapped in an array ref so that
# we know to eval it again on the way out.

sub cachedValueForKey {
	my ($self, $key) = @_;
	my $m = $self->_memcached();
	return unless $m;

	my ($rc, $flags);
	my $value = $m->memcached_get($key, $flags, $rc);
	if (! defined $value) {
	    if ($m->errstr() eq 'NOT FOUND') {
    		IF::Log::debug("IF::Cache::Memcached::cachedValueForKey not found (".$m->errstr().") for: $key");
    	} else {
    		IF::Log::error("IF::Cache::Memcached::cachedValueForKey failed (".$m->errstr().") for: $key");
    	}
	}
	elsif (! $value) {
		# defined but false means that null value is stored in memcache
    }
    else {
    	#IF::Log::debug("cached value for key: $key (flags: $flags)");

    	if ($flags & $COMPRESS_FLAG) {
    		$value = uncompress($value);
    	}
    	if ($flags & $STORABLE_FLAG) {
    		$value = Storable::thaw($value);
    	} else {
    		$value = Encode::decode_utf8($value);
    	}
    	# This is a bit redundant, but ensure that we return undef
    	# rather than other false values like []
    	if (! $value) {
    	    return;
    	}
    }
	return $value;
}

sub cachedValuesForKeys {
	my ($self, $keys) = @_;
	my $m = $self->_memcached();
	return {} unless $m;
	my $result = {};
	my $rv = $m->mget_into_hashref($keys, $result);
	if (! $rv) {
        if ($m->errstr() eq 'SOME ERRORS WERE REPORTED') {
    		IF::Log::error("IF::Cache::Memcached::cachedValuesForKeys some errors reported (".$m->errstr().") for: $keys ".
							"got back values for: ".join(",", keys %$result));
    	} else {
    		IF::Log::error("IF::Cache::Memcached::cachedValuesForKeys failed (".$m->errstr().") for: $keys");
    	}
	}
	return $result;
}

sub setCachedValueForKey {
	my $self = shift;
	return $self->setCachedValueForKeyWithTimeout(@_, $self->cacheTimeout());
}

sub setCachedValueForKeyWithTimeout {
	my ($self, $value, $key, $timeout) = @_;
	my $m = $self->_memcached();
	return unless $m;

	my $original_value = $value;
	my $rv;
	my $flags;
	if (ref($value)) {
		$value = Storable::freeze($value);
		$flags = $STORABLE_FLAG;
		#IF::Log::debug("Storing: $value");
	} else {
		$value = Encode::encode_utf8($value);
	}
	if (length($value) > $COMPRESSION_THRESHOLD) {
		$value = compress($value);
		$flags += $COMPRESS_FLAG;
	}

	$rv = $m->memcached_set($key, $value, $timeout, $flags);
	if (! $rv) {
		IF::Log::error("Cache::Memcached::setCachedValueForKeyWithTimeout failed for $key: ".$m->errstr().", flags: $flags, length: ".length($value));
	} elsif ($self->sanityCheckMode()) {
		my $retrieved_value = $self->cachedValueForKey($key);
		if (not defined $retrieved_value) {
			IF::Log::error("Cache::Memcached::setCachedValueForKeyWithTimeout SANITY CHECK FAILED! [$key] ".
				"No error reported on writing, but not found on read.");
		} else {
			if (ref($original_value) == ref($retrieved_value)) {
				if (ref($original_value)) {
					my $orig = Dumper($original_value);
					my $back = Dumper($retrieved_value);
					if ($orig ne $back) {
						IF::Log::error("Cache::Memcached::setCachedValueForKeyWithTimeout SANITY CHECK FAILED! [$key] ".
							"data structures differ.");
							IF::Log::error("Cache::Memcached::setCachedValueForKeyWithTimeout original: ".$orig);
							IF::Log::error("Cache::Memcached::setCachedValueForKeyWithTimeout retrieved: ".$back);
					}
				} else {
					if (length($retrieved_value) != length($original_value)) {
						IF::Log::error("Cache::Memcached::setCachedValueForKeyWithTimeout SANITY CHECK FAILED! [$key] original len: ".
							length($original_value)." retrieved len: ".length($retrieved_value));
						IF::Log::error("Cache::Memcached::setCachedValueForKeyWithTimeout original: ".$original_value);
						IF::Log::error("Cache::Memcached::setCachedValueForKeyWithTimeout retrieved: ".$retrieved_value);
					}
				}
			} else {
				IF::Log::error("Cache::Memcached::setCachedValueForKeyWithTimeout SANITY CHECK FAILED! [$key] ".
				"Ref types don't match: orig ".ref($original_value)." back ".ref($original_value));
			}
		}
	}
	return $rv;
}

sub allKeys {
	my $self = shift;
	return [];
}

sub deleteCachedValueForKey {
	my ($self, $key) = @_;
	my $m = $self->_memcached();
	return unless $m;
	$m->memcached_delete($key);
	return 1;
}

sub cachedValueForKeyHasExpired {
	my ($self, $key) = @_;
	return 0;
}

sub _memcached {
	my $self = shift;
	unless ($self->{_memcached}) {
		IF::Log::warning("Memcached did not instantiate!  Server is probably not running!");
	}
	return $self->{_memcached};
}

sub _setMemcached {
	my ($self, $value) = @_;
	$self->{_memcached} = $value;
}

sub _flush {
	my ($self) = @_;
	return $self->_memcached()->memcached_flush();
}

sub _stats {
	my ($self) = @_;
	return $self->_memcached()->memcached_stats();
}

1;
