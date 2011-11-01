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

package IFTest::TestQuery;

use strict;
use base qw(
    IFTest::Type::Datasource
);
use Test::More;
use IF::Log;
use IFTest::Application;
use IF::Query;
use IF::ObjectContext;


# sub setUp : Test(startup => 4) {
#     my ($self) = @_;
#
#     my $entities = [];
#     my $root = IFTest::Entity::Root->new();
#     $root->setTitle("Root");
#     push @$entities, $root;
#
#     my $trunk = IFTest::Entity::Trunk->new();
#     $trunk->setThickness(20);
#     push @$entities, $trunk;
#
#     $root->setTrunk($trunk);
#
#     foreach my $length (0..5) {
#         my $branch = IFTest::Entity::Branch->new();
#         $branch->setLength($length);
#         $branch->setLeafCount(6-$length);
#         push @$entities, $branch;
#         $trunk->addObjectToBranches($branch);
#     }
#
#     $root->save();
#     ok($root->id(), "Root has an id now");
#     ok($trunk->id(), "Trunk has an id now");
#
#     ok($root->trunk() && $root->trunk()->is($trunk), "Trunk and root connected");
#     ok(scalar @{$trunk->branches()} == 6, "Trunk has six branches");
#
#     # this just assists with cleanup
#     $self->{entities} = $entities;
#
#     $self->{root} = $root;
# }
#
# sub tearDown : Test(shutdown => 1) {
#     my ($self) = @_;
#     my $found = 0;
#     foreach my $e (@{$self->{entities}}) {
#         $e->_deleteSelf();
#         my $ecdn = $e->entityClassDescription()->name();
#         my $re = IF::ObjectContext->new()->entityWithPrimaryKey($ecdn, $e->id());
#         $found = $found && $re;
#     }
#     ok(!$found, "Successfully deleted object");
# }

sub setUp: Test(setup) {
    my ($self) = @_;
    IF::ObjectContext->new()->init();
}

sub test_basic: Test(2) {
    my ($self) = @_;

    my $basic = IF::Query->new("Root");
    my $all = $basic->all();
    ok($all && scalar @$all == 1, "Basic query all() returned correct number");
    my $basic = IF::Query->new("Branch");
    my $all = $basic->all();
    ok($all && scalar @$all == 6, "Basic query all() returned correct number when more than 1 result");
}

sub test_iterate : Test(4) {
    my ($self) = @_;

    # Simple fetch of 1 item
    my $query = IF::Query->new("Trunk");
    ok($query->next(), "Fetched object correctly");
    ok(!$query->next(), "Iteration terminated correctly");

    # Simple fetch of more than 1 item
    my $query = IF::Query->new("Branch");
    ok( $query->next()
     && $query->next()
     && $query->next()
     && $query->next()
     && $query->next()
     && $query->next(), "Fetch six objects using ->next()");
    ok(!$query->next(), "Iteration terminated orrectly");
}

sub test_filter : Test(7) {
    my ($self) = @_;

    # simple filter with one term
    my $query = IF::Query->new("Root")->filter("title = %@", "Foosball");
    ok(!$query->next(), "No result found when one-term filter doesn't match");
    $query = IF::Query->new("Root")->filter("title LIKE %@", "Roo%");
    ok($query->next() && !$query->next(), "Exactly one result found when one-term filter matches");

    # find exact match
    $query = IF::Query->new("Root")->filter("title = %@", "Root");
    ok($query->next(), "Result found when one-term filter with bind value matches");
    $query = IF::Query->new("Root")->filter("title = 'Root'");
    ok($query->next(), "Result found when one-term filter without bind value matches");

    # try filter with no bind values
    $query = IF::Query->new("Branch")->filter("length > 4");
    ok( $query->next()
     && !$query->next(), "Found one result using filter without bind values");

    # try more than one filter
    $query = IF::Query->new("Branch")->filter("length < %@", 2)->filter("leafCount > %@", 4);
    ok( $query->next()
     && $query->next()
     && !$query->next(), "Found two results using two filters");

    # adjust the filter and check
    $query = IF::Query->new("Branch")->filter("length < %@", 2)->filter("leafCount > %@", 5);
    ok( $query->next()
     && !$query->next(), "Found one result using two filters");
}

sub test_count : Test(2) {
    my ($self) = @_;

    my $query = IF::Query->new("Branch")->filter("leafCount > 4");
    ok($query->count() == 2, "Counted correct number of branches");

    # change the filter
    $query = IF::Query->new("Branch");
    ok($query->count() == 6, "Counted correct number of branches with no filter");
}

sub test_reset : Test(1) {
    my ($self) = @_;

    my $query = IF::Query->new("Branch")->filter("length > 4");
    my $nid = $query->next()->id();
    $query->reset();
    ok($query->next()->id() == $nid, "Reset query started it over again");
}

sub test_join : Test(2) {
    my ($self) = @_;

    # TODO test the objects when they come back and make sure
    # they're the right objects.
    my $query = IF::Query->new("Root")->filter("trunk.thickness > 10");
    ok( $query->next()
     && !$query->next(), "Found one object when qualifying via a join");

    $query = IF::Query->new("Root")->filter("trunk.branches.leafCount > 5");
    ok( $query->next()
     && !$query->next(), "Found one object via two joins");

}

sub test_limit : Test(2) {
    my ($self) = @_;

    my $query = IF::Query->new("Branch")->filter("leafCount > 2");
    ok($query->count() == 4, "Counted 4 branches");

    $query->reset()->limit(2);
    ok( $query->next()
     && $query->next()
     && !$query->next(), "Limited fetch that matches 4 to 2 results");
}

sub test_ordering : Test(2) {
    my ($self) = @_;

    my $query = IF::Query->new("Branch")->orderBy("leafCount");
    ok($query->first()->leafCount() == 1, "First item has correct count");
    $query->reset()->orderBy("leafCount DESC");
    ok($query->first()->leafCount() == 6, "First item has correct count");
}

sub test_prefetching : Test(2) {
    my ($self) = @_;

    my $query = IF::Query->new("Trunk");
    my $trunk = $query->first();
    ok($trunk && IF::Array->arrayHasNoElements($trunk->_cachedEntitiesForRelationshipNamed("branches")), "No items prefetched");
    $query->reset()->prefetch("branches");
    $trunk = $query->first();
    ok( $trunk
     && IF::Array->arrayHasElements($trunk->_cachedEntitiesForRelationshipNamed("branches"))
     && scalar @{$trunk->_cachedEntitiesForRelationshipNamed("branches")} == 6,
     "Prefetched all branches"
    );
}

1;