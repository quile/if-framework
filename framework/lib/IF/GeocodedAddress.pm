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

package IF::GeocodedAddress;

# NOTE: You must comply with Google's TOS in order to use this!
# If you want to use Geocoded addresses in your application,
# you just need to create an entity class in your Entity folder
# and make sure you add your subclass to your model.

# To bootstrap the table, the definition is:
# DROP TABLE IF EXISTS `GEOCODED_ADDRESS`;
# SET @saved_cs_client     = @@character_set_client;
# SET character_set_client = utf8;
# CREATE TABLE `GEOCODED_ADDRESS` (
#   `ID` int(11) NOT NULL auto_increment,
#   `CREATION_DATE` int(11) NOT NULL default '0',
#   `MODIFICATION_DATE` int(11) NOT NULL default '0',
#   `ADD1` varchar(60) NOT NULL default '',
#   `ADD2` varchar(60) NOT NULL default '',
#   `CITY` varchar(30) NOT NULL default '',
#   `STATE` varchar(30) NOT NULL default '',
#   `COUNTRY` varchar(60) NOT NULL default '',
#   `ZIP` varchar(12) character set latin1 NOT NULL default '',
#   `RAW_DATA` text NOT NULL,
#   `LONGITUDE` double NOT NULL default '0',
#   `LATITUDE` double NOT NULL default '0',
#   PRIMARY KEY  (`ID`),
# ) ENGINE=MyISAM AUTO_INCREMENT=586544 DEFAULT CHARSET=utf8;
# SET character_set_client = @saved_cs_client;

use strict;
use base qw(
    IF::Entity::Persistent
);

use LWP::UserAgent;
use JSON;

my $GOOGLE_GEOCODER_BASE_URL = "http://maps.google.com/maps/geo";

# +++++++ class ++++++
sub instanceFromObject {
    my ($className, $object) = @_;

    my $new = $className->new();

    return $new unless $object;
    my $ecd = $object->entityClassDescription();

    my $fields = {
        add1    => "add1",
        add2    => "add2",
        city    => "city",
        state   => "state",
        country => "country",
    };

    if ($ecd && $ecd->hasGeographicData()) {
        $fields->{add1}    = $ecd->geographicAddress1NameKey();
        $fields->{add2}    = $ecd->geographicAddress2NameKey();
        $fields->{city}    = $ecd->geographicCityNameKey();
        $fields->{state}   = $ecd->geographicStateNameKey();
        $fields->{country} = $ecd->geographicCountryNameKey();
    }

    foreach my $f (keys %$fields) {
        my $objectKey = $fields->{$f};
        $new->setValueForKey($object->valueForKey($objectKey), $f);
    }

    # some special snooping required for items that don't
    # have add1 & add2... this could be optimised!

    if (!$ecd->geographicAddress1NameKey() &&
        !$ecd->geographicAddress2NameKey()) {

        my $owner = $object->valueForKey("assetOwner");
        if ($owner && !$owner->is($object)) {
            # we have an owner that is not this (which could result in
            # a rather nasty infinite loop!)s, and no add1/add2 info, so fish for it in
            # the owner's record:

            my $oecd = $owner->entityClassDescription();
            my $add1 = $owner->valueForKey($oecd->geographicAddress1NameKey());
            my $add2 = $owner->valueForKey($oecd->geographicAddress2NameKey());
            my $city    = $owner->valueForKey($oecd->geographicCityNameKey());
            my $state   = $owner->valueForKey($oecd->geographicStateNameKey());
            my $country = $owner->valueForKey($oecd->geographicCountryNameKey());

            if ( ($add1 || $add2)
                && $city    eq $new->city()
                && $state   eq $new->state()
                && $country eq $new->country()
                ) {
                # the city/state/country are the same as this listing,
                # and there's an address, so let's use it
                $new->setAdd1($add1);
                $new->setAdd2($add2);
            }
        }
    }

    # check for an existing geocoded address for that data
    my $fs = IF::FetchSpecification->new("GeocodedAddress",
                IF::Qualifier->and([
                    IF::Qualifier->key("add1 = %@", $new->add1()),
                    IF::Qualifier->key("add2 = %@", $new->add2()),
                    IF::Qualifier->key("city = %@", $new->city()),
                    IF::Qualifier->key("state = %@", $new->state()),
                    IF::Qualifier->key("country = %@", $new->country()),
                ]));
    my $match = IF::ObjectContext->new()->entityMatchingFetchSpecification($fs);
    return $match if $match;
    # if we don't find one in the db, populate it from google
    $new->populateFromGoogleGeocoder();
    return $new;
}


