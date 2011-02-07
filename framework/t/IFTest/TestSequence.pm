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

package IFTest::TestSequence;

use base qw(
    Test::Class
);
use Test::More;
use IFTest::Application;
use IF::DB;

sub setUp : Test(startup => 1) {
     my ($self) = @_;

     my $st = IF::Application->systemConfigurationValueForKey("SEQUENCE_TABLE");

     IF::DB::executeArbitrarySQL("INSERT INTO `$st` (NAME, NEXT_ID) VALUES ('FOO', 666)");
     my ($rows, undef) = IF::DB::rawRowsForSQL("SELECT NEXT_ID FROM `$st` WHERE NAME='FOO'");
     ok($rows->[0]->{NEXT_ID} == 666, "Inserted and initialised sequence");
}

sub test_next : Test(2) {
    my ($self) = @_;

    my $n = IF::DB::nextNumberForSequence("FOO");
    ok($n == 666, "N is correct");
    $n = IF::DB::nextNumberForSequence("FOO");
    ok($n == 667, "N is correct");
}

sub test_faulting : Test(2) {
    my ($self) = @_;

    my $n = IF::DB::nextNumberForSequence("BAR");
    ok($n == 1, "N is correct");
    $n = IF::DB::nextNumberForSequence("BAR");
    ok($n == 2, "N is correct");
}

sub tearDown : Test(shutdown) {
    my ($self) = @_;

    my $st = IF::Application->systemConfigurationValueForKey("SEQUENCE_TABLE");
    IF::DB::executeArbitrarySQL("DELETE FROM `$st`");
}

1;