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

package IFTest::TestStashSession;

use base qw(
    IFTest::Type::Memcached
);
use Test::More;
use IFTest::Application;
use IF::Request::Offline;
use IF::Context;
use IFTest::Entity::SiteClassifier;

# these have an extra test because their parent
# methods start & stop memcache and check to make
# sure it started/stopped.
sub setUp : Test(startup => 1) {
    my ($self) = @_;
    $self->SUPER::_setUp(IF::Application->systemConfigurationValueForKey("MEMCACHED_PORT"));
}

sub tearDown : Test(shutdown => 1) {
    my ($self) = @_;
    $self->SUPER::_tearDown();
    #$self->{_s}->_deleteSelf();
}

sub test_creation : Test(5) {
    my ($self) = @_;

    my $app = IF::Application->applicationInstanceWithName("IFTest");
    ok($app, "Found app instance");

    $sc = "IFTest::Entity::StashSession";
    $self->{_sc} = $sc;

    my $s = $sc->new();
    ok($s, "Created session instance");

    $s->setApplication($app);
    ok($s->application()->name() == $app->name(), "App set correctly");

    $s->setContextNumber(1);
    $s->save();
    $self->{_s} = $s;
    ok($s->id(), "saved session");
    ok($s->externalId(), "session has external id");

}

sub test_persistence : Test(1) {
    my ($self) = @_;

    #diag $self->{_s}->externalId();
    my $ns = $self->{_sc}->sessionWithExternalId($self->{_s}->externalId());
    #diag $self->{_s};
    ok($ns && $ns->is($self->{_s}), "reloaded session using external id");
}

sub test_store : Test(5) {
    my ($self) = @_;

    my $ns = $self->{_sc}->sessionWithExternalId($self->{_s}->externalId());
    ok($ns && $ns->is($self->{_s}), "reloaded session using external id");
    $ns->setSessionValueForKey("Foo bar", "randomText");
    $ns->save();

    my $ns2 = $self->{_sc}->sessionWithExternalId($self->{_s}->externalId());
    ok($ns2 && $ns2->is($self->{_s}), "reloaded session using external id");
    is($ns2->sessionValueForKey("randomText"), "Foo bar", "stored value inflated correctly");
    $ns2->setSessionValueForKey(undef, "randomText");
    $ns2->save();

    my $ns3 = $self->{_sc}->sessionWithExternalId($self->{_s}->externalId());
    ok($ns3 && $ns3->is($self->{_s}), "reloaded session using external id");
    is($ns3->sessionValueForKey("randomText"), undef, "stored value updated correctly");
}

# # TODO
# # * store
#
sub test_request_contexts : Test(5) {
    my ($self) = @_;

    my $s = $self->{_s};
    ok($s->id(), "S has been saved");

    $s->setContextNumber(0);
    $s->save(); # the context number should be incremented on save

    # make some request contexts
    for(my $i=1; $i<=6; $i++) {
        # get the current session
        my $cs = $self->{_sc}->sessionWithExternalId($s->externalId());


        # get the current rc
        my $rc = $cs->requestContext();
        $cs->save();
    }
    #IF::Log::setLogMask(0xffff);
    my $cs = $self->{_sc}->sessionWithExternalId($s->externalId());
    #IF::Log::dump($cs);

    ok(scalar @{$cs->_requestContexts()} == 6, "Created the RC's ok");

    # fetch an RC by context number
    my $rc4 = $cs->requestContextForContextNumber(4);
    ok($rc4 && $rc4->contextNumber() == 4, "found correct request context");

    # hmmmm?
    my $lrc = $cs->requestContextForLastRequest();
    ok($lrc && $lrc->contextNumber() == ($cs->contextNumber() - 1), "found last rc");

    # now make sure the buffering of request contexts works
    # so that older ones are expired

    $cs->setContextNumber(7);
    my $rc = $cs->requestContext();
    $cs->save(); # this should expire rc with context number 0

    #IF::Log::dump($cs);
    my $rfc = $cs->requestContextForContextNumber(1);
    ok(!$rfc, "old rc has expired");
}

1;