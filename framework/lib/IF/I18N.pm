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

package IF::I18N;

use strict;
use vars qw($AUTOLOAD @EXPORT);
#=================================================
# this class abstracts the Language modules from
# the application layer.  all constant strings
# should be vended through this API
#=================================================
use IF::Application;
use IF::Log;

# Load system strings
use IF::I18N::en;

use Exporter 'import';
@EXPORT = (
    '_s'
);

sub defaultLanguage {
	return IF::Application->defaultApplication()->defaultLanguage();
}

# TODO: This only works in single-threaded code!
my $LANG;
sub setLanguage {
    $LANG = shift;
}
sub language {
    return $LANG || 'en';
}

my $_STRING_CACHE = {};

# TODO: optimise this... it's super inefficient
sub _s {
    my $string = shift;
    # if the first arg is an object, ignore it; sometimes this gets
    # called as a method on an object (from bindings, usually),
    # so we can ignore the first arg in that case.
    # TODO: use the first arg to evaluate the string against the object.
    if (ref($string)) {
        $string = shift;
    }
    my $language = shift;
    my $applicationName = shift;
    $language ||= language();
    my $applications = $applicationName? [$applicationName] : [map {$_->name()} @{IF::Application->allApplications()}];
    no strict 'refs';
    foreach my $application (@$applications) {
        my $s = $application."::I18N::".$language."::STRINGS";
        my $v = ${$s}->{$string};
        if ($v) {
            $_STRING_CACHE->{$string} = $v;
            return $v;
        }
    }

    # Check system strings, otherwise return just $string itself
    my $ds = "IF::I18N::".$language."::STRINGS";
    my $v = ${$ds}->{$string} || $string;

    $_STRING_CACHE->{$string} = $v;
    return $v;
}

1;
