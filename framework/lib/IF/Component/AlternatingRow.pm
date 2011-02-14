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

package IF::Component::AlternatingRow;
use strict;
use base qw(
    IF::Component
);

my $index = 0;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $index = 0;
}

sub evenRowClass {
    my $self = shift;
    return $self->{evenRowClass};
}

sub setEvenRowClass {
    my ($self, $value) = @_;
    $self->{evenRowClass} = $value;
}

sub oddRowClass {
    my $self = shift;
    return $self->{oddRowClass};
}

sub setOddRowClass {
    my ($self, $value) = @_;
    $self->{oddRowClass} = $value;
}

sub index {
    my $self = shift;
    return $self->{index} || $index;
}

sub setIndex {
    my ($self, $value) = @_;
    $self->{index} = $value;
}

sub rowClass {
    my $self = shift;
    return $self->{rowClass} if $self->{rowClass};
    if ($self->index() % 2) {
        return $self->oddRowClass() || "odd-row-default";
    }
    return $self->evenRowClass() || "even-row-default";
}

sub setRowClass {
    my ($self, $value) = @_;
    $self->{rowClass} = $value;
}

sub appendToResponse {
    my ($self, $response, $context) = @_;
    my $return = $self->SUPER::appendToResponse($response, $context);
    $index++;
    $self->setRowClass();
    return $return;
}

1;
