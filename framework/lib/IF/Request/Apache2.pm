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

package IF::Request::Apache2;

use strict;
use base qw(Apache2::Request IF::Request);
use Apache2::Cookie;
use Apache2::Upload;
use APR::Const -compile => qw(SUCCESS);
use Apache2::Const qw(:common);

# Apache::Request does some funky stuff with it's
# constructor necessitating this.
# See perldoc Apache::Request for details
sub new {
	my($classname, @args) = @_;
	my $req = bless { r => Apache2::Request->new(@args) }, $classname;
 	my $j = Apache2::Cookie::Jar->new($req->{r});
	if ($j->status() == APR::Const::SUCCESS) {
		$req->{_cookieJar} = $j;
		IF::Log::debug("Cookie names: ".join(' ',$j->cookies()));
	} else {
		IF::Log::debug("Cookie jar status: ".$j->status());
	}
	return $req;
}

sub applicationName {
	my $self = shift;
	return $self->{_applicationName} if $self->{_applicationName};
	my $dirConfigAppNameName = $self->dir_config()->get("Application");
	if ($dirConfigAppNameName) {
		$self->{_applicationName} = $dirConfigAppNameName;
		return $dirConfigAppNameName ;
	}
	return $self->SUPER::applicationName();
}


sub internalRedirect {
    my ($self, $redirect) = @_;
    use Apache2::SubRequest;
    $self->{r}->internal_redirect($redirect);
    return OK;
}

sub dropCookie {
	my $self = shift;
	my $cookie = Apache2::Cookie->new($self, @_);
	unless ($cookie) {
	    IF::Log::error("Failed to create cookie ".join(", ", @_));
        return;
    }
	$cookie->bake($self);
	return $cookie;
}

sub cookieValueForKey {
	my ($self, $key) = @_;
	IF::Log::debug(__PACKAGE__."->cookieValueForKey($key) on ".$self->{_cookieJar});
	return unless $self->{_cookieJar};
	my $c = $self->{_cookieJar}->cookies($key);
	IF::Log::debug(__PACKAGE__."->cookieValueForKey($key) returns $c");
	return $c;
}

sub upload {
    my ($self, $key) = @_;
    return $self->SUPER::upload($key);
}

1;
