package IF::Default::Components;

# Remember, these are preloaded and cached by mod_perl.  Placing
# them all here allows us to precompile ALL of these
# modules before apache spawns child subprocesses.  This means
# that all forked children SHARE the code, saving vast amounts of
# ram and speeding up module loading later

use strict;
use IF::Component;
use IF::Components;
use IF::Log;


use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and
                        $ENV{MOD_PERL_API_VERSION} >= 2 );
use constant MP1 => ( not exists $ENV{MOD_PERL_API_VERSION} and
                        $ENV{MOD_PERL} );

# This gets run on import so that app name is available to the component loader.

my $APP_NAME;

sub import {
    my ($className, $applicationName) = @_;
    $APP_NAME = $applicationName;

    no strict 'refs';
    my $appName = $APP_NAME;
    my $appRoot = ${$appName."::Config::APP_ROOT"};
    open (DIR, "find $appRoot/components -name '*.pm' -print |") || die "Can't find any components in $appRoot/components";
    my $environment = IF::Application->applicationInstanceWithName($appName)->configurationValueForKey("ENVIRONMENT");
    IF::Log::debug("$appName starting in environment $environment");
    my ($file, $pkg);
    while ($file = <DIR>) {
        next if $file =~ /\/\./o; # skip modules with /. anywhere in their name
        next unless $file =~ /^.+\.pm$/o;
        chomp($file);
        $file =~ s/$appRoot\/components\///g;

        $file =~ s/\.pm//;
        $file =~ s/\//::/g;
        $pkg =     $appName."::Component::".$file;
        eval "use $pkg";
        IF::Log::debug("Imported component $pkg");
        if ($@) {
            die "WARNING: failed to use $pkg: $@";
        }
    }
    close(DIR);
}

1;