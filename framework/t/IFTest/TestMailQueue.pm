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

package IFTest::TestMailQueue;

use strict;
use base qw(
    Test::Class
);
use Test::More;
use IFTest::Application;
use IF::Utility;
use IF::Log;
use IF::MailQueue::Model;
use utf8;

sub setUp : Test(startup => 2) {
    my ($self) = @_;

    my $app = IFTest::Application->application();
    ok($app, "grabbed app handle");
    my $mqm = IF::Application->systemConfigurationValueForKey('FRAMEWORK_ROOT')."/lib/IF/MailQueue/ModelWithAttributes.pmodel";
    diag $mqm;
    $self->{model} = IF::MailQueue::Model->new($mqm);
    ok($self->{model}, "loaded model");
}

sub test_entities : Test(1) {
    my ($self) = @_;

    ok(1);
}


sub tearDown : Test(shutdown => 0) {
    my ($self) = @_;
}

1;