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

package IFTest::TestComponent;

use strict;
use base qw(
    Test::Class
    IFTest::Type::SiteClassifier
);
use Test::More;
use IFTest::Application;
use IF::Request::Offline;
use IF::Context;
use IFTest::Entity::SiteClassifier;
use IF::Component;
use IF::Components;
use IF::WebServer::Handler;

use IFTest::Component::IFTest::Home;

sub setUp : Test(startup => 2) {
    my ($self) = @_;

    IFTest::Type::SiteClassifier::_setUp($self);
}

sub test_from_request : Test(8) {
    my ($self) = @_;

    my $URI = '/IFTest/root/en/Home/default';
    my $request = IF::Request::Offline->new();
    ok($request, "Created an offline request");
    $request->setApplicationName('IFTest');
    $request->setUri($URI);
    ok($request->uri() eq $URI, "Set the uri on the request");

    my $component = IF::Component->instanceForRequest($request);
    ok($component, "Instantiated component for request");

    my $response = $component->response();
    ok($response, "Got a response");
    ok($response->template(), "Got a template");

    $component->appendToResponse($response, $component->context());
    ok($response->content() =~ /Jabberwock/, "Matched string from resolved binding in response");

    my $output = $component->render();
    ok($output =~ /Jabberwock/, "Rendered directly");
    ok($output =~ /b3ta/, "Rendered URL using system component");
}

sub test_instantiation : Test(3) {
    my ($self) = @_;

    my $component = IFTest::Component::IFTest::Home->new();
    ok($component, "instantiated component");

    my $o = $component->render();
    ok($o && $o =~ /Jabberwock/, "Rendered directly");

    my $response = $component->response();
    $component->appendToResponse($response);

    #diag $response->content();
    ok($response->content() =~ /Jabberwock/, "Rendered via response");
}

sub test_parameters : Test(2) {
    my ($self) = @_;

    my $component = IFTest::Component::IFTest::Home->new();
    #IF::Log::setLogMask(0xffff);
    my $o = $component->renderWithParameters(language => "es", siteClassifierName => "foo");
    #IF::Log::setLogMask(0x0000);

    ok($o =~ /Jabberwock/, "Rendered via response");
    ok($o =~ /Boludo/, "Rendered in correct language");
}

sub test_direct_access : Test(3) {
    my ($self) = @_;

    my $component = IFTest::Component::IFTest::Home->new();
    my $o = $component->render();
    ok($o !~ /Zabzib!/, "Didn't render using direct access");

    $component->setAllowsDirectAccess(1);
    $o = $component->render();
    ok($o =~ /Zabzib!/, "Rendered using direct access");
    ok($o =~ /Quux/, "Context passed in correctly");
}

sub test_key_paths : Test(5) {
    my ($self) = @_;

    my $component = IFTest::Component::IFTest::Home->new();
    my $o = $component->render();
    ok($o =~ /Fascination!/, "Rendered using key path");
    ok($o =~ /Simon Cowell/, "Rendered using 'keypath' tag");
    ok($o =~ /Paula Abdul/, "Rendered using 'keypath' tag without trailing slash");
    ok($o =~ /YAK!/, "Rendered using 'keypath' tag");
    ok($o =~ /RYAN THE DUDE!/, "Rendered using i18n");
}

sub tearDown : Test(shutdown) {
    my ($self) = @_;
    IFTest::Type::SiteClassifier::_tearDown($self);
}


1;