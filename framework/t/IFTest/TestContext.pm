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

package IFTest::TestContext;

use base qw(
    Test::Class
    IFTest::Type::SiteClassifier
);
use Test::More;
use IFTest::Application;
use IF::Request::Offline;
use IF::Context;
use IFTest::Entity::SiteClassifier;

sub setUp : Test(startup => 4) {
    my ($self) = @_;

    IFTest::Type::SiteClassifier::_setUp($self);

    my $URI = '/IFTest/root/en/Home/boohoo';
    my $request = IF::Request::Offline->new();
    ok($request, "Create an offline request");
    $request->setApplicationName('IFTest');
    $request->setUri($URI);
    ok($request->uri() eq $URI, "Set the uri on the request");

    $self->{request} = $request;
}

sub tearDown : Test(shutdown) {
    my ($self) = @_;
    IFTest::Type::SiteClassifier::_tearDown($self);
}


sub test_request_params : Test(10) {
    my ($self) = @_;

    ok($self->{rootSiteClassifier}, "Root site classifier set");

    my $request = $self->{request};
    $request->param('abc' => '123');
    $request->param('def' => ['555', '666', '777']);
    $request->param('blank' => '');

    ok($request->param('abc') eq '123', "Scalar param fetched back from request correctly");
    ok([$request->param('def')]->[0] eq '555', "Array param fetched back from request correctly");

    my $context = IF::Context->contextForRequest($request);
    ok($context, "Create and inflated a context");

    my $rv = $context->formValueForKey('abc');
    ok($rv eq '123', "Scalar key value from request fetched correctly. (abc eq $rv)");

    my $rv = $context->formValuesForKey('abc');
    ok($rv->[0] eq '123', "Scalar key value from request fetched correctly in list context. ([abc]->[0] eq $rv->[0])");

    my $rv = $context->formValueForKey('def');
    my @rvl = split("\0", $rv);
    ok($rvl[2] eq "777", "Multiple value key fetched as scalar. (def[2] eq 777)");

    my $rv = $context->formValuesForKey('def');
    ok(scalar @$rv == 3 && $rv->[0] eq '555', "Multiple value key fetched as list. ([def]->[0] eq $rv->[0])");

    my $rv = $context->formValueForKey('blank');
    ok(!length($rv), "Key with empty string value returned correctly.");

    # Test setting form values on the context
    $context->setFormValueForKey('999', 'abc');
    my $rv = $context->formValueForKey('abc');
    ok($rv eq '999', "Scalar value following setFormValueForKey on context returned ok. (abc eq $rv)");
}

1;