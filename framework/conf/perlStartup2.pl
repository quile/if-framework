use strict;
no warnings;
# This is a bit nasty
# TODO

our %Location;
use Apache2::Const qw(:common);
use Apache2::Status ();
use Apache::DBI ();
DBI->install_driver("mysql");
BEGIN {
    # TODO make this work for all of the apps
    # my $uname = `uname`;  
    # chomp $uname;
    # if ($uname eq 'FreeBSD' || $uname eq 'Linux') {
    #         require Apache2::SizeLimit;
    #         $Apache2::SizeLimit::MAX_PROCESS_SIZE = $ENV{'MAX_PROC_SIZE'};
    #         $Apache2::SizeLimit::DEBUG = 0;
    #         $Location{"/if"}->{'PerlFixupHandler'} = 'Apache2::SizeLimit';
    # }
}

# Logging:
use IF::Log;
IF::Log::debug("Env is ".$ENV{'FRAMEWORK_ROOT'}." and ".$ENV{'APP_ROOT'});

BEGIN {
    IF::Log::setLogMask($ENV{'LOG_MASK'});          #  set from macros and httpd.conf
    #IF::Log::setLogMask(1|4|16|32|512); #  Apache, Info, Error, Assertion
    #IF::Log::setLogMask(0);                  #  All Off (default)
}

use IF::Classes;
# Load config-specific  here for each application (?)
my $configStart = "$ENV{'FRAMEWORK_ROOT'}/conf/ACTIVE/perlStartup2.pl";
if (-f $configStart) {
     IF::Log::debug("Loading framework perl startup file at $configStart");
     require "$configStart";
}

# Load app-specific classes here for each application (?)
# Load in this particular conf's own perlStartup.pl
my $perlStart = "$ENV{'APP_ROOT'}/conf/ACTIVE/perlStartup2.pl";
if (-f $perlStart) {
     IF::Log::debug("Loading local perl startup file at $perlStart");
     require "$perlStart";
}

IF::Log::info("Started mod_perl2 server, listening for requests");

1;
