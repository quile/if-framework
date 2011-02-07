# First, declare that we're alive:
IF::Log::info("Custom startup script running");

$ENV{'PERLDB_OPTS'} = "NonStop";