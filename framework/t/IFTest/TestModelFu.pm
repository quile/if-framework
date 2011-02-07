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

package IFTest::TestModelFu;

use base qw(
    Test::Class
);
use Test::More;

use IFTest::Application;
use IF::Behaviour::ModelFu;


sub test_identifiers : Test(11) {
    my ($self) = @_;

    # First we'll test the Identifier Fu
    my $i = IF::Behaviour::ModelFu::_Identifier->new("testOfIdentifier");
    ok($i->asCamelCase() eq "TestOfIdentifier", "Camelcase");
    ok($i->asAttribute() eq "testOfIdentifier", "Attribute");
    ok($i->asConstant() eq "TEST_OF_IDENTIFIER", "Constant");
    ok($i->asForeignKey() eq "TEST_OF_IDENTIFIER_ID", "Foreign key");

    my $plural = $i->asPlural();
    ok($plural->asCamelCase() eq "TestOfIdentifiers", "Plural camelcase");
    ok($plural->asAttribute() eq "testOfIdentifiers", "Plural attribute");
    ok($plural->asConstant() eq "TEST_OF_IDENTIFIERS", "Plural constant");
    ok($plural->asForeignKey() eq "TEST_OF_IDENTIFIERS_ID", "Plural foreign key"); # is this necessary?

    # test plurals
    my $fly = IF::Behaviour::ModelFu::_Identifier->new("fly");
    ok($fly->asPlural()->asCamelCase() eq "Flies", "Plural of fly is flies");
    my $grey = IF::Behaviour::ModelFu::_Identifier->new("grey");
    ok($grey->asPlural()->asCamelCase() eq "Greys", "Plural of grey is greys");
    my $history = IF::Behaviour::ModelFu::_Identifier->new("history");
    ok($history->asPlural()->asCamelCase() eq "Histories", "Plural of history is histories");
}

sub test_relationship_fu : Test(15) {
    my ($self) = @_;

    # Now test relationship Fu
    my $r = IF::Behaviour::ModelFu::_Relationship->new();
    ok($r, "Created relationship");
    $r->setName("foo");
    $r->setDetails({
        TARGET_ENTITY => "Foo",
        SOURCE_ATTRIBUTE => q(ID),
        TARGET_ATTRIBUTE => q(FOO_ID),
        TYPE => "TO_ONE",
    });
    ok($r->name() eq "foo", "Name is set ok");
    ok($r->[0] eq "foo", "Name is first entry in array");
    ok($r->details(), "Details are set");
    ok(ref($r->[1]) eq "HASH", "Second entry in array is details hash");
    ok($r->called("bar")->name() eq "bar", "Set the name and returned relationship using 'called()'");

    $r = IF::Behaviour::ModelFu->hasManyToMany("Wang");
    ok($r->name() eq "wangs", "Many to many is named correctly");

    ok($r->details()->{JOIN_TABLE} eq "TEST_MODEL_FU_X_WANG", "Join table is correctly guessed");
    ok($r->details()->{JOIN_TARGET_ATTRIBUTE} eq "TEST_MODEL_FU_ID", "Join target attribute is correct");
    ok($r->details()->{JOIN_SOURCE_ATTRIBUTE} eq "WANG_ID", "Join source attribute is correct");

    $r->joinedThrough("WANG_MAP")->orderedBy("creationDate");
    ok($r->details()->{JOIN_TABLE} eq "WANG_MAP", "Join table is correctly changed");
    ok(IF::Array::isArray($r->details()->{DEFAULT_SORT_ORDERINGS}), "Sort orderings set as array");
    ok($r->details()->{DEFAULT_SORT_ORDERINGS}->[0] eq "creationDate", "Ordering set correctly");

    $r->orderedBy("length", "lastUseDate");
    ok($r->details()->{DEFAULT_SORT_ORDERINGS}->[0] eq "length" &&
       $r->details()->{DEFAULT_SORT_ORDERINGS}->[1] eq "lastUseDate", "Multiple ordering set correctly");

    $r->withKeyValuePairs(
        FOO => "2",
        BAR => [ "BANANA", "PLANKTON", "ABBESS HILDEGARD VON BINGEN" ],
    );
    ok($r->details()->{BAR}->[1] eq "PLANKTON", "Setting extra details seems to work");
}

1;