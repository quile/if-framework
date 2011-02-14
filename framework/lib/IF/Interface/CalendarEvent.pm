package IF::Interface::CalendarEvent;

# Anything that wants to be treated as an event
# needs to conform to this interface
#
use strict;

sub name {
    IF::Log::warning("IF::Interface::CalendarEvent method name has not been overridden");
}

sub date {
    IF::Log::warning("IF::Interface::CalendarEvent method date has not been overridden");
}

sub dates {
    IF::Log::warning("IF::Interface::CalendarEvent method dates has not been overriden");
}

sub time {
    IF::Log::warning("IF::Interface::CalendarEvent method time has not been overridden");
}

sub utc {
    IF::Log::warning("IF::Interface::CalendarEvent method utc has not been overridden");
}

# TODO flesh out with timezone, location and
# recurrence information
1;
