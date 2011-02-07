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

package IFTest::TestMailer;

use strict;
use base qw(
    Test::Class
);
use Test::More;
use IFTest::Application;
use IF::Utility;
use IF::Log;
use utf8;

sub setUp : Test(startup => 2) {
    my ($self) = @_;

    my $app = IFTest::Application->application();
    ok($app, "grabbed app handle");
    $self->{mailer} = $app->mailer();
    ok($self->{mailer}, "grabbed mailer from app");
}

sub test_addresses : Test(7) {
    my ($self) = @_;

    ok($self->{mailer}->emailAddressIsValid('foo@bar.baz'), "foo\@bar.baz is valid email");
    ok(!$self->{mailer}->emailAddressIsSafe('foo@bar.baz'), "foo\@bar.baz is not safe");

    ok($self->{mailer}->emailAddressIsValid('banana@banana.foz'), "banana\@banana.foz is valid email");
    ok($self->{mailer}->emailAddressIsSafe('banana@banana.foz'), "banana\@banana.foz is safe because the application allows it");

    my $admin = $self->{mailer}->SITE_ADMINISTRATOR();
    ok($admin, "Site administrator email present");
    ok($self->{mailer}->emailAddressIsValid($admin), "Site administrator email is valid");
    ok($self->{mailer}->emailAddressIsSafe($admin), "Site administrator email is safe");
}


sub tearDown : Test(shutdown => 0) {
    my ($self) = @_;
}

1;