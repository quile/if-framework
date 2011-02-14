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

package IF::Component::Date;

use strict;
use base qw(
    IF::Component
);
use IF::I18N;


sub resetValues {
    my ($self) = @_;
    $self->SUPER::resetValues();
    $self->{DATE} = "0000-00-00";
}

sub date {
    my $self = shift;
    return $self->{DATE};
}

sub setDate {
    my $self = shift;
    $self->{DATE} = shift;
    if ($self->{DATE} =~ /^[0-9]+$/) {
        # it's a unix time so
        $self->{DATE} = IF::Utility::sqlDateFromUnixTime($self->{DATE});
    }
}

sub value {
    my $self = shift;
    return $self->date();
}

sub setValue {
    my $self = shift;
    my $value = shift;
    $self->setDate($value);
}

sub year {
    my $self = shift;
    return substr($self->{DATE}, 0, 4);
}

sub month {
    my $self = shift;
    return substr($self->{DATE}, 5, 2);
}

sub day {
    my $self = shift;
    return substr($self->{DATE}, 8, 2);
}

sub nameOfDayOfWeek {
    my $self = shift;
    my $date = IF::GregorianDate->new($self->date());
    return _s("DAY_OF_WEEK_".$date->dayOfWeek());
}

sub format {
    my $self = shift;
    return $self->{FORMAT};
}

sub setFormat {
    my $self = shift;
    $self->{FORMAT} = shift;
}

sub shouldShowNameOfDayOfWeek {
    my $self = shift;
    return $self->{shouldShowNameOfDayOfWeek};
}

sub setShouldShowNameOfDayOfWeek {
    my $self = shift;
    $self->{shouldShowNameOfDayOfWeek} = shift;
}

1;
