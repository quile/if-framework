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

package IF::Request::Apache;

use strict;
use base qw(IF::Request Apache::Request);
use Apache::Cookie ();

# Apache::Request does some funky stuff with it's
# constructor necessitating this.
# See perldoc Apache::Request for details
sub new {
	my($classname, @args) = @_;
	my $req = bless { r => Apache::Request->new(@args) }, $classname;
	$req->{_cookies} = Apache::Cookie->fetch();
	return $req;
}

sub applicationName {
	my $self = shift;
	return $self->{_applicationName} if $self->{_applicationName};
	my $dirConfigAppNameName = $self->dir_config()->get("Application");
	return $dirConfigAppNameName if $dirConfigAppNameName;
	return $self->SUPER::applicationName();
}

sub internalRedirect {
    my ($self, $redirect) = @_;
    my $subr = $self->{r}->lookup_uri($redirect);
    return $subr->run(1);
}

sub dropCookie {
	my $self = shift;
	my $cookie = Apache::Cookie->new($self, @_);
	$cookie->bake;
	return $cookie;
}

sub cookieValueForKey {
	my ($self, $key) = @_;
	my $c = $self->{_cookies}->{$key};
	return $c;
}

1;
