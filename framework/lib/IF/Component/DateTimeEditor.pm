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

package IF::Component::DateTimeEditor;

use strict;
use vars qw(@ISA);
use IF::Component;
use IF::GregorianDate;

@ISA = qw(IF::Component);

sub init {
    my $self = shift;
    $self->setDateTime($IF::GregorianDate::ZERO_DATE_STRING);
    return $self->SUPER::init();
}

sub takeValuesFromRequest {
    my $self = shift;
    my $context = shift;
    $self->SUPER::takeValuesFromRequest($context);
    IF::Log::debug("Value of date-time is ".$self->dateTime());
}

sub setDateTime {
    my $self = shift;
    my $dateTime = shift;
    if ($dateTime =~ /^[0-9]+$/) {
        $dateTime = IF::Utility::sqlDateTimeFromUnixTime($dateTime);
    }
    IF::Log::debug("Date time is set to $dateTime");
    $self->{dateTime} = $dateTime;
}

sub dateTime {
    my $self = shift;
    if ($self->isUnixTimeFormat() && $self->{dateTime}) {
        return IF::Utility::unixTimeFromSQLDateAndTime(substr($self->{dateTime}, 0, 10), substr($self->{dateTime}, 11, 8));
    }
    return $self->{dateTime};
}

sub value {
    my $self = shift;
    return $self->dateTime();
}

sub setValue {
    my $self = shift;
    my $value = shift;
    $self->setDateTime($value);
}

sub theDate {
    my $self = shift;
    return substr($self->{dateTime}, 0, 10);
}

sub setTheDate {
    my $self = shift;
    my $date = shift;
    my $time = $self->theTime();
    IF::Log::debug("Setting TheDate to ".$date);
    $self->setDateTime("$date $time");
    IF::Log::debug("date-time is now ".$self->dateTime());
}

sub theTime {
    my $self = shift;
    return substr($self->{dateTime}, 11, 8);
}

sub setTheTime {
    my $self = shift;
    my $time = shift;
    my $date = $self->theDate();
    if (length($date) < 10) {
        $date = "0000-00-00";
    }
    $self->setDateTime("$date $time");
}

sub startYear {
    my $self = shift;
    return $self->{startYear};
}

sub setStartYear {
    my $self = shift;
    $self->{startYear} = shift;
}

sub endYear {
    my $self = shift;
    return $self->{endYear};
}

sub setEndYear {
    my $self = shift;
    $self->{endYear} = shift;
}

sub timeStartsEmpty {
    my $self = shift;
    return 1 if $self->dateTime() eq $IF::GregorianDate::ZERO_DATE_STRING;
    return 0;
}

sub isUnixTimeFormat {
    my $self = shift;
    return $self->{isUnixTimeFormat};
}

sub setIsUnixTimeFormat {
    my $self = shift;
    $self->{isUnixTimeFormat} = shift;
}

sub shouldShowSeconds {
    my $self = shift;
    return $self->{shouldShowSeconds};
}

sub setShouldShowSeconds {
    my $self = shift;
    $self->{shouldShowSeconds} = shift;
}

sub shouldShowClientSideControls {
    my $self = shift;
    return $self->{_shouldShowClientSideControls};
}

sub setShouldShowClientSideControls {
    my $self = shift;
    $self->{_shouldShowClientSideControls} = shift;
}

1;
