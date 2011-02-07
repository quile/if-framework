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

package IFTest::TestModule;

use strict;
use base qw(
    Test::Class
);

use Test::More;
use IFTest::Application;
use IF::Log;
use IF::Application::Module;
use IF::Web::ActionLocator;

use Data::Dumper;

sub setUp : Test(startup => 2) {
    my ($self) = @_;
    my $app = IFTest::Application->application();
    ok($app, "Application instantiated correctly");
    $self->{app} = $app;

    # check modules
    my $modules = $app->modules();
    ok(scalar @$modules == 2, "Has two modules");
}

sub test_locating_modules : Test(3) {
    my ($self) = @_;

    my $twang = $self->{app}->moduleWithName("IFTest::Module::Twang");
    ok($twang, "Found twang");
    my $bong = $self->{app}->moduleWithName("IFTest::Module::Bong");
    ok($bong, "Found bong");
    my $foo = $self->{app}->moduleWithName("IFTest::Module::Foo");
    ok(!$foo, "No foo found");
}


sub test_basic_url_generation : Test(13) {
    my ($self) = @_;

    my $URL1 = "/IFTest/root/en/Home/default";
    my $URL1r = "/ift/h";

    my $al = IF::Web::ActionLocator->newFromString($URL1);
    ok($al, "Constructed a web action locator");

    ok($al->urlRoot() eq "IFTest", "URL Root parsed correctly");
    ok($al->siteClassifierName() eq "root", "Site classifier name parsed correctly");
    ok($al->language() eq "en", "Language parsed correctly");
    ok($al->targetComponentName() eq "Home", "component parsed correctly");
    ok($al->directAction() eq "default", "Action parsed correctly");

    my $twang = $self->{app}->moduleWithName("IFTest::Module::Twang");
    my $ru = $twang->urlFromActionLocatorAndQueryDictionary($al, {});
    ok($ru eq $URL1r, "Rewrote url as $URL1r");

    # now try more complex one

    my $URL2 = "/IFTest/banana/ni/Zibzab/view";
    my $URL2r = "/ift/ni/banana/he-man";

    my $al = IF::Web::ActionLocator->newFromString($URL2);

    ok($al->urlRoot() eq "IFTest", "URL Root parsed correctly");
    ok($al->siteClassifierName() eq "banana", "Site classifier name parsed correctly");
    ok($al->language() eq "ni", "Language parsed correctly");
    ok($al->targetComponentName() eq "Zibzab", "component parsed correctly");
    ok($al->directAction() eq "view", "Action parsed correctly");

    my $bong = $self->{app}->moduleWithName("IFTest::Module::Bong");
    my $ru = $bong->urlFromActionLocatorAndQueryDictionary($al, { "questor" => "he-man" });
    ok($ru = $URL2r, "Rewrote url as $ru");
}

sub test_basic_url_parsing : Test(5) {
    my ($self) = @_;
    my $twang = $self->{app}->moduleWithName("IFTest::Module::Twang");
    my $bong  = $self->{app}->moduleWithName("IFTest::Module::Bong");

    my $URL1 = "/ift/h";
    my $URL2 = "/ift/ni/banana/he-man";

    my ($url, $qs) = $twang->urlFromIncomingUrl($URL1);
    ok($url eq "/IFTest/root/en/Home/default", "Parsed incoming $URL1");
    diag $url;
    ok(!$qs, "No qd found");

    my ($url, $qs) = $twang->urlFromIncomingUrl($URL2);
    ok($url eq $URL2, "Couldn't parse");
    my ($url, $qs) = $bong->urlFromIncomingUrl($URL2);
    ok($url eq "/IFTest/banana/ni/Zibzab/view", "Parsed $URL2");
    diag($url);
    ok($qs eq "questor=he-man", "Generated qs correctly");
}

1;