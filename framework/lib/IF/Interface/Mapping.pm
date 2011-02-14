package IF::Interface::Mapping;

use strict;

# TODO remove any of the goopy Asset stuff
# Override where appropriate
sub mappingTitle {
    my ($self) = @_;
    return $self->valueForKey("assetName") || $self->valueForKey("name");
}

sub mappingDescription {
    my ($self) = @_;
    return $self->valueForKey("description") || $self->valueForKey("mission");
}

sub mappingViewerUrl {
    my ($self, $context) = @_;
    if (UNIVERSAL::can($self, "assetExternalViewerUrl")) {
        return $self->assetExternalViewerUrl($context);
    }
    return $self->valueForKey("assetExternalViewerUrl");
}

sub mappingAddressKeys {
    my ($self) = @_;
    return [ qw( add1 add2 city state country ) ];
}

sub mappingAddress {
    my ($self, $context) = @_;

    my $keys = $self->mappingAddressKeys();
    my $address = [];
    foreach my $key (@$keys) {
        my $v = $self->valueForKey($key);
        next unless $v;
        push (@$address, $v);
    }
    return join(", ", @$address);
}

# you could override these if you think you know better...
sub mappingLatitude {
    my ($self) = @_;
    if ($self->valueForKey("geocodedAddressId")) {
        return $self->valueForKey("geocodedAddress.latitude");
    }
    if ($self->valueForKey("geographicCityId")) {
        return $self->valueForKey("geographicCity.latitude");
    }
    return undef;
}

sub mappingLongitude {
    my ($self) = @_;
    if ($self->valueForKey("geocodedAddressId")) {
        return $self->valueForKey("geocodedAddress.longitude");
    }
    if ($self->valueForKey("geographicCityId")) {
        return $self->valueForKey("geographicCity.longitude");
    }
    return undef;    
}

sub mappingAssetType {
    my ($self) = @_;
    return $self->valueForKey("assetType");
}

1;
