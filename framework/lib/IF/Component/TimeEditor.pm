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

package IF::Component::TimeEditor;

use strict;
use base qw(
    IF::Component
);

sub resetValues {
    my ($self) = @_;
    $self->SUPER::resetValues();
    $self->setTime("00:00:00");
}

sub takeValuesFromRequest {
    my $self = shift;
    my $context = shift;
    $self->SUPER::takeValuesFromRequest($context);
    IF::Log::debug("takeValues: time is ".$self->time());
    # this is commented out because this component should only
    # have takeValues() called when it really is receiving data
    # from a request
    my $hours = $context->formValueForKey("SHH_".$self->name());
    if ($context->formValueForKey("SAP_".$self->name()) eq "pm" &&
        $hours < 12) {
        $hours += 12;
    } elsif ($context->formValueForKey("SAP_".$self->name()) eq "am" &&
        $hours == 12) {
        $hours = 0;
    }
    $self->setHours($hours);
    $self->setMinutes($context->formValueForKey("SMM_".$self->name()));
    $self->setSeconds($context->formValueForKey("SSS_".$self->name()));
    IF::Log::debug("takeValues: time is ".$self->time());
}

sub appendToResponse {
    my $self = shift;
    my $response = shift;
    my $context = shift;
    my $returnValue = $self->SUPER::appendToResponse($response, $context);
    $context->setTransactionValueForKey("1", "loaded-time-editor"); #TODO: fix this using RequestContext
    return $returnValue;
}

sub time {
    my $self = shift;
    if ($self->isUnixTimeFormat()) {
        # there's no such thing as unix time format for a time without a date
        # so we just give the number of seconds since midnight
        return $self->seconds() + 60 * $self->minutes() + 3600 * $self->hours();
    }
    return $self->{TIME};
}

sub setTime {
    my $self = shift;
    my $time = shift;
    if ($time =~ /^[0-9]+$/) {
        $self->{TIME} = IF::Utility::sqlTimeFromUnixTime($time);
        return;
    }
    return unless $time =~ /^\d\d:\d\d:\d\d$/;
    $self->{TIME} = $time;
}

sub value {
    my $self = shift;
    return $self->time();
}

sub setValue {
    my $self = shift;
    my $value = shift;
    $self->setTime($value);
}

sub name {
    my $self = shift;
    return $self->{NAME} || $self->queryKeyNameForPageAndLoopContexts();
}

sub setName {
    my $self = shift;
    $self->{NAME} = shift;
}

sub hours {
    my $self = shift;
    my $hours = substr($self->{TIME}, 0, 2);
    return $hours if ($self->isTwentyFourHour());
    $hours = $hours % 12;
    return $hours unless $hours == 0;
    return 12;
}

sub setHours {
    my $self = shift;
    my $hours = shift;
    substr($self->{TIME}, 0, 2) = sprintf("%02d", $hours);
    IF::Log::debug("Time is now ".$self->time());
}

sub minutes {
    my $self = shift;
    return substr($self->{TIME}, 3, 2);
}

sub setMinutes {
    my $self = shift;
    my $minutes = shift;
    substr($self->{TIME}, 3, 2) = sprintf("%02d", $minutes);
    IF::Log::debug("Time is now ".$self->time());
}

sub seconds {
    my $self = shift;
    return substr($self->{TIME}, 6, 2);
}

sub setSeconds {
    my $self = shift;
    my $seconds = shift;
    substr($self->{TIME}, 6, 2) = sprintf("%02d", $seconds);
    IF::Log::debug("Time is now ".$self->time());
}

sub ampm {
    my $self = shift;

    my $hours = substr($self->{TIME}, 0, 2);
    IF::Log::debug("Time is $self->{TIME}");
    return "pm" if ($hours > 11);
    return "am";
}

sub isTwentyFourHour {
    my $self = shift;
    return ($self->context()->language() ne "en");
}

sub showSeconds {
    my $self = shift;
    return $self->{SHOW_SECONDS};
}

sub setShowSeconds {
    my $self = shift;
    $self->{SHOW_SECONDS} = shift;
}

sub shouldShowSeconds {
    my $self = shift;
    return $self->showSeconds();
}

sub setShouldShowSeconds {
    my $self = shift;
    $self->setShowSeconds(shift);
}

sub allowsNoSelection {
    my $self = shift;
    return $self->{allowsNoSelection};
}

sub setAllowsNoSelection {
    my $self = shift;
    $self->{allowsNoSelection} = shift;
}

sub hoursForSelection {
    my $self = shift;
    my $hours = [1..12];
    if ($self->isTwentyFourHour()) {
        $hours = [0..23];
    }
    if ($self->allowsNoSelection()) {
        unshift (@$hours, "");
    }
    return $hours;
}

sub minutesForSelection {
    my $self = shift;
    my $minutes = [map {sprintf("%02d", $_)} (0..59)];
    if ($self->allowsNoSelection()) {
        unshift (@$minutes, "");
    }
    return $minutes;
}

sub startsEmpty {
    my $self = shift;
    return $self->{startsEmpty};
}

sub setStartsEmpty {
    my $self = shift;
    $self->{startsEmpty} = shift;
}

sub setIsUnixTimeFormat {
    my $self = shift;
    $self->{_isUnixTimeFormat} = shift;
}

sub isUnixTimeFormat {
    my $self = shift;
    return $self->{_isUnixTimeFormat};
}

sub isFirstTimeLoaded {
    my $self = shift;
    return 1 unless $self->context()->transactionValueForKey("loaded-time-editor");
    return 0;
}

sub currentTime {
    my $self = shift;
    unless ($self->{_currentTime}) {
        $self->{_currentTime} = IF::GregorianDate->new(CORE::time);
    }
    return $self->{_currentTime};
}

sub currentHour {
    my $self = shift;
    my $hours = $self->currentTime()->hour();
    return $hours if ($self->isTwentyFourHour());
    $hours = $hours % 12;
    return $hours unless $hours == 0;
    return 12;
}

sub currentMinute {
    my $self = shift;
    return $self->currentTime()->minute();
}

sub currentSecond {
    my $self = shift;
    return $self->currentTime()->second();
}

sub currentAmPm {
    my $self = shift;
    if ($self->currentTime()->hour() >= 12) {
        return "pm";
    }
    return "am";
}

sub shouldShowNowLink {
    my $self = shift;
    return $self->{shouldShowNowLink};
}

sub setShouldShowNowLink {
    my $self = shift;
    $self->{shouldShowNowLink} = shift;
}

1;
