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

package IFTest::TestSummarySpecification;

use strict;
use base qw(
    IFTest::Type::Datasource
);

use Test::More;
use IF::Qualifier;
use IF::SummarySpecification;
use IF::SummaryAttribute;

sub test_counting : Test(2) {
    my ($self) = @_;

    my $qualifier = IF::Qualifier->key("globules.name = %@", "Globule-2");

    my $ss = IF::SummarySpecification->new('Branch', $qualifier);
    ok($ss, "Constructed Summary Spec");

    $ss->restrictFetchToAttributes("globuleCount");
    my $results = $self->{oc}->resultsForSummarySpecification(
            $ss->initWithSummaryAttributes([IF::SummaryAttribute->new("globuleCount", "COUNT(distinct %@)", "id")])
    );
    my $count = $results->[0]->valueForKey("globuleCount");
    ok($count == 2, "Found 2 distinct ids for branches with globule-2");
}


# super crappy test:
sub test_grouping_summary : Test(3) {
    my ($self) = @_;

    my $ss = IF::SummarySpecification->new("Globule", IF::Qualifier->key("branches.length > %@", 0));

    $ss->setGroupBy(['attributeSum']);

    $ss->restrictFetchToAttributes(['attributeSum', 'globuleCount']);
    $DB::single = 1;
    my $results = $self->{oc}->resultsForSummarySpecification(
        $ss->initWithSummaryAttributes([
            IF::SummaryAttribute->new("attributeSum", "LENGTH + LEAF_COUNT"),
            IF::SummaryAttribute->new("globuleCount", "COUNT(DISTINCT %@)", "id"),
        ])
    );
    ok(scalar @$results == 1, "One result found");
    ok($results->[0]->valueForKey("attributeSum") == 6, "Attribute sum is correct");
    #diag $results->[0]->valueForKey("attributeSum");
    ok($results->[0]->valueForKey("globuleCount") == 6, "Found 6 globules whose branches sum to 6");
    #diag $results->[0]->valueForKey("globuleCount");
}

1;