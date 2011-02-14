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

package IF::Component::DateEditor;

use strict;
use vars qw(@ISA);
use IF::Component;
use IF::GregorianDate;

@ISA = qw(IF::Component);

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->setDate("0000-00-00");
    $self->setIsUnixTimeFormat(0);
}

sub takeValuesFromRequest {
    my $self = shift;
    my $context = shift;
    $self->SUPER::takeValuesFromRequest($context);
    #IF::Log::debug("Date is now ".$self->date());
    $self->setYear($context->formValueForKey("SYYYY_".$self->name()));
    #IF::Log::debug("Date is now ".$self->date());
    $self->setMonth($context->formValueForKey("SMM_".$self->name()));
    #IF::Log::debug("Date is now ".$self->date());
    $self->setDay($context->formValueForKey("SDD_".$self->name()));
    #IF::Log::debug("Date is now ".$self->date());
}

sub appendToResponse {
    my $self = shift;
    my $response = shift;
    my $context = shift;

    if ($self->date() eq "0000-00-00" && $self->defaultValue()) {
        $self->setDate($self->defaultValue());
    }
    my $returnValue = $self->SUPER::appendToResponse($response, $context);
    $context->setTransactionValueForKey("1", "loaded-date-editor"); #TODO: fix this using RequestContext
    return $returnValue;
}

sub name {
    my $self = shift;
    return $self->{NAME} if $self->{NAME};
    return $self->queryKeyNameForPageAndLoopContexts();
}

sub setName {
    my $self = shift;
    $self->{NAME} = shift;
}

sub daysAsStrings {
    my $self = shift;

    my $days = [map {sprintf("%02d", $_)} (1..31)];
    if ($self->allowsNoSelection()) {
        unshift (@$days, "");
    }
    return $days;
}

sub monthsAsStrings {
    my $self = shift;
    my $context = shift;
    my $monthsAsArray = [];
    foreach my $index (1..12) {
        push (@$monthsAsArray, { index => sprintf("%02d",$index), month => _s("MONTH_$index"), });
    }
    if ($self->allowsNoSelection()) {
        unshift (@$monthsAsArray, { index => "", month => "" });
    }
    return $monthsAsArray;
}

sub yearsAsStrings {
    my $self = shift;

    my $startYear = $self->startYear();
    my $endYear = $self->endYear();

    if ($endYear - $startYear > 100) {
        $endYear = $startYear + 100;
    }
    my @years = ($startYear..$endYear);

    if ($self->allowsNoSelection()) {
        unshift (@years, "");
    }

    return \@years;
}

sub date {
    my $self = shift;
    if ($self->isUnixTimeFormat()) {
        return IF::Utility::unixTimeFromSQLDate($self->{DATE});
    }
    return $self->{DATE};
}

sub setDate {
    my $self = shift;
    my $date = shift;
    if ($date =~ /^[0-9]+$/) {
        $self->{DATE} = IF::Utility::sqlDateFromUnixTime($date);
        return;
    }
    return unless $date;
    $self->{DATE} = $date;
}

# just to keep it legal
sub value {
    my $self = shift;
    return $self->date();
}

sub setValue {
    my $self = shift;
    my $value = shift;
    $self->setDate($value);
}

sub defaultValue {
    my $self = shift;
    return $self->{defaultValue};
}

sub setDefaultValue {
    my $self = shift;
    $self->{defaultValue} = shift;
}

sub year {
    my $self = shift;
    return substr($self->{DATE}, 0, 4);
}

sub setYear {
    my $self = shift;
    my $year = shift;
    substr($self->{DATE}, 0, 4) = sprintf("%04d", $year);
    #IF::Log::debug("Date is now ".$self->date());
}

sub month {
    my $self = shift;
    return substr($self->{DATE}, 5, 2);
    #IF::Log::debug("Date is now ".$self->date());
}

sub setMonth {
    my $self = shift;
    my $month = shift;
    substr($self->{DATE}, 5, 2) = sprintf("%02d", $month);
    #IF::Log::debug("Date is now ".$self->date());
}

sub day {
    my $self = shift;
    return substr($self->{DATE}, 8, 2);
}

sub setDay {
    my $self = shift;
    my $day = shift;
    substr($self->{DATE}, 8, 2) = sprintf("%02d", $day);
}

sub setAllowsNoSelection {
    my $self = shift;
    $self->{_allowsNoSelection} = shift;
}

sub allowsNoSelection {
    my $self = shift;
    return $self->{_allowsNoSelection};
}

sub startYear {
    my $self = shift;
    return $self->{_startYear} if $self->{_startYear};
    return $self->year() if $self->year() && $self->year() ne "0000";
    return $self->currentYear();
}

sub setStartYear {
    my $self = shift;
    $self->{_startYear} = shift;
}

sub endYear {
    my $self = shift;
    return $self->{_endYear} if $self->{_endYear};
    return ($self->currentYear() + 10);
}

sub setEndYear {
    my $self = shift;
    $self->{_endYear} = shift;
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
    return 1 unless $self->context()->transactionValueForKey("loaded-date-editor");
    return 0;
}

sub shouldShowTodayLink {
    my $self = shift;
    return $self->{shouldShowTodayLink};
}

sub setShouldShowTodayLink {
    my $self = shift;
    $self->{shouldShowTodayLink} = shift;
}

sub currentDate {
    my $self = shift;
    unless ($self->{_currentDate}) {
        $self->{_currentDate} = IF::GregorianDate->new(time);
    }
    return $self->{_currentDate};
}

sub currentYear {
    my $self = shift;
    return $self->currentDate()->year();
}

sub currentMonth {
    my $self = shift;
    return $self->currentDate()->month();
}

sub currentDay {
    my $self = shift;
    return $self->currentDate()->day();
}

1;
