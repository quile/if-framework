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

package IF::Array;

use strict;
use base qw(PF::Array);

# static method

sub isArray {
	my $object = shift;
	return UNIVERSAL::isa($object, "ARRAY");
}

# The naming is broken at this low level; above this
# we always use "array" to refer to an array ref.
sub arrayFromObject {
	my ($className, $object) = @_;
	return IF::Array->new() unless defined $object;
	if (isArray($object)) {
		if (ref($object) eq "ARRAY") {
			return bless $object, "IF::Array";
		}
		return $object;
	}
	return IF::Array->new()->initWithArray($object);
}

sub arrayHasNoElements {
	my ($className, $array) = @_;
	return (!$className->arrayHasElements($array));
}

# This also returns false if the object passed in is not an array
sub arrayHasElements {
	my ($className, $array) = @_;
	return 0 unless ($array);
	return 0 unless isArray($array);
	return 0 if (scalar @$array == 0);
	return 1;
}

1;