# ---------- instance ---------

sub populateFromGoogleGeocoder {
    my ($self) = @_;

    # using the info we have in $self, we build a query and
    # fire it off to google. Then we fill the object with data from google

    my $url = $self->googleGeocoderUrl();
    #IF::Log::debug("Sending URL to google: $url");

    my $ua = LWP::UserAgent->new();
    $ua->agent("IF Framework __VERSION__");
    $ua->timeout(10); # if google doesn't respond in 10 seconds, give up.
    my $request = HTTP::Request->new(GET => $url);
    my $response = $ua->request($request);

    if ($response->is_success()) {
        my $content = $response->content();
        $self->setRawData($content);
        #IF::Log::debug("Google returned this: ".$content);

        # extract goop from it
        my $parsedData = eval { IF::Dictionary->new(from_json($content)); };
        if ($parsedData) {
            $self->setParsedData($parsedData);
            #IF::Log::debug("Google returned a code of " . $parsedData->valueForKey("Status.code"));

            # kinda bogus b/c we only suck data from the first
            # placemark... there could be more than one, apparently.
            # TODO suck it from the placemark that has the highest
            # level of accuracy
            my $coordinates = $parsedData->valueForKey('Placemark.@0.Point.coordinates');
            $self->setLatitude($coordinates->[1]);
            $self->setLongitude($coordinates->[0]);
        } else {
            IF::Log::error("Unable to parse geocoder response: $@");
        }
    } else {
        IF::Log::error("Google returned an error response: ". $response->content());
    }
}

sub isValid {
    my ($self) = @_;
    return 1 if ($self->latitude() && $self->longitude());
    return 0;
}

sub googleGeocoderUrl {
    my ($self) = @_;
    my $url = $GOOGLE_GEOCODER_BASE_URL . "?"
            . IF::Utility::stringFromQueryDictionary( {
                q => $self->addressStringAsGoogleQuery(),
                key => IF::Application->defaultApplication()->configurationValueForKey("GOOGLE_MAPS_KEY"),
                output => "json",
            });
    return $url;
}

sub addressString {
    my ($self) = @_;

    my $address = [];
    foreach my $key (qw(add1 add2 city state country)) {
        my $v = $self->valueForKey($key);
        next unless $v;
        push (@$address, $v);
    }
    return join(", ", @$address);
}

# Don't geocode the address 2 as google doesn't like it
sub addressStringAsGoogleQuery {
    my ($self) = @_;
    my $address = [];
    foreach my $key (qw(add1 city state country)) {
        my $v = $self->valueForKey($key);
        next unless $v;
        # Addresses were coming in address 1 with the address 2 info
        $v =~ s/,.*$//;
        push (@$address, $v);
    }
    return join(", ", @$address);
}


sub parsedData {
    my ($self) = @_;
    unless ($self->{parsedData}) {
        $self->{parsedData} = IF::Dictionary->new(from_json($self->rawData()));
    }
    return $self->{parsedData};
}

sub setParsedData {
    my ($self, $value) = @_;
    $self->{parsedData} = $value;
}

sub parsedDataValueForKeyPath {
    my ($self, $keypath) = @_;
    return $self->parsedData()->valueForKey($keypath);
}



# ----- low-level wiring

sub add1    { return $_[0]->storedValueForKey("add1") }
sub setAdd1 { $_[0]->setStoredValueForKey($_[1], "add1") }
sub add2    { return $_[0]->storedValueForKey("add2") }
sub setAdd2 { $_[0]->setStoredValueForKey($_[1], "add2") }
sub city    { return $_[0]->storedValueForKey("city") }
sub setCity { $_[0]->setStoredValueForKey($_[1], "city") }
sub state    { return $_[0]->storedValueForKey("state") }
sub setState { $_[0]->setStoredValueForKey($_[1], "state") }
sub zip      { return $_[0]->storedValueForKey("zip") }
sub setZip   { $_[0]->setStoredValueForKey($_[1], "zip") }
sub country      { return $_[0]->storedValueForKey("country") }
sub setCountry   { $_[0]->setStoredValueForKey($_[1], "country") }
sub rawData      { return $_[0]->storedValueForKey("rawData") }
sub setRawData   { $_[0]->setStoredValueForKey($_[1], "rawData") }
sub latitude     { return $_[0]->storedValueForKey("latitude") }
sub setLatitude  { $_[0]->setStoredValueForKey($_[1], "latitude") }
sub longitude    { return $_[0]->storedValueForKey("longitude") }
sub setLongitude { $_[0]->setStoredValueForKey($_[1], "longitude") }

1;