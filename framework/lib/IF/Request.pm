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

package IF::Request;

use strict;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and
                        $ENV{MOD_PERL_API_VERSION} >= 2 );
use constant MP1 => ( not exists $ENV{MOD_PERL_API_VERSION} and
                        $ENV{MOD_PERL} );

# Please, don't try this at home without a very good reason!
if (MP2) {
    *new = __PACKAGE__->_generateNewMethod("IF::Request::Apache2");
} elsif (MP1) {
    *new = __PACKAGE__->_generateNewMethod("IF::Request::Apache");
} else {
    *new = __PACKAGE__->_generateNewMethod("IF::Request::Offline");
}

sub _generateNewMethod {
    my ($className, $requestPackageName) = @_;
    eval "use $requestPackageName";
    die "Failed to use $requestPackageName: $@" if $@;
    return sub {
        my ($className, $r) = @_;
        # helpful in the offline where we've already created
        # the request we want to use
        return $r if ref($r) eq $requestPackageName;
        return $requestPackageName->new($r);
    }
}

sub applicationName {
    my $self = shift;
    return $self->{_applicationName} if $self->{_applicationName};
    return $ENV{'IF_APPLICATION_NAME'} || 'IF';
}

sub setApplicationName {
    my ($self, $name) = @_;
    $self->{_applicationName} = $name;
}

sub dropCookie {
    my $self = shift;
    IF::Log::error("dropCookie not implemented");
}

1;
