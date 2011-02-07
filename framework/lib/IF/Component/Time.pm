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

package IF::Component::Time;

use strict;
use base qw(
    IF::Component
);

sub resetValues {
    my ($self) = @_;
    $self->SUPER::resetValues();
    $self->{TIME} = "00:00:00";
}

sub time {
	my $self = shift;
	return $self->{TIME};
}

sub setTime {
	my $self = shift;
	$self->{TIME} = shift;
	if ($self->{TIME} =~ /^[0-9]+$/) {
		# it's a unix time so
		$self->{TIME} = IF::Utility::sqlTimeFromUnixTime($self->{TIME});
	}
	if ($self->{TIME} =~ /^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/) {
		# it's a SQL timestamp so
		$self->{TIME} = substr($self->{TIME}, 11, 8);
	}
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

sub hours {
	my $self = shift;
	my $hours = substr($self->{TIME}, 0, 2);
	return $hours if ($self->isTwentyFourHour());
	$hours = $hours % 12;
	return $hours unless $hours == 0;
	return 12;
}

sub minutes {
	my $self = shift;
	return substr($self->{TIME}, 3, 2);
}

sub seconds {
	my $self = shift;
	return substr($self->{TIME}, 6, 2);
}

sub ampm {
	my $self = shift;

	my $hours = substr($self->{TIME}, 0, 2);
	return "pm" if ($hours > 11);
	return "am";
}

sub isTwentyFourHour {
	my ($self) = @_;
	return $self->{isTwentyFourHour} if $self->{isTwentyFourHour};
	return $self->{isTwentyFourHour} = ($self->context()->language() ne "en");
}

sub setIsTwentyFourHour {
	my ($self, $value) = @_;
	$self->{isTwentyFourHour} = $value;
}

sub showSeconds {
	my $self = shift;
	return $self->{SHOW_SECONDS};
}

sub setShowSeconds {
	my $self = shift;
	$self->{SHOW_SECONDS} = shift;
}

sub timeZone {
	my ($self) = @_;
	return $self->{timeZone};
}

sub setTimeZone {
	my ($self, $value) = @_;
	$self->{timeZone} = $value;
}

1;
