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

package IFTest::Component::IFTest::Home;

use strict;
use base qw(
    IF::Component
);
use IF::I18N;

# this is an overridden method that the framework
# uses to determine if the component allows
# direct access to its keys and keypaths.  Generally
# you would just override it and return a true value
# to allow access.
sub allowsDirectAccess    { return $_[0]->{allowsDirectAccess} }
sub setAllowsDirectAccess { $_[0]->{allowsDirectAccess} = $_[1] }

# This is used to verify that direct access is working
sub zibzab { return "Zabzib!" }
sub quux   {
    my ($self, $context) = @_;
    if ($context) {
        return "Quux";
    } else {
        return "No context!";
    }
}
sub foo {
    my ($self) = @_;
    return {
        bar => "Fascination!",
        baz => {
            banana => "mango",
        },
    };
}
sub idol {
    my ($self) = @_;
    return IF::Dictionary->new({
        tosser => "Simon Cowell",
        nice => "Paula Abdul",
        funny => "Ryan Seacrest",
        cool => "Randy Jackson",
    });
}

sub goop {
    return "YAK!";
}

sub Bindings {
    return {
        header => {
            type => "STRING",
            value => q("Jabberwock"),
        },
        system_test => {
            type => "URL",
            bindings => {
                url => q("http://b3ta.com"),
            },
        },
    }
}

1;