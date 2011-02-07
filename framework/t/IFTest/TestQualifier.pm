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

package IFTest::TestQualifier;

use strict;
use base qw(
    IFTest::Type::Datasource
);
use Test::More;

use IFTest::Application;
use IF::Log;
use IF::Model;
use IF::FetchSpecification;
use IF::Qualifier;
use IF::Array;
use IF::ObjectContext;

sub test_fetch_by_id : Test(2) {
    my ($self) = @_;

    my $t1qualifier = IF::Qualifier->key("id = %@", $self->{root}->id());
    my $t1fs = IF::FetchSpecification->new("Root", $t1qualifier);
    my $t1results = $self->{oc}->entitiesMatchingFetchSpecification($t1fs);
    ok(scalar @$t1results == 1, "Found exactly one root by id");

    my $t1qualifier = IF::Qualifier->key("id <> %@", $self->{root}->id());
    my $t1fs = IF::FetchSpecification->new("Root", $t1qualifier);
    my $t1results = $self->{oc}->entitiesMatchingFetchSpecification($t1fs);
    ok(scalar @$t1results == 0, "Found no root by id");
}

sub test_multiple_qualifiers : Test(3) {
    my ($self) = @_;

    my $t2qualifier1 = IF::Qualifier->key("length > %@", 3);
    my $t2qualifier2 = IF::Qualifier->key("leafCount < %@", 3);
    my $t2qualifier3 = IF::Qualifier->and([$t2qualifier1, $t2qualifier2]);
    my $t2fs = IF::FetchSpecification->new("Branch", $t2qualifier3);
    my $t2results = $self->{oc}->entitiesMatchingFetchSpecification($t2fs);
    ok(scalar @$t2results, "Found branches matching qualifiers");
    my $isOk = 1;
    foreach my $r (@$t2results) {
        next if ($r->length() > 3 && $r->leafCount() < 3);
        $isOk = 0;
    }
    ok($isOk, "Matching branches have correct attributes");

    # This will match none
    my $t2qualifier1 = IF::Qualifier->key("length > %@", 50);
    my $t2qualifier2 = IF::Qualifier->key("leafCount < %@", 3);
    my $t2qualifier3 = IF::Qualifier->and([$t2qualifier1, $t2qualifier2]);
    my $t2fs = IF::FetchSpecification->new("Branch", $t2qualifier3);
    my $t2results = $self->{oc}->entitiesMatchingFetchSpecification($t2fs);
    ok(scalar @$t2results == 0, "No branches found matching qualifiers");
}

sub test_single_relationship_traversal : Test(1) {
    my ($self) = @_;

    my $t3qualifier = IF::Qualifier->key("branches.length = %@", 3);
    my $t3fs = IF::FetchSpecification->new("Trunk", $t3qualifier);
    my $t3results = $self->{oc}->entitiesMatchingFetchSpecification($t3fs);
    ok(scalar @$t3results == 1, "Exactly one trunk with a branch whose length is 3");
}


sub test_single_relationship_traversal_with_qualifiers : Test(1) {
    my ($self) = @_;

    my $t4qualifier1 = IF::Qualifier->key("trunk.thickness > %@", 10);
    my $t4qualifier2 = IF::Qualifier->key("length > %@", 4);
    my $t4qualifier3 = IF::Qualifier->and([$t4qualifier1, $t4qualifier2]);
    my $t4fs = IF::FetchSpecification->new("Branch", $t4qualifier3);
    my $t4results = $self->{oc}->entitiesMatchingFetchSpecification($t4fs);
    ok(scalar @$t4results, "Found branches with matching trunk");
}


sub test_multiple_relationship_traversal : Test(2) {
    my ($self) = @_;

    my $t5qualifier1 = IF::Qualifier->key("trunk.thickness > %@", 10);
    my $t5qualifier2 = IF::Qualifier->key("globules.name = %@", 'Globule-1');
    my $t5qualifier3 = IF::Qualifier->and([$t5qualifier1, $t5qualifier2]);
    my $t5fs = IF::FetchSpecification->new("Branch", $t5qualifier3);
    my $t5results = $self->{oc}->entitiesMatchingFetchSpecification($t5fs);
    ok(scalar @$t5results, "Branch matching multiple different relationship traversals");

    # make sure different q's don't match
    my $t5qualifier1 = IF::Qualifier->key("trunk.thickness > %@", 10);
    my $t5qualifier2 = IF::Qualifier->key("globules.name = %@", 'Foo-1');
    my $t5qualifier3 = IF::Qualifier->and([$t5qualifier1, $t5qualifier2]);
    my $t5fs = IF::FetchSpecification->new("Branch", $t5qualifier3);
    my $t5results = $self->{oc}->entitiesMatchingFetchSpecification($t5fs);
    ok(scalar @$t5results == 0, "No branch matched");
}

sub test_multiple_relationships_with_qualifiers : Test(1) {
    my ($self) = @_;

    my $t6qualifier1 = IF::Qualifier->key("trunk.thickness > %@", 10);
    my $t6qualifier2 = IF::Qualifier->key("globules.name = %@", 'Globule-2');
    my $t6qualifier3 = IF::Qualifier->key("leafCount = %@", 4);
    my $t6qualifier4 = IF::Qualifier->and([$t6qualifier1, $t6qualifier2, $t6qualifier3]);
    my $t6fs = IF::FetchSpecification->new("Branch", $t6qualifier4);
    my $t6results = $self->{oc}->entitiesMatchingFetchSpecification($t6fs);
    ok(scalar @$t6results == 1, "Found matching branch");
}

sub test_prefetch_of_to_one : Test(1) {
    my ($self) = @_;

    my $t7qualifier1 = IF::Qualifier->key("title = %@", 'Root');
    my $t7fs = IF::FetchSpecification->new("Root", $t7qualifier1);
    $t7fs->setPrefetchingRelationships(["trunk"]);
    my $t7results = $self->{oc}->entitiesMatchingFetchSpecification($t7fs);
    ok(scalar @$t7results &&
        IF::Array->arrayHasElements($t7results->[0]->_cachedEntitiesForRelationshipNamed("trunk")),
        "Prefetching a to_one relationship");
}


sub test_prefetch_of_to_one_with_qualifiers : Test(1) {
    my ($self) = @_;

    my $t8qualifier1 = IF::Qualifier->key("title = %@", 'Root');
    my $t8qualifier2 = IF::Qualifier->key("trunk.thickness > %@", 10);
    my $t8qualifier3 = IF::Qualifier->and([$t8qualifier1, $t8qualifier2]);
    my $t8fs = IF::FetchSpecification->new("Root", $t8qualifier3);
    $t8fs->setPrefetchingRelationships(["trunk"]);
    my $t8results = $self->{oc}->entitiesMatchingFetchSpecification($t8fs);
    ok(scalar @$t8results &&
        IF::Array->arrayHasElements($t8results->[0]->_cachedEntitiesForRelationshipNamed("trunk")),
        "Prefetch of to_one relationship with qualifier");
}


sub test_prefetch_of_two_to_one_relationships : Test(1) {
    my ($self) = @_;

    my $t9qualifier1 = IF::Qualifier->key("title = %@", 'Root');
    my $t9fs = IF::FetchSpecification->new("Root", $t9qualifier1);
    $t9fs->setPrefetchingRelationships([qw(ground trunk)]);
    my $t9results = $self->{oc}->entitiesMatchingFetchSpecification($t9fs);
    ok(scalar @$t9results
        && IF::Array->arrayHasElements($t9results->[0]->_cachedEntitiesForRelationshipNamed("ground"))
        && IF::Array->arrayHasElements($t9results->[0]->_cachedEntitiesForRelationshipNamed("trunk")),
        "Prefetching TWO to-one relationships in one fetch");
}


sub test_prefetch_of_to_one_with_no_qualifiers : Test(1) {
    my ($self) = @_;

    my $t7fs = IF::FetchSpecification->new("Root");
    $t7fs->setPrefetchingRelationships(["trunk"]);
    my $t7results = $self->{oc}->entitiesMatchingFetchSpecification($t7fs);
    ok(scalar @$t7results &&
        IF::Array->arrayHasElements($t7results->[0]->_cachedEntitiesForRelationshipNamed("trunk")),
        "Prefetching a to_one relationship with no qualifiers");
}


sub test_prefetch_of_to_many_with_no_qualifiers : Test(1) {
    my ($self) = @_;

    my $t11fs = IF::FetchSpecification->new("Trunk");
    $t11fs->setPrefetchingRelationships([qw(branches)]);
    my $t11results = $self->{oc}->entitiesMatchingFetchSpecificationUsingSQLExpressions($t11fs);
    ok(scalar @$t11results &&
        IF::Array->arrayHasElements($t11results->[0]->_cachedEntitiesForRelationshipNamed("branches")),
        "Prefetching a to_many with no qualifiers");
}

sub test_traversal_of_two_relationships_in_qualifier : Test(1) {
    my ($self) = @_;

    my $t15fs = IF::FetchSpecification->new("Root",
                  IF::Qualifier->key("trunk.branches.length = %@", 3),
                  );
    my $t15results = $self->{oc}->entitiesMatchingFetchSpecification($t15fs);
    ok(scalar @$t15results == 1, "Traversed 2 relationships with a single qualifier");
}

sub test_traversal_of_three_relationships_in_qualifier : Test(2) {
    my ($self) = @_;

    my $t16fs = IF::FetchSpecification->new("Ground",
                  IF::Qualifier->key("root.trunk.branches.length = %@", 3),
                  );
    my $t16results = $self->{oc}->entitiesMatchingFetchSpecification($t16fs);
    ok(scalar @$t16results == 1, "Traversed 3 relationships with a single qualifier");

    # check it through a m2m too:

    my $t16fs = IF::FetchSpecification->new("Root",
                  IF::Qualifier->key("trunk.branches.globules.name = %@", "Globule-0"),
                  );
    my $t16results = $self->{oc}->entitiesMatchingFetchSpecification($t16fs);
    ok(scalar @$t16results == 1, "Traversed 3 relationships, and via m2m, with a single qualifier");
}

sub test_traverse_multiple_relationships_with_multiple_qualifiers : Test(1) {
    my ($self) = @_;

    my $t17fs = IF::FetchSpecification->new("Root",
                  IF::Qualifier->and([
                      IF::Qualifier->key("trunk.branches.globules.name = %@", "Globule-2"),
                      IF::Qualifier->key("ground.colour = %@", "Earthy brown"),
                  ])
              );
    my $t17results = $self->{oc}->entitiesMatchingFetchSpecification($t17fs);
    ok(scalar @$t17results == 1, "Traversed multiple relationships with multiple qualifiers");
}

sub test_repeated_joins : Test(1) {
    my ($self) = @_;

    my $t20fs = IF::FetchSpecification->new("Branch",
                    IF::Qualifier->and([
                        IF::Qualifier->key("globules.name = %@", "Globule-0"),
                        IF::Qualifier->key("globules.name = %@", "Globule-1")->requiresRepeatedJoin(),
                    ]));

    my $t20results = $self->{oc}->entitiesMatchingFetchSpecification($t20fs);
    ok(scalar @$t20results > 0, "Found at least one branch that has globules 0 and 1");
}

sub test_qualifier_without_bind_value : Test(1) {
    my ($self) = @_;

    my $rid = $self->{root}->id();
    my $t19fs = IF::FetchSpecification->new("Root", IF::Qualifier->key("id = $rid"));
    my $t19results = $self->{oc}->entitiesMatchingFetchSpecification($t19fs);
    ok(scalar @$t19results == 1, "Retrieved the correct number of roots without using bind value");
}

1;