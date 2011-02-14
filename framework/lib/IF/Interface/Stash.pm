package IF::Interface::Stash;

use IF::Cache::Memcached;
use IF::Cache::PerProcess;
use Data::Dumper;

# singleton cache instance for the apache process
my $_sharedCache;
my $_localCache;

# Implementors of this interface should override appropriately
sub stashTimeout {
    my ($self) = @_;
    return 24*3600;
}

# Implementors of stashes for very small and heavily used data sets
# should override and always return true to enable per-process storage of the value
# (examples: asset tags, asset types, language objects)
# Offline scripts like the nightly match may want to set the env variable
# below to force all stashed objects to be stored locally (like the site index
# word objects)
sub shouldCacheLocally {
    return $ENV{'STASH_CACHE_ALL_LOCALLY'};
}

sub stashedValueForKey {
    my ($self, $key) = @_;
    my $value;
    my $stashKey = $self->_stashKeyForLocalKey($key);
    if ($self->shouldCacheLocally()) {
        my $rec = $self->_localCache()->cachedValueForKey($stashKey);
        return $rec if $rec;
    }
    my $rec = $self->_sharedCache()->cachedValueForKey($stashKey);
    if ($rec->{r}) {
        $value = eval($rec->{v});
    } else {
        $value = $rec->{v};
    }
    # This is the case where another process pushed the value into memcache.  
    # We fetch it from there and store it locally. Note that timeout is lost here
    # but the assumption is that locally cached objects are not quickly changing
    # and therefore should have very long ttls.
    if ($self->shouldCacheLocally()) {
        $self->_localCache()->setCachedValueForKeyWithTimeout($value, $stashKey, $self->stashTimeout());
    }
    return $value;
}

sub setStashedValueForKey {
    my ($self, $value, $key) = @_;
    return $self->_setRawStashedValueForKeyWithTimeout($value, $key, $self->stashTimeout());
}

sub setStashedValueForKeyWithTimeout {
    my ($self, $value, $key, $timeout) = @_;
    return $self->_setRawStashedValueForKeyWithTimeout($value, $key, $timeout);
}

sub _setRawStashedValueForKeyWithTimeout {
    my ($self, $value, $key, $timeout) = @_;
    my $rec = { r => 0, v => $value };
    if (ref($value)) {
        $rec->{r} = 1;
        $rec->{v} = Dumper($value);
    }
    $self->_sharedCache()->setCachedValueForKeyWithTimeout($rec, $self->_stashKeyForLocalKey($key), $timeout);
    if ($self->shouldCacheLocally()) {
        $self->_localCache()->setCachedValueForKeyWithTimeout($value, $key, $timeout);
    }
}

sub deleteStashedValueForKey {
    my ($self, $key) = @_;
    $self->_sharedCache()->deleteCachedValueForKey($self->_stashKeyForLocalKey($key));
    $self->_localCache()->deleteCachedValueForKey($self->_stashKeyForLocalKey($key));
}

sub _stashKeyForLocalKey {
    my ($self, $key) = @_;
    my $rv;
    # filter whitespace and unicode chrs
    $key =~ s/[\s\X]/_/g;
    if (ref($self)) {
        $rv = join('', "STASH_", ref($self), "_", $key);
    } else {
        $rv = join('', "STASH_", $self,"_", $key);        
    }
    return $rv;
}

sub _sharedCache {
    return $_sharedCache if $_sharedCache;
    $_sharedCache = IF::Cache::cacheOfTypeWithName('Memcached', 'Component');
    # fallback to local cache if memcache not available
    unless ($_sharedCache) {
        $_sharedCache = IF::Cache::cacheOfTypeWithName('PerProcess', 'Stash');
    }
    return $_sharedCache;
}

sub _localCache {
    return $_localCache if $_localCache;
    $_localCache = IF::Cache::cacheOfTypeWithName('PerProcess', 'Stash');
    return $_localCache;
}

1;