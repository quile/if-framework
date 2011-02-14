package IF::Interface::Cache;

# This is also part interface/ part category
use strict;

# This should come from the config:
my $DEFAULT_CACHE_TIMEOUT = 600;

sub new {
    my $className = shift;
    my $name = shift;
    my $self = bless { NAME => $name }, $className;
    return $self;
}
sub init {
    my $self = shift;
    $self->setCacheTimeout($DEFAULT_CACHE_TIMEOUT);
}

sub cachedValueForKey {}
sub cacheEntryForKey {
    my ($self, $key) = @_;
    # TODO: fix this bogusness.  If it's called repeatedly,
    # it will repeatedly create instances, which could
    # conceivably leak
    my $cacheEntry = IF::CacheEntry->new()->initWithCacheAndKey($self, $key);
    return $cacheEntry;
}
sub setCachedValueForKey {}
sub setCachedValueForKeyWithTimeout {}
sub allKeys {}
sub cachedValueForKeyHasExpired {}
sub deleteCachedValueForKey {}

sub expireCachedValues {
    my $self = shift;
    foreach my $key (@{$self->allKeys()}) {
        if ($self->cachedValueForKeyHasExpired($key)) {
            IF::Log::debug("Expiring cached value for key $key");
            $self->deleteCachedValueForKey($key);
        }
    }
}

sub cacheSize {
    my $self = shift;
    return $self->{cacheSize};
}

sub setCacheSize {
    my $self = shift;
    $self->{cacheSize} = shift;
}

sub cacheTimeout {
    my $self = shift;
    return $self->{cacheTimeout};
}

sub setCacheTimeout {
    my $self = shift;
    $self->{cacheTimeout} = shift;
}

sub invalidateAllObjects {
    my $self = shift;
    foreach my $key (@{$self->allKeys()}) {
        $self->deleteCachedValueForKey($key);
    }
}

sub name {
    my $self = shift;
    return $self->{NAME};
}

sub type {
    my $self = shift;
    my $type = ref($self);
    $type =~ s/.*:://o;
    return $type;
}

1;