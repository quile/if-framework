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

package IF::GregorianDate;

use strict;
use vars qw(@ISA $SECONDS_PER_DAY $ZERO_DATE_STRING);

use base qw(
    IF::Interface::KeyValueCoding
);

$SECONDS_PER_DAY = 24 * 60 * 60;
$ZERO_DATE_STRING = "0000-00-00 00:00:00";

sub new {
    my $className = shift;
    my $arg = shift;
    my $self = bless {}, $className;
    $self->init($arg);
    return $self;
}

sub init {
    my $self = shift;
    my $arg = shift;

    if ($arg) {
        if ($arg =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/) {
            $self->setYear($1);
            $self->setMonth($2);
            $self->setDay($3);

            if ($arg =~ /^\d\d\d\d-\d\d-\d\d (\d\d):(\d\d):(\d\d)/) {
                $self->setHour($1);
                $self->setMinute($2);
                $self->setSecond($3);
            }
        } else {
            my ($second, $minute, $hour, $day, $month, $year, $dow, $doy, $isdst) = localtime($arg);
            $self->setYear($year + 1900);
            $self->setMonth($month + 1);
            $self->setDay($day);
            $self->setHour($hour);
            $self->setMinute($minute);
            $self->setSecond($second);
            $self->setDayOfWeek($dow);
            $self->setUTC($arg);
        }
    }
    $self->setIsSelected(0);
    $self->setEvents([]);
}

sub day {
    my $self = shift;
    return $self->{DAY};
}

sub setDay {
    my $self = shift;
    $self->{DAY} = shift;
}

sub month {
    my $self = shift;
    return $self->{MONTH};
}

sub setMonth {
    my $self = shift;
    $self->{MONTH} = shift;
}

sub year {
    my $self = shift;
    return $self->{YEAR};
}

sub setYear {
    my $self = shift;
    $self->{YEAR} = shift;
}

sub hour {
    my $self = shift;
    return $self->{HOUR};
}

sub setHour {
    my $self = shift;
    $self->{HOUR} = shift;
}

sub minute {
    my $self = shift;
    return $self->{MINUTE};
}

sub setMinute {
    my $self = shift;
    $self->{MINUTE} = shift;
}

sub second {
    my $self = shift;
    return $self->{SECOND};
}

sub setSecond {
    my $self = shift;
    $self->{SECOND} = shift;
}

sub dayOfWeek {
    my $self = shift;
    return $self->{DAY_OF_WEEK} if $self->{DAY_OF_WEEK};
    $self->{DAY_OF_WEEK} = IF::Utility::dayOfWeekForDate($self->sqlDate());
    return $self->{DAY_OF_WEEK};
}

sub setDayOfWeek {
    my $self = shift;
    $self->{DAY_OF_WEEK} = shift;
}

sub startOfWeek {
    my $self = shift;
    unless ($self->{START_OF_WEEK}) {
        $self->{START_OF_WEEK} = IF::GregorianDate->new(IF::Utility::startOfWeekForDate($self->sqlDate()));
    }
    return $self->{START_OF_WEEK};
}

sub startOfMonth {
    my $self = shift;
    unless ($self->{START_OF_MONTH}) {
        $self->{START_OF_MONTH} = IF::GregorianDate->new(sprintf("%04d-%02d-01",
                                        $self->year(), $self->month()
                                        ));
    }
    return $self->{START_OF_MONTH};
}

sub endOfMonth {
    my $self = shift;
    unless ($self->{END_OF_MONTH}) {
        my $nextMonth;
        my $whichYear;
        if ($self->month() == 12) {
            $nextMonth = 1;
            $whichYear = $self->year() + 1;
        } else {
            $nextMonth = $self->month() + 1;
            $whichYear = $self->year();
        }
        my $firstOfNextMonth = IF::GregorianDate->new(sprintf("%04d-%02d-01", $whichYear, $nextMonth));
        $self->{END_OF_MONTH} = $firstOfNextMonth->dateByAddingDays(-1);
    }
    return $self->{END_OF_MONTH};
}

sub endOfWeek {
    my $self = shift;
    return IF::GregorianDate->new($self->startOfWeek()->utc() + ($SECONDS_PER_DAY * 6));
}

sub dateTime {
    my $self = shift;
    return $self->sqlDate()." ".$self->sqlTime();
}

sub sqlDate {
    my $self = shift;
    return sprintf("%04d-%02d-%02d", int($self->year()), int($self->month()), int($self->day()));
}

sub sqlTime {
    my $self = shift;
    return sprintf("%02d:%02d:%02d", int($self->hour()), int($self->minute()), int($self->second()));
}

sub sqlDateTime {
    my ($self) = @_;
    return $self->sqlDate()." ".$self->sqlTime();
}

sub utc {
    my $self = shift;
    return $self->{UTC} if $self->{UTC};
    $self->{UTC} = IF::Utility::unixTimeFromSQLDateAndTime($self->sqlDate(), $self->sqlTime());
    return $self->{UTC};
}

sub setUTC {
    my $self = shift;
    $self->{UTC} = shift;
}

sub isSelected {
    my $self = shift;
    return $self->{isSelected};
}

sub setIsSelected {
    my $self = shift;
    $self->{isSelected} = shift;
}

sub dateByAddingDays {
    my $self = shift;
    my $days = shift;
    my $normalisedDate = IF::GregorianDate->new($self->sqlDate());
    $normalisedDate->setHour(12);
    my $newDate =  IF::GregorianDate->new($normalisedDate->utc() + $SECONDS_PER_DAY * $days);
    $newDate->setHour($self->hour());
    $newDate->setMinute($self->minute());
    $newDate->setSecond($self->second());
    return $newDate;
}

sub dateBySubtractingDays {
    my $self = shift;
    my $days = shift;
    return $self->dateByAddingDays(-$days);
}

sub events {
    my $self = shift;
    return $self->{_events};
}

sub setEvents {
    my $self = shift;
    $self->{_events} = shift;
}

sub addEvent {
    my $self = shift;
    my $event = shift;
    unless ($self->{_events}) {
        $self->{_events} = [];
    }
    push (@{$self->{_events}}, $event);
    # re-sort the events?
    $self->{_events} = [sort {$a->name() cmp $b->name()} @{$self->{_events}}];
}

sub readableDateForAmericans {
    my ($self) = @_;
    return IF::Utility::readableDateForUnixTime($self->utc()) ." ". $self->hour() .":". $self->minute();
}

1;
