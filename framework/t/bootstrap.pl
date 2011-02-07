#!/usr/bin/env perl

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

use lib qw(t . lib conf);

# This is a comment
#
use strict;

use IFTest::Application;
use IF::Array;
use IF::Log;

my $FRAMEWORK_ROOT = IF::Application->systemConfigurationValueForKey("FRAMEWORK_ROOT");

$ENV{'FRAMEWORK_ROOT'} = $FRAMEWORK_ROOT;
require "$FRAMEWORK_ROOT/bin/AppControl/Perl5Lib.pl";


my $modelBuilder = "$FRAMEWORK_ROOT/bin/populateModel";

my $testModelFileName = "IFTest/Model.pmodel";

my $outputModelPath = IFTest::Application->application()->configurationValueForKey("DEFAULT_MODEL");
#ok($outputModelPath, "found output model path");

my $modelClass = IF::Application->defaultApplication()->defaultModelClassName();
my $model = $modelClass->new($testModelFileName);
#ok($model, "loaded test model");

# now that it's loaded, we can loop through entities and make their tables
my $namespace = $model->entityNamespace();
foreach my $entityClassName (@{$model->allEntityClassKeys}) {
    my $fullname = $namespace."::".$entityClassName;
    if (UNIVERSAL::can($fullname, "_test_createTableCommand")) {
        my $c = $fullname->_test_dropTableCommand();
        $c = IF::Array->arrayFromObject($c);
        my $ct = $fullname->_test_createTableCommand();
        $ct = IF::Array->arrayFromObject($ct);
        foreach my $command (@$c, @$ct) {
            IF::DB::executeArbitrarySQL($command);
        }
    }
}

my $st = IF::Application->systemConfigurationValueForKey("SEQUENCE_TABLE");

# Drop and create the sequence table
IF::DB::executeArbitrarySQL(qq{
    DROP TABLE IF EXISTS `$st`
});
IF::DB::executeArbitrarySQL(qq{
    CREATE TABLE `$st` (
        NAME CHAR(64) NOT NULL DEFAULT '',
        NEXT_ID INT(11) NOT NULL DEFAULT 1
    )
});

# build the fully populated model:

# populate model
my $command = "perl $modelBuilder --input-model=$testModelFileName --output-model=$outputModelPath --application=IFTest";
system($command);

my $namespace = $model->entityNamespace();
foreach my $entityClassName (@{$model->allEntityClassKeys}) {
    # create low-level entity bits
    my $createCommand = "bin/createEntity --application=IFTest --entity=$entityClassName --silent";
    system($createCommand);
}
