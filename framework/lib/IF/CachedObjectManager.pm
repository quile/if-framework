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


package IF::CachedObjectManager;

# This managed cached objects of all types; it's used
# to allow easy invalidation of all caches related to
# a certain object... it's the only way we can
# effectively implement cached objects/pages/components
#
# This essentially operates as a meta-cache that can
# keep track of which objects are stored in which
# caches.  Note that it doesn't do it on its own; you
# have to do it yourself.

use strict;
use IF::Cache;

my $_sharedCache = IF::Cache::cacheOfTypeWithName("Memcached", "CacheManager");

sub registerEntryInCacheWithKeyForObject {
    my ($className, $cache, $key, $object) = @_;
    return unless ($cache && $key && $object);
    my $id = _identifierForObject($object);

    my $entries = _sharedCacheEntryForId($id);
    my $newKey = $cache->type()."/".$cache->name();
    IF::Log::debug("Adding cache reference for $id");
    $entries->{$newKey} = { cacheType  => $cache->type(),
                             cacheName => $cache->name(),
                             cacheKey  => $key
                         };

    _setSharedCacheEntryForId($entries, $id);
}

sub removeAllCacheEntriesForObject {
    my ($className, $object) = @_;
    my $id = _identifierForObject($object);
    my $entries = _sharedCacheEntryForId($id);
    foreach my $hashKey (keys %$entries) {
        my $entry = $entries->{$hashKey};
        my $cache = IF::Cache::cacheOfTypeWithName($entry->{cacheType}, $entry->{cacheName});
        if ($cache) {
            IF::Log::debug("Deleting cache entry for $id from cache $hashKey");
            $cache->deleteCachedValueForKey($entry->{cacheKey});
        }
    }
    _removeSharedCacheEntryForId($id);
}

sub _identifierForObject {
    my $object = shift;
    my $idString;
    if (UNIVERSAL::can($object, "id")) {
        $idString = ref($object)."/".$object->id();
    } else {
        IF::Log::warning("Object $object passed in, but object has no 'id' method");
        $idString = ref($object);
    }

    # here we should hash it, but for now let's keep it plaintext
    return $idString;
}

sub _sharedCacheEntryForId {
    my $id = shift;
    unless ($_sharedCache) {
        IF::Log::warning("No cache manager cache is available");
        return {};
    }
    return $_sharedCache->cachedValueForKey($id) || {};
}

sub _setSharedCacheEntryForId {
    my ($entry, $id) = @_;
    unless ($_sharedCache) {
        IF::Log::warning("No cache manager cache is available");
        return;
    }
    $_sharedCache->setCachedValueForKey($entry, $id);
}

sub _removeSharedCacheEntryForId {
    my $id = shift;
    unless ($_sharedCache) {
        IF::Log::warning("No cache manager cache is available");
        return;
    }
    $_sharedCache->deleteCachedValueForKey($id);
}

1;