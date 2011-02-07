#!/usr/bin/env perl -d

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

use lib qw(. bin lib conf);

use strict;
use IF::Classes;
use Getopt::Long;
use AppControl::Utility;

my $application;
my $result = GetOptions("application=s" => \$application);

die "You must specify an --application on the command line" unless ($result && $application);

my (undef, $appRoot, $appConfigClassName) = AppControl::Utility::loadApplication($application);

IF::Log::setLogMask(0xffff);
my $history = [];
my $oc = IF::ObjectContext->new();

print <<EOP;
IF Console
----------------
This is an interactive console (well, it's the perl debugger)
that you can use to test/query/execute parts of the system.

The object context is initialised and ready for use in the
variable \$oc.
You can instantiate anything else you want using global
declarations, like:

\$o = Foo::Entity::Banana->instanceWithId(52691);

etc
Caveat: Don't use 'my' to declare variables; they will scoped only to
exist on the line of the interpreter and will not exist for your
next command.  If you wish to assign variables while interacting,
just do a straight assignment.

EOP

$DB::single = 1;

sleep(1);
print "> ending!\n";
