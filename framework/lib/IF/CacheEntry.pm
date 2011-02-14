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

package IF::CacheEntry;

use strict;
use IF::Log;
use base qw(IF::Interface::KeyValueCoding);

sub new {
    my $className = shift;
    return bless {}, $className;
}

sub initWithCacheAndKey {
    my ($self, $cache, $key) = @_;
    $self->setKey($key);
    $self->setCache($cache);
    return $self;
}

sub key {
    my $self = shift;
    return $self->{key};
}

sub setKey {
    my ($self, $value) = @_;
    $self->{key} = $value;
}

sub value {
    my $self = shift;
    return unless (IF::Log::assert($self->cache(), "Cache exists"));
    return unless $self->key();
    return $self->{value} if $self->{value};
    $self->{value} = $self->cache()->cachedValueForKey($self->key());
    return $self->{value};
}

sub setValue {
    my ($self, $value) = @_;
    return unless (IF::Log::assert($self->cache(), "Cache exists"));
    return unless $self->key();
    $self->{value} = $value;
    $self->cache()->setCachedValueForKey($value, $self->key());
}

sub cache {
    my $self = shift;
    return $self->{cache};
}

sub setCache {
    my ($self, $value) = @_;
    $self->{cache} = $value;
}

sub registerObjectDependency {
    my ($self, $object) = @_;
    IF::CachedObjectManager->registerEntryInCacheWithKeyForObject(
        $self->cache(),
        $self->key(),
        $object,
    );
}

1;