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

package IFTest::TestRelationships;

use strict;
use base qw(
    Test::Class
);

use Test::More;

use IFTest::Application;
use IF::ObjectContext;
use IF::Log;

sub setUp : Test(startup) {
    my ($self) = @_;
    $self->{oc} = IF::ObjectContext->new();
}

# These tests are a bit bogus because I'm writing them... and I know
# how to avoid the bugs in the ORM because I wrote that too...
# and it definitely has bugs/gaps.
sub test_to_many : Test(7) {
    my ($self) = @_;

    my $entities = [];

    # create a trunk object
    my $trunk = IFTest::Entity::Trunk->new();
    $trunk->setThickness(20);
    push @$entities, $trunk;
    $trunk->save();
    ok($trunk && $trunk->id(), "Made a new trunk object and saved it");

    # add so objects to a to-many
    foreach my $length (0..2) {
        my $branch = IFTest::Entity::Branch->new();
        $branch->setLength($length);
        $branch->setLeafCount(6-$length);
        push @$entities, $branch;
        $trunk->addObjectToBothSidesOfRelationshipWithKey($branch, "branches");
    }
    $trunk->save();

    ok(scalar @{$trunk->branches()} == 3, "Trunk has correct number of branches");

    # now re-fetch
    my $rtr = $self->{oc}->entityWithPrimaryKey("Trunk", $trunk->id());
    ok($rtr && $rtr->is($trunk), "Refetched trunk object");
    ok(scalar @{$rtr->branches()} == 3, "Refetched trunk has correct number of branches");

    # TODO check the actual branches to make sure they're correct

    # now remove a branch
    my $br = $trunk->branches()->[0];
    $trunk->removeObjectFromBothSidesOfRelationshipWithKey($br, "branches");
    $trunk->save();

    ok(scalar @{$trunk->branches()} == 2, "Trunk now has 2 branches");

    my $rtr = $self->{oc}->entityWithPrimaryKey("Trunk", $trunk->id());
    ok($rtr && $rtr->is($trunk), "Refetched trunk again");
    ok(scalar @{$rtr->branches()} == 2, "Refetched trunk has 2 branches");

    # cleanup
    foreach my $e (@$entities) {
        $e->_deleteSelf();
    }

    # TODO check cleanup was successful
}

sub test_to_one : Test(9) {
    my ($self) = @_;

    my $entities = [];

    # create a root object
    my $root = IFTest::Entity::Root->new();
    $root->setTitle("Foo");
    push @$entities, $root;
    $root->save();
    ok($root && $root->id(), "Made a new root object and saved it");

    # create a trunk object
    my $trunk = IFTest::Entity::Trunk->new();
    $trunk->setThickness(20);
    push @$entities, $trunk;
    $trunk->save();
    ok($trunk && $trunk->id(), "Made a new trunk object and saved it");

    $root->setTrunk($trunk);
    $root->save();

    ok($root->trunk(), "Root and trunk related correctly");
    ok($trunk->root(), "Trunk and root related correctly");

    # now re-fetch
    my $rr = $self->{oc}->entityWithPrimaryKey("Root", $root->id());
    ok($rr && $rr->trunk() && $rr->trunk()->is($trunk), "Root refetched and trunk related");

    $rr->setTrunk(undef);
    $rr->save();
    ok(!$rr->trunk(), "Trunk no longer related");
    my $rt = $self->{oc}->entityWithPrimaryKey("Trunk", $trunk->id());
    ok(!$rt, "Trunk has been deleted");

    # refetch
    my $rr = $self->{oc}->entityWithPrimaryKey("Root", $root->id());
    ok($rr && $rr->is($root), "Refetched root again");
    ok(!$rr->trunk(), "Refetched root has no trunk");

    # cleanup
    foreach my $e (@$entities) {
        $e->_deleteSelf();
    }

    # TODO check cleanup was successful
}

sub test_many_to_many : Test(7) {
    my ($self) = @_;

    my $entities = [];
    my $branches = [];
    my $isOk = 1;
    foreach my $c (0..4) {
        my $b = IFTest::Entity::Branch->new();
        $b->setLength($c);
        $b->setLeafCount($c+1);
        push @$branches, $b;
        $b->save();
        $isOk = 0 unless $b->id();
        last unless $isOk;
    }
    ok($isOk, "Created branches");

    my $globules = [];
    $isOk = 1;
    foreach my $c (0..4) {
        my $g = IFTest::Entity::Globule->new();
        $g->setName("Globule $c");
        push @$globules, $g;
        $g->save();
        $isOk = 0 unless $g->id();
        last unless $isOk;
    }
    ok($isOk, "Created globules");

    # associate them via a many-2-many

    my $g0 = $globules->[0];
    my $b4 = $branches->[4];
    $g0->addObjectToBothSidesOfRelationshipWithKeyAndHints($branches->[4], "branches", { FOO => "four", BAR => "bur", } );
    $g0->addObjectToBothSidesOfRelationshipWithKeyAndHints($branches->[2], "branches", { FOO => "two", BAR => "bum", } );
    $g0->save();
    my $brs = $g0->branches();
    ok(scalar @$brs == 2, "Two branches on globule");

    $b4->addObjectToBothSidesOfRelationshipWithKeyAndHints($globules->[1], "globules", { FOO => "one", BAR => "buz", }, );
    $b4->save();
    my $gs = $b4->globules();
    ok(scalar @$gs == 2, "Two globules on branch");

    $g0->removeObjectFromBothSidesOfRelationshipWithKey($branches->[4], "branches");
    $g0->save();
    my $brs = $g0->branches();
    ok(scalar @$brs == 1, "One branch on globule");
    # shame this is _deprecated_...
    ok($brs->[0]->_deprecated_relationshipHintForKey("FOO") eq "two", "Hint is correct");
    ok(scalar @{$b4->globules()}, "One globule on branch");

    # cleanup
    foreach my $e (@$entities) {
        $e->_deleteSelf();
    }

    # TODO check cleanup was successful
}

1;