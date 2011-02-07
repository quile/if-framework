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

package IF::Authentication::RPX;

# super rough, just helper methods now.
use strict;
use LWP::UserAgent;
use JSON;

use base qw(
    IF::Entity::Transient
);

our $AUTH_INFO_URL  = "https://rpxnow.com/api/v2/auth_info";
our $MAP_USER_URL   = "https://rpxnow.com/api/v2/map";
our $UNMAP_USER_URL = "https://rpxnow.com/api/v2/unmap";

sub initWithApplication {
    my ($self, $application) = @_;
    $self->setApplication($application);
    return $self;
}

# gets the consumer key from here
sub application    { return $_[0]->{application}  }
sub setApplication { $_[0]->{application} = $_[1] }

sub rpxApiKey    {
    my ($self) = @_;
    return $self->application()->configurationValueForKey("RPX_API_KEY");
}

# TODO - refactor all these calls to use one transport agent!
sub authInfo {
    my ($self, $token) = @_;

    my $ua = LWP::UserAgent->new();

    my $utoken = IF::Utility::uriEscapedStringFromString($token);
    my $uapiKey = IF::Utility::uriEscapedStringFromString($self->rpxApiKey());

    my $url = $AUTH_INFO_URL;
    IF::Log::debug("Posting to auth URL $url, token $utoken, api key $uapiKey");

    my $res = $ua->post($url, {
        token => $utoken,
        apiKey => $uapiKey,
    });

    if ($res->is_success) {
        my $response = $res->content;
        IF::Log::dump($response);
        return from_json($response);
    } else {
        IF::Log::debug($res->status_line);
    }
    return undef;
}

sub mapUser {
    my ($self, $user) = @_;

    return unless IF::Log::assert($user && $user->id() && $user->rpxIdentifier(), "User has id, identifier");

    my $ua = LWP::UserAgent->new();
    my $uapiKey = IF::Utility::uriEscapedStringFromString($self->rpxApiKey());

    my $url = $MAP_USER_URL;
    IF::Log::debug("Posting to map URL $url, api key $uapiKey, identifier ".$user->rpxIdentifier()." id ".$user->id());

    my $res = $ua->post($url, {
        identifier => $user->rpxIdentifier(),
        primaryKey => $user->id(),
        apiKey => $uapiKey,
    });

    if ($res->is_success) {
        my $response = $res->content;
        IF::Log::dump($response);
        return from_json($response);
    } else {
        IF::Log::debug($res->status_line);
    }
    return undef;
}

sub unmapUser {
    my ($self, $user) = @_;

    return unless IF::Log::assert($user && $user->id() && $user->rpxIdentifier(), "User has id, identifier");

    my $ua = LWP::UserAgent->new();
    my $uapiKey = IF::Utility::uriEscapedStringFromString($self->rpxApiKey());

    my $url = $UNMAP_USER_URL;
    IF::Log::debug("Posting to unmap URL $url, api key $uapiKey, identifier ".$user->rpxIdentifier()." id ".$user->id());

    my $res = $ua->post($url, {
        identifier => $user->rpxIdentifier(),
        primaryKey => $user->id(),
        apiKey => $uapiKey,
    });

    if ($res->is_success) {
        my $response = $res->content;
        IF::Log::dump($response);
        return from_json($response);
    } else {
        IF::Log::debug($res->status_line);
    }
    return undef;
}

1;