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

package IF::Cache;

use strict;
use IF::Interface::Cache;
use IF::Log;
use IF::Cache::File;
use IF::Cache::Memcached;
use IF::Cache::Failover;


my %cache = ();

sub refreshAllCacheHandles {
    %cache = ();
    IF::Cache::Memcached->refreshAllCacheHandles();
}

sub cacheOfTypeWithName {
    my $type = shift;
    my $name = shift;

    if ($cache{$type} && $cache{$type}->{$name}) {
        IF::Log::debug("Using existing cache $name for $type");
        return $cache{$type}->{$name};
    }

    unless ($cache{$type}) {
        $cache{$type} = {};
    }

    my $cacheClass = "IF::Cache::$type";
    my $newCache = eval { $cacheClass->new($name) };
    if ($newCache && !$@) {
        $newCache->init();
        IF::Log::debug("Created cache object $newCache with name $name");
        $cache{$type}->{$name} = $newCache;
        return $newCache;
    } else {
        IF::Log::error("Couldn't create cache of type $type: $@");
        return;
    }
}

sub bestAvailableCacheWithName {
    my $name = shift;
    my $optimalCacheList = ["Failover", "Memcached", "File"];
    foreach my $optimalCacheType (@$optimalCacheList) {
        my $cache = cacheOfTypeWithName($optimalCacheType, $name);
        return $cache if $cache;
    }
    return;
}

1;