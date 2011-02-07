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

package IFTest::TestDerivedRelationship;

use strict;
use base qw(
    IFTest::Type::Datasource
);
use Test::More;
use IFTest::Application;

# Test relationship traversal and derived relationships

# Test: the new code that handles derived data sources; basically
# at allows any FetchSpecification (almost) to be used as a relationship
# in another query

sub test_basic : Test(6) {
    my ($self) = @_;

    my $elastic = IFTest::Entity::Elastic->new();

    # grab a branch
    my $trunk = $self->{oc}->allEntities("Trunk")->[0];
    ok($trunk, "Grabbed a trunk");

    $elastic->setSourceId($trunk->id());
    $elastic->setSourceType("Trunk");
    $elastic->setPling("Bloop!");
    $elastic->save();

    # This finds branches
    my $dq = IF::Qualifier->key("length > %@", 4);
    my $dfs = IF::FetchSpecification->new("Branch", $dq);
    ok($self->{oc}->countOfEntitiesMatchingFetchSpecification($dfs) == 1, "Found one entity with basic fs");

    # This finds Elastics
    my $dq2 = IF::Qualifier->and([
        IF::Qualifier->key("sourceId = %@", $trunk->id()),
        IF::Qualifier->key("sourceType = %@", "Trunk"),
    ]);
    my $dfs2 = IF::FetchSpecification->new("Elastic", $dq2);
    ok($self->{oc}->countOfEntitiesMatchingFetchSpecification($dfs2) == 1, "Found one entity with basic fs");


    # dfs finds branches with length > 4, so let's use that as a derived data source
    # and add another derived data source for elastics
    # This will find all orgs that have both jobs and internships in canada.

    my $fs = IF::FetchSpecification->new("Trunk");
    # Commented out because having more than one derived data source for now
    # doesn't work; it gets the bind values in the wrong order;
    # TODO : fix this limitation!

    # $fs->addDerivedDataSourceWithNameAndQualifier($dfs, "LongBranches",
    #                               IF::Qualifier->key("LongBranches.trunkId = id"));

    $fs->addDerivedDataSourceWithNameAndQualifier($dfs2, "BendyElastics",
                                    IF::Qualifier->and([
    								    IF::Qualifier->key("BendyElastics.sourceId = id"),
    								    IF::Qualifier->key("BendyElastics.sourceType = 'Trunk'")
    								]),
    							);
    my $r = $self->{oc}->entitiesMatchingFetchSpecification($fs);
    ok(scalar @$r == 1, "Found one trunk");
    diag @$r;

    # add a qualifier across the derived relationship:
    $fs->setQualifier(IF::Qualifier->key("BendyElastics.pling = 'Bloop!'"));
    my $r = $self->{oc}->entitiesMatchingFetchSpecification($fs);
    ok(scalar @$r == 1, "Found one trunk when qualifying across derived relationship");

    # change the qualifier not to match
    $fs->setQualifier(IF::Qualifier->key("BendyElastics.pling = 'Fang!'"));
    my $r = $self->{oc}->entitiesMatchingFetchSpecification($fs);
    ok(scalar @$r == 0, "Found no trunks when qualifying across derived relationship with non-matching qual");

    $elastic->_deleteSelf();
}

1;