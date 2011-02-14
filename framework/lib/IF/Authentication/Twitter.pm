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

package IF::Authentication::Twitter;

# super rough, just helper methods now.
use strict;
use Net::OAuth;
use Net::OAuth::RequestTokenRequest;
use Net::OAuth::AccessTokenRequest;
use LWP::UserAgent;
use Digest::HMAC_SHA1;
use HTTP::Request::Common;
use JSON;

use base qw(
    IF::Entity::Transient
);

our $REQUEST_TOKEN_URL = "https://twitter.com/oauth/request_token";
our $ACCESS_TOKEN_URL  = "https://twitter.com/oauth/access_token";
our $AUTHORIZE_URL     = "https://twitter.com/oauth/authorize";
our $AUTHENTICATE_URL  = "https://twitter.com/oauth/authenticate";
our $RESOURCE_URL      = "https://twitter.com/account/verify_credentials.json";

$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;

sub initWithApplication {
    my ($self, $application) = @_;
    $self->setApplication($application);
    return $self;
}

# gets the consumer key from here
sub application    { return $_[0]->{application}  }
sub setApplication { $_[0]->{application} = $_[1] }
sub consumerKey    { return $_[0]->{consumerKey}  }
sub setConsumerKey { $_[0]->{consumerKey} = $_[1] }
sub consumerSecret    { return $_[0]->{consumerSecret}  }
sub setConsumerSecret { $_[0]->{consumerSecret} = $_[1] }
sub callback    { return $_[0]->{callback}  }
sub setCallback { $_[0]->{callback} = $_[1] }
sub accessKey    { return $_[0]->{accessKey}  }
sub setAccessKey { $_[0]->{accessKey} = $_[1] }
sub accessSecret    { return $_[0]->{accessSecret}  }
sub setAccessSecret { $_[0]->{accessSecret} = $_[1] }

sub defaults {
    my ($self) = @_;
    my $app = $self->application();
    my $consumerKey    = $self->consumerKey() || $app->configurationValueForKey("TWITTER_CONSUMER_KEY");
    my $consumerSecret = $self->consumerSecret() || $app->configurationValueForKey("TWITTER_CONSUMER_SECRET");
    my $nonce = int(rand(65535)); # huh?

    return {
        consumer_key => $consumerKey,
        consumer_secret => $consumerSecret,
        signature_method => 'HMAC-SHA1',
        timestamp => CORE::time,
        nonce => $nonce,
    }
}

sub requestTokenAndSecret {
    my ($self) = @_;

    my $ua = LWP::UserAgent->new;
    my $request = Net::OAuth->request("request token")->new(
        %{$self->defaults()},
        request_url => $REQUEST_TOKEN_URL,
        request_method => 'POST',
        callback => $self->callback(),
    );
    $request->sign;
    my $res = $ua->request(POST $request->to_url); # Post message to the Service Provider

    if ($res->is_success) {
        my $response = Net::OAuth->response('request token')->from_post_body($res->content);
        return ($response->token, $response->token_secret);
    }
    return undef;
}

sub accessTokenAndSecret {
    my ($self, $requestToken, $requestSecret, $verifier) = @_;

    my $ua = LWP::UserAgent->new;
    my $request = Net::OAuth->request("access token")->new(
        %{$self->defaults()},
        request_url => $ACCESS_TOKEN_URL,
        request_method => 'GET',
        token => $requestToken,
        token_secret => $requestSecret,
        callback_confirmed => "true",
        verifier => $verifier,
    );

    $request->sign;
    my $res = $ua->request(GET $request->to_url); # Post message to the Service Provider

    if ($res->is_success) {
        my $response = Net::OAuth->response('access token')->from_post_body($res->content);
        my $token = $response->token;
        my $secret = $response->token_secret;
        return ($token, $secret);
    }
    return undef;
}

sub userInfoFromTwitter {
    my ($self, $accessToken, $accessSecret) = @_;
    my $request = Net::OAuth->request("protected resource")->new(
        %{$self->defaults()},
        request_method => "GET",
        request_url => $RESOURCE_URL,
        token => $accessToken,
        token_secret => $accessSecret,
    );
    $request->sign();

    my $ua = LWP::UserAgent->new;
    my $res = $ua->request(GET($request->request_url, Authorization => $request->to_authorization_header));

    if (!$res->is_success) {
        die 'Could not get feed: ' . $res->status_line . ' ' . $res->content;
    }
    return from_json($res->decoded_content);
}

sub authenticationUrl {
    my ($className, $token) = @_;
    return $AUTHENTICATE_URL."?oauth_token=$token";
}

1;