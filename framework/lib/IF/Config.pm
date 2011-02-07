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

package IF::Config;

use strict;
use vars qw(
			$CONFIGURATION
			);

use Data::Dumper;

eval {
	require "conf/ACTIVE/IF.conf";
} or die "Failed to load IF.conf: $@ \n".Dumper \%INC;

my $BUILD_VERSION = 1;

eval {
    $BUILD_VERSION = do "conf/BUILD_VERSION.conf";

} or die "Couldn't load build version; maybe you need run 'make javascript' for the framework\n";


$CONFIGURATION = {
	DEFAULT_ENTITY_CLASS => "IF::Entity::Persistent",
	DEFAULT_BATCH_SIZE => 30,
	DEFAULT_LANGUAGE => "en",
	DEFAULT_MODEL => "",  # TODO:  maybe come up with a better default for this?
	SEQUENCE_TABLE => "SEQUENCE",
	JAVASCRIPT_ROOT => "/javascript",
	# these may get re-defined in the site-specific conf
	# so we want to load that last
	SHOULD_CACHE_TEMPLATE_PATHS => 1,
	SHOULD_CACHE_TEMPLATES => 0,
	SHOULD_CACHE_BINDINGS => 0,
	PROCS_TO_RUN => [qw(ApacheModPerl ApacheCache)],
	BUILD_VERSION => $BUILD_VERSION,
	%$CONFIGURATION,
};

1;