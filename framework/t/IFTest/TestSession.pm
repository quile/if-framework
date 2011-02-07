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

package IFTest::TestSession;

use base qw(
    Test::Class
    IFTest::Type::SiteClassifier
);
use Test::More;
use IFTest::Application;
use IF::Request::Offline;
use IF::Context;
use IFTest::Entity::SiteClassifier;

sub setUp : Test(startup => 6) {
    my ($self) = @_;

    my $app = IF::Application->applicationInstanceWithName("IFTest");
    ok($app, "Found app instance");

    my $sc = $app->sessionClassName();
    $self->{_sc} = $sc;
    ok($sc eq "IFTest::Entity::Session");

    my $s = $sc->new();
    ok($s, "Created session instance");

    $s->setApplication($app);
    ok($s->application()->name() == $app->name(), "App set correctly");

    $s->setContextNumber(1);
    $s->save();
    $self->{_s} = $s;
    ok($s->id(), "saved session");
    ok($s->externalId(), "session has external id");
    IFTest::Type::SiteClassifier->_setUp($self);
}

sub test_persistence : Test(1) {
    my ($self) = @_;

    my $ns = $self->{_sc}->sessionWithExternalId($self->{_s}->externalId());
    ok($ns && $ns->is($self->{_s}), "reloaded session using external id");
}

# TODO
# * store

sub test_request_contexts : Test(4) {
    my ($self) = @_;

    my $s = $self->{_s};
    ok($s->id(), "S has been saved");

    # make some request contexts
    # -- this involves a fair amount of churn to
    #    save them one by one
    my $allOk = 1;
    for(my $i=1; $i<6; $i++) {
        # get the current session
        my $cs = $self->{_sc}->sessionWithExternalId($s->externalId());
        $cs->setContextNumber($i);

        # get the current rc
        my $rc = $cs->requestContext();
        $cs->save();
        $rc->save();

        unless ($rc->id()) {
            $allOk = 0;
        }
    }
    ok($allOk, "Created the RC's ok");

    # fetch an RC by context number
    my $rc4 = $self->{_s}->requestContextForContextNumber(4);
    ok($rc4 && $rc4->contextNumber() == 4, "found correct request context");

    $s = $self->{_s}->currentStoredRepresentation();
    my $lrc = $s->requestContextForLastRequest();
    ok($lrc && $lrc->contextNumber() == ($s->contextNumber() - 1), "found last rc");
}

sub test_sid_key : Test(1) {
    my ($self) = @_;

    my $sidKey = $self->{_s}->application()->sessionIdKey();
    is($sidKey, "iftest-sid", "Generated correct sid key");
}

sub tearDown : Test(shutdown) {
    my ($self) = @_;
    $self->{_s}->_deleteSelf();
    IFTest::Type::SiteClassifier->_tearDown($self);
}

1;