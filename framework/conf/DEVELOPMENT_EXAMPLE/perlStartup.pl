# First, declare that we're alive:
IF::Log::info("Custom startup script running");

# Turn Apache::StatINC on for /ip
IF::Log::info("Installing Apache::StatINC handler");
$Location{"/if"}->{'PerlInitHandler'} = "Apache::StatINC";

# Uncomment this line if you want to see when Apache::StatINC
# reloads your modules:
#push @{ $Location{"/ip"}->{PerlSetVar} }, [ StatINC_Debug => '1' ];
$ENV{'PERLDB_OPTS'} = "NonStop";