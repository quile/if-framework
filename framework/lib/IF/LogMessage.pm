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

#=======================================
# Represents a single message in the
# Log message buffer
#=======================================

package IF::LogMessage;

use base qw(
    IF::Interface::KeyValueCoding
);
use Time::HiRes qw(gettimeofday);

sub new {
    my $className = shift;
    my $self = {};
    $self->{TYPE} = shift;
    $self->{MESSAGE} = shift;
    $self->{DEPTH} = shift;
    $self->{CALLER} = shift;
    $self->{TIME} = [ gettimeofday ];

    unless ($self->{CALLER}) {
        $self->{CALLER} = [caller(2)];
        $self->{CALLER}->[2] = [caller(1)]->[2];
    }
    return bless $self, $className;
}

sub type {
    my $self = shift;
    return $self->{TYPE};
}

sub message {
    my $self = shift;
    return $self->{MESSAGE};
}

sub content {
    my ($self) = @_;
    return $self->stringWithEvaluatedKeyPathsInLanguage($self->message(), "en");
}

sub depth {
    my $self = shift;
    return $self->{DEPTH};
}

sub formattedMessage {
    my $self = shift;
    my $width = shift || 50;
    my $message = $self->content();
    my $formattedMessage = "";
    while (length($message) > $width) {
        $formattedMessage .= substr($message, 0, $width);
        if (substr($message, 0, $width) !~ /\w/) {
            $formattedMessage .= " ";
        }
        $message = substr($message, $width);
    }
    $formattedMessage .= $message;
    return $formattedMessage;
}

sub time {
    my $self = shift;
    my ($sec, $min, $hour, $day, $month, $year) = localtime($self->{TIME}->[0]);
    return sprintf("%4d-%02d-%02d %02d:%02d:%02d.%06d", ($year+1900),
            ($month+1), $day, $hour, $min, $sec, $self->{TIME}->[1]);
}

sub callerPackage {
    my $self = shift;
    my $value = $self->{CALLER}->[0];
    return $value unless length($value) > 20;
    return substr($value, 0, 8)."...".substr($value, -8, 8);
}

sub callerMethod {
    my $self = shift;
    my $value = $self->{CALLER}->[3];
    return $value unless length($value) > 40;
    return substr($value, 0, 16)."...".substr($value, -16, 16);
}

sub callerLine {
    my $self = shift;
    my $value = $self->{CALLER}->[2];
    return $value unless length($value) > 20;
    return substr($value, 0, 8)."...".substr($value, -8, 8);
}

1;
