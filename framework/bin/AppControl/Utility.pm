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

package AppControl::Utility;

use strict;
use IF::Config;
use vars qw(
    $_APP_CONFIG
);

$_APP_CONFIG = undef;

sub loadAppConfig {
    my ($application, $appConfigPath) = @_;

    if ($application) {
        unshift @INC,  "../../applications/$application", "../applications/$application";
    } elsif ($appConfigPath) {
        my ($appName) = ($appConfigPath =~ m/([^\/]+)\/Config.pm/);
        require "$appConfigPath";
        my $appRoot = ${$appName."::Config::APP_ROOT"};
        unshift @INC, $appRoot;
        $application = basename($appRoot);
    }
    my $appConfig = $application."::Config";
    #print "Loading application config for $appConfig\n";
    eval "use $appConfig";
    if ($@) {
        print STDERR "$@\n";
        exit(1);
    }
    no strict 'refs';
    $_APP_CONFIG = ${$appConfig."::CONFIGURATION"};

    return $appConfig;
}

sub loadApplication {
    my ($application, $appConfigPath) = @_;
    # load app config:
    my $appConfigClassName = loadAppConfig($application, $appConfigPath);

    no strict 'refs';
    my $appRoot = ${$appConfigClassName."::APP_ROOT"};
    $application ||= ${$appConfigClassName."::APP_NAME"};

    die "No app root specified" unless $appRoot;

    # Load the app class
    use lib '$appRoot';
    eval "use ".$application."::Application;";
    die $@ if $@;
    return ($application, $appRoot, $appConfigClassName);
}

# special case for this script because we want to avoid loading an
# IF::Application instance to make this runnable with as few dependencies
# as possible
sub configurationValueForKey {
	my $key = shift;
	die "App configuration not loaded" unless $_APP_CONFIG;
	if (exists($_APP_CONFIG->{$key})) {
		return $_APP_CONFIG->{$key};
	}
	return $IF::Config::CONFIGURATION->{$key};
}

1;