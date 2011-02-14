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

package IFTest::TestKeyValueCoding;

use base qw(
    Test::Class
);

use Test::More;
use strict;

my $camelCaseUpperCaseMap = {
    'attributeName' => "ATTRIBUTE_NAME",
    'name' => "NAME",
    'aBigLongName' => "A_BIG_LONG_NAME",
    'aProperty' => "A_PROPERTY",
};

sub test_names : Test(8) {
    my ($self) = @_;
    foreach my $key (keys %{$camelCaseUpperCaseMap}) {
        my $value = $camelCaseUpperCaseMap->{$key};
        my $valueResult = IF::Interface::KeyValueCoding::keyNameFromNiceName($key);
        my $keyResult = IF::Interface::KeyValueCoding::niceName($value);
        ok($value eq $valueResult,"keyNameFromNiceName: $key -> $value (result: $valueResult)");
        ok($key eq $keyResult,"niceName: $value -> $key (result: $keyResult)");
    }
}

my $keyPathToElementArrayMap = {
    # Commented out b/c whitespace is not stripped at the moment
    #' abc.def.ghi ' => [qw(abc def ghi)], # test stripping of whitespace
    'xyz.bbc.xyz' => [qw(xyz bbc xyz)],
    'nnn' => [qw(nnn)],
    'ooo.' => [qw(ooo)],  # hmm, this one passes
};

my $keyPathsWithArguments = {
    q(abc.def("Arg With Spaces").yyy) => [{key => 'abc'},
                                         {key => 'def', arguments => [q("Arg With Spaces")]},
                                         {key => 'yyy'}, ],
};

sub test_parsing : Test(no_plan) {
    my ($self) = @_;
    foreach my $keyPath (keys %{$keyPathToElementArrayMap}) {
        my $reference = $keyPathToElementArrayMap->{$keyPath};
        my $test = IF::Interface::KeyValueCoding::keyPathElementsForPath($keyPath);
        ok(scalar @$reference == scalar @$test, "$keyPath has correct element count");
        foreach my $i (0..scalar @$reference -1) {
            ok ($reference->[$i] eq $test->[$i]->{key}, "element matches: ".$reference->[$i]." == ".$test->[$i]->{key});
        }
    }

    foreach my $keyPath (keys %{$keyPathsWithArguments}) {
        my $reference = $keyPathsWithArguments->{$keyPath};
        my $test = IF::Interface::KeyValueCoding::keyPathElementsForPath($keyPath);
        ok(scalar @$reference == scalar @$test, "$keyPath has correct element count");
        foreach my $i (0..scalar @$reference -1) {
            ok ($reference->[$i]->{key} eq $test->[$i]->{key}, "element matches: ".$reference->[$i]->{key}." == ".$test->[$i]->{key});
            ok (defined $reference->[$i]->{arguments} == defined $test->[$i]->{arguments}, "Both either do or don't have arguments");
            if (defined $reference->[$i]->{arguments}) {
                ok (scalar @{$reference->[$i]->{arguments}} == scalar @{$test->[$i]->{arguments}}, "element has correct argument count");
                my $refArgs = $reference->[$i]->{arguments};
                my $testArgs = $test->[$i]->{arguments};
                for my $j (0..scalar @$refArgs -1) {
                    ok($refArgs->[$j] eq $testArgs->[$j], "arg $j matches: ".$refArgs->[$j]." eq ".$testArgs->[$j]);
                }
            }
        }
    }

    my $root = IFTest::Entity::Root->new();
    $root->setTitle("Banana");
    ok($root->stringWithEvaluatedKeyPathsInLanguage('Title: ${title}') eq "Title: Banana", "key paths in interpolated string work");
}

1;