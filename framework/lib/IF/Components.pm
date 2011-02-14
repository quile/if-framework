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

package Components;

# Remember, these are preloaded and cached by mod_perl.  Placing
# them all here allows us to precompile ALL of these
# modules before apache spawns child subprocesses.  This means
# that all forked children SHARE the code, saving vast amounts of
# ram and speeding up module loading later

use strict;

use IF::Application;
use IF::Component;

BEGIN {
    my $frameworkRoot = IF::Application->systemConfigurationValueForKey("FRAMEWORK_ROOT");

    open (DIR, "find $frameworkRoot/lib/IF/Component -name '*.pm' -print |") || die "Can't find any components in $frameworkRoot/lib/IF/Component";

    my ($file,$pkg);
    while ($file = <DIR>) {
        next unless $file =~ /^.+\.pm$/;
        $file =~ s/$frameworkRoot\/lib\/IF\/Component\///g;
        $file =~ s/\.pm//;
        $file =~ s/\//::/g;
        $pkg =     "IF::Component::".$file;
        #IF::Log::debug("use $pkg\n");
        eval "use $pkg";
        if ($@) {
            die "WARNING: failed to use $pkg: $@";
        }
    }
    close(DIR);
}

1;
