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

package IF::StoredResult;
use strict;
use base qw(IF::FetchSpecification);

sub summaryQualifier {
    my $self = shift;
    return $self->{summaryQualifier};
}

sub setSummaryQualifier {
    my ($self, $value) = @_;
    if ($value) {
        $value->setEntity($self->entityName());
    }
    $self->{summaryQualifier} = $value;
}

sub summaryTable {
    my $self = shift;
    return $self->{summaryTable};
}

sub setSummaryTable {
    my ($self, $value) = @_;
    $self->{summaryTable} = $value;
}

sub qualifier {
    my ($self) = @_;
    if ($self->summaryQualifier()) {
        return IF::Qualifier->and([$self->summaryQualifier(), $self->SUPER::qualifier()]);
    }
    return $self->SUPER::qualifier();
}

# wow, the first destructor in our entire system
sub DESTROY {
    my ($self) = @_;
    if ($self->summaryTable()) {
        IF::DB::executeArbitrarySQL("DROP TABLE IF EXISTS ".$self->summaryTable());
    }
    $self->SUPER::DESTROY();
}

1;