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

package IFTest::Type::Datasource;

#-----------------------------------------
# Base class for tests that need to build
# up some goop in the DB to test against
#-----------------------------------------

use strict;
use base qw(
    Test::Class
);
use Test::More;
use IFTest::Application;
use IF::ObjectContext;

sub setUp : Test(startup => 9) {
    my ($self) = @_;

    $self->{oc} = IF::ObjectContext->new();

    my $entities = [];

    my $ground = IFTest::Entity::Ground->new();
    $ground->setColour("Earthy brown");
    push @$entities, $ground;

    my $root = IFTest::Entity::Root->new();
    $root->setTitle("Root");
    $root->setGround($ground);
    push @$entities, $root;

    my $trunk = IFTest::Entity::Trunk->new();
    $trunk->setThickness(20);
    push @$entities, $trunk;

    $root->setTrunk($trunk);

    my $globules = [];
    my $branches = [];

    foreach my $length (0..5) {
        my $branch = IFTest::Entity::Branch->new();
        $branch->setLength($length);
        $branch->setLeafCount(6-$length);
        push @$branches, $branch;

        my $globule = IFTest::Entity::Globule->new();
        $globule->setName("Globule-$length");
        push @$globules, $globule;

        push @$entities, $branch, $globule;

        # add it to the trunk
        $trunk->addObjectToBranches($branch);
    }

    foreach my $length (0..5) {
        my $b = $branches->[$length];

        my $g1 = $globules->[$length];
        my $g2 = $globules->[($length+1)%6];

        $b->addObjectToGlobules($g1);
        $b->addObjectToGlobules($g2);

        # i hate that this currently necessary
        $b->save();
    }

    my $isOk = 1;
    foreach my $branch (@{$trunk->branches}) {
        next if (scalar @{$branch->globules()} == 2);
        diag $branch->length()." has ".scalar(@{$branch->globules()});
        $isOk = 0;
    }
    ok($isOk, "All branches have 2 globules");

    $root->save();
    ok($root->id(), "Root has an id now");
    ok($trunk->id(), "Trunk has an id now");
    ok($ground->id(), "Ground has an id now");
    ok(scalar @{$ground->roots()} == 1, "Ground has one root");
    ok($root->trunk() && $root->trunk()->is($trunk), "Trunk and root connected");
    ok(scalar @{$trunk->branches()} == 6, "Trunk has six branches");

    my $isOk = 1;
    foreach my $branch (@{$trunk->branches}) {
        next if (scalar @{$branch->globules()} == 2);
        $isOk = 0;
    }
    ok($isOk, "All branches have 2 globules");

    # check that they are still that way by refetching them
    my $rr  = $self->{oc}->entityWithPrimaryKey("Root", $root->id());
    my $rtr = $rr->trunk();
    my $rbs = $rtr->branches();
    my $isOk = (scalar @$rbs == 6);
    #$DB::single = 1;
    #IF::Log::setLogMask(0xffff);
    foreach my $rbr (@$rbs) {
        my $rgs = $rbr->globules();
        next if (scalar @$rgs == 2);
        $isOk = 0;
    }
    #IF::Log::setLogMask(0x0000);
    ok($isOk, "All refetched branches have 2 globules");

    # this just assists with cleanup
    $self->{entities} = $entities;
    $self->{root} = $root;
    $self->{trunk} = $trunk;
}


sub tearDown : Test(shutdown => 1) {
    my ($self) = @_;
    my $found = 0;
    foreach my $e (@{$self->{entities}}) {
        $e->_deleteSelf();
        my $ecdn = $e->entityClassDescription()->name();
        my $re = IF::ObjectContext->new()->entityWithPrimaryKey($ecdn, $e->id());
        $found = $found && $re;
    }
    ok(!$found, "Successfully deleted objects");
}

sub trackEntity {
    my ($self, $entity) = @_;
    $self->{entities} ||= [];
    push (@{$self->{entities}}, $entity);
}

1;
