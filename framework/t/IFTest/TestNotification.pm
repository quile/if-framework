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

package IFTest::TestNotification;

use strict;
use base qw(
    Test::Class
);
use Test::More;

sub test_basic : Test(2) {
    my ($self) = @_;

    my $x = IFTest::Entity::Foo->new();
    my $inh = $x->invokeNotificationFromObjectWithArguments("didFooBar", undef);
    ok($x->name() eq "Foo", "First notification was received");
    ok($x->email() eq "Bar", "Second notification was received");
};

# Set up some fake notifications that we can test.  I love perl.

package IFTest::Entity::Foo;
use base qw(IFTest::Entity);

sub name     { return $_[0]->{name} }
sub setName  { $_[0]->{name} = $_[1] }
sub email    { return $_[0]->{email} }
sub setEmail { $_[0]->{email} = $_[1] }
sub didFooBar {
    my ($self, @arguments) = @_;
    $self->setName("Foo");
}

package IF::Interface::KeyValueCoding;
sub didFooBar {
    my ($self, @arguments) = @_;
    $self->setEmail("Bar");
}

1;