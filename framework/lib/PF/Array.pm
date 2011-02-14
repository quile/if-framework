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

package PF::Array;

use strict;
use overload '""' => "toString",
             '==' => "isEqualTo";

sub new {
    my $className = shift;
    my $self = [];
    bless $self, $className;
    return $self;
}

sub initWithArray {
    my $self = shift;
    my @array = @_;
    $self->removeAllObjects();
    return if (scalar @array == 0);
    $self->addObjectsFromArray([@array]);
    return $self;
}

sub initWithArrayRef {
    my $self = shift;
    my $arrayRef = shift;
    return $self->initWithArray(@$arrayRef);
}

sub addObjectsFromArray {
    my $self = shift;
    my $array = shift;
    return unless UNIVERSAL::isa($array, "ARRAY");
    foreach my $object (@$array) {
        $self->addObject($object);
    }
}

sub removeAllObjects {
    my $self = shift;
    while ($self->length() > 0) {
        shift @$self;
    }
}

sub length {
    my $self = shift;
    return scalar @$self;
}

sub count {
    my $self = shift;
    return $self->length();
}

sub objectAtIndex {
    my $self = shift;
    my $index = shift;
    return $self->[$index];
}

sub removeObjectAtIndex {
    my $self = shift;
    my $index = shift;
    splice (@$self, $index, 1);
}

sub addObject {
    my $self = shift;
    my $object = shift;
    push (@$self, $object);
}

sub removeObject {
    my $self = shift;
    my $object = shift;
    for (my $i=0; $i<$self->length(); $i++) {
        my $selfObject = $self->objectAtIndex($i);
        if (ref($object)) {
            if ($selfObject == $object) {
                $self->removeObjectAtIndex($i);
                $i = 0;
                next;
            }
        } else {
            if ($selfObject eq $object) {
                $self->removeObjectAtIndex($i);
                $i = 0;
                next;
            }
        }
    }
}

sub toString {
    my $self = shift;
    my $string = "[ ";
    foreach my $object (@$self) {
        $string .= $object." ";
    }
    $string .= "]";
    return $string;
}

sub isEqualTo {
    my $self = shift;
    my $object = shift;
    my $reversed = shift;

    return 0 unless (UNIVERSAL::isa($object, 'ARRAY'));
    for (my $i=0; $i<$self->count(); $i++) {
        return 0 unless ($self->objectAtIndex($i) == $object->[$i]);
    }
    return 1;
}

1;
