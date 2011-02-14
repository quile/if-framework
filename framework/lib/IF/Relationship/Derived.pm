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

package IF::Relationship::Derived;

use strict;
use base qw(
    IF::Relationship::Modelled
);

sub newFromFetchSpecificationWithName {
    my ($className, $fs, $name) = @_;
    my $self = {
        _fetchSpecification => $fs,
    };
    bless $self, $className;
    $self->setName($name);
    return $self;
}

sub targetEntity {
    my ($self) = @_;
    return $self->fetchSpecification()->entityName();
}

sub targetEntityClassDescription {
    my ($self) = @_;
    return $self->fetchSpecification()->entityClassDescription();
}

sub type {
    return "TO_MANY";
}

# These aren't defined because there's no actual
# relationship: that has to be applied via a
# separate qualifier

sub sourceAttribute {
    return undef;
}

sub targetAttribute {
    return undef;
}

sub fetchSpecification {
    my ($self) = @_;
    return $self->{_fetchSpecification};
}

sub setFetchSpecification {
    my ($self, $value) = @_;
    $self->{_fetchSpecification} = $value;
}

1;