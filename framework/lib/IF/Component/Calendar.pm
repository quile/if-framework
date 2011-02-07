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

package IF::Component::Calendar;

use strict;
use vars qw(@ISA);
use IF::Component;
@ISA = qw(IF::Component);

sub init {
	my $self = shift;
	$self->setEvents([]);
	$self->SUPER::init();
}

sub defaultAction {
    my $self = shift;
    my $context = shift;
    return undef;
}

sub viewMode {
	my $self = shift;
	return $self->{VIEW_MODE};
}

sub setViewMode {
	my $self = shift;
	$self->{VIEW_MODE} = shift;
}

sub viewSize {
	my $self = shift;
	return $self->{VIEW_SIZE};
}

sub setViewSize {
	my $self = shift;
	$self->{VIEW_SIZE} = shift;
}

sub viewFormat {
	my $self = shift;
	return $self->{VIEW_FORMAT};
}

sub setViewFormat {
	my $self = shift;
	$self->{VIEW_FORMAT} = shift;
}

sub frameWidth {
	my $self = shift;
	return $self->{FRAME_WIDTH};
}

sub setFrameWidth {
	my $self = shift;
	$self->{FRAME_WIDTH} = shift;
}

sub frameColor {
	my $self = shift;
	return $self->{FRAME_COLOR};
}

sub setFrameColor {
	my $self = shift;
	$self->{FRAME_COLOR} = shift;
}

sub headerColor {
	my $self = shift;
	return $self->{HEADER_COLOR};
}

sub setHeaderColor {
	my $self = shift;
	$self->{HEADER_COLOR} = shift;
}

sub cellPadding {
	my $self = shift;
	return $self->{CELL_PADDING};
}

sub setCellPadding {
	my $self = shift;
	$self->{CELL_PADDING} = shift;
}

sub backgroundColor {
	my $self = shift;
	return $self->{BACKGROUND_COLOR};
}

sub setBackgroundColor {
	my $self = shift;
	$self->{BACKGROUND_COLOR} = shift;
}

sub headerCSSClass {
	my $self = shift;
	return $self->{headerCSSClass};
}

sub setHeaderCSSClass {
	my $self = shift;
	$self->{headerCSSClass} = shift;
}

sub eventCSSClass {
	my $self = shift;
	return $self->{eventCSSClass};
}

sub setEventCSSClass {
	my $self = shift;
	$self->{eventCSSClass} = shift;
}

sub noEventCSSClass {
	my $self = shift;
	return $self->{noEventCSSClass};
}

sub setNoEventCSSClass {
	my $self = shift;
	$self->{noEventCSSClass} = shift;
}

sub otherMonthNoEventCSSClass {
	my $self = shift;
	return $self->{otherMonthNoEventCSSClass};
}

sub setOtherMonthNoEventCSSClass {
	my $self = shift;
	$self->{otherMonthNoEventCSSClass} = shift;
}

sub otherMonthEventCSSClass {
	my $self = shift;
	return $self->{otherMonthEventCSSClass};
}

sub setOtherMonthEventCSSClass {
	my $self = shift;
	$self->{otherMonthEventCSSClass} = shift;
}

sub eventViewer {
	my $self = shift;
	return $self->{eventViewer};
}

sub setEventViewer {
	my $self = shift;
	$self->{eventViewer} = shift;
}

sub listViewer {
	my $self = shift;
	return $self->{LIST_VIEWER};
}

sub setListViewer {
	my $self = shift;
	$self->{LIST_VIEWER} = shift;
}

sub events {
	my $self = shift;
	return $self->{EVENTS};
}

sub setEvents {
	my $self = shift;
	$self->{EVENTS} = shift;
}

sub daysOfWeek {
	my $self = shift;
	my $context = shift;

    # TODO i18n
    return [qw(mon tue wed thu fri sat sun)];

    # return $self->{_daysOfWeek} if $self->{_daysOfWeek};
    # my %daysOfWeek = _s()->daysOfWeek($context->language());
    # my $daysOfWeekArray = [];
    # foreach my $dayOfWeek (sort keys %daysOfWeek) {
    #   push (@$daysOfWeekArray, { LONG_NAME => $daysOfWeek{$dayOfWeek}->{LONG},
    #                              SHORT_NAME => $daysOfWeek{$dayOfWeek}->{SHORT},
    #                              ABBREVIATION => $daysOfWeek{$dayOfWeek}->{ABBREVIATION},
    #                              VALUE => $dayOfWeek });
    # }
    # $self->{_daysOfWeek} = $daysOfWeekArray;
    # return $self->{_daysOfWeek};
}

sub days {
	my $self = shift;
	return [];
}

sub date {
	my $self = shift;
	return $self->{DATE};
}

sub setDate {
	my $self = shift;
	$self->{DATE} = shift;
}

sub assignEventsToDays {
	my $self = shift;
	my $days = $self->days();

	my $daysByDate = {};
	foreach my $day (@$days) {
		$daysByDate->{$day->sqlDate()} = $day;
	}

	foreach my $event (@{$self->events()}) {
		foreach my $date (@{$event->dates()}) {
			next unless $daysByDate->{$date->sqlDate()};
			$daysByDate->{$date->sqlDate()}->addEvent($event);
			#IF::Log::debug("Added event ".$event->name()." to day ".$date->sqlDate());
		}
	}
}

sub appendToResponse {
	my $self = shift;
	my $response = shift;
	my $context = shift;

	$self->assignEventsToDays();
	return $self->SUPER::appendToResponse($response, $context);

}

1;
