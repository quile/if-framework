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

package PF::String;

use strict;
use PF::Array;

use overload
	"." => "_stringByConcatenatingStrings",
	'""' => "toString",
	"eq" => "isEqualToString",
	"==" => "isEqualToNumber",
	"cmp" => "compareToString",
	"<=>" => "compareToNumber",
	;

sub import {
	shift;
	return unless @_;
	die "unknown import: @_" unless @_ == 1 and $_[0] eq ':constant';
	overload::constant q => sub {
		my $rawString = shift;
		my $string = shift;
		my $type = shift;
		return PF::String->new($string);
	};
}

sub new {
	my $className = shift;
	my $self = { _string => "" };
	bless $self, $className;
	$self->init(@_);
	return $self;
}

sub init {
	my $self = shift;
	if (scalar @_ == 1) {
		if (UNIVERSAL::isa($_[0], "ARRAY")) {
			$self->initWithArrayOfStrings($_[0]);
		} else {
			$self->initWithString($_[0]);
		}
	} elsif (scalar @_ > 1) {
		$self->initWithArrayOfStrings([@_]);
	}
}

sub initWithString {
	my $self = shift;
	my $string = shift;
	$self->_setString($string);
	return $self;
}

sub initWithArrayOfStrings {
	my $self = shift;
	my $array = shift;
	$self->_setString(join("", @$array));
	return $self;
}

sub initWithContentsOfFile {
	my $self = shift;
	my $filePath = shift;
	if (open (FILE, $filePath)) {
		$self->_setString(join("", <FILE>));
		close (FILE);
	}
	return $self;
}

sub _setString {
	my $self = shift;
	$self->{_string} = shift;
}

sub _string {
	my $self = shift;
	return $self->{_string};
}

sub toString {
	my $self = shift;
	return $self->{_string};
}

sub _stringByConcatenatingStrings {
	my $self = shift;
	my $string = shift;
	my $reversed = shift;
	my $stringClass = ref $self;
	if ($reversed) {
		return $stringClass->new($string.$self->_string());
	}
	return $stringClass->new($self->_string().$string);
}

sub stringByAppendingString {
	my $self = shift;
	my $string = shift;
	return $self->_newInstanceOfSameClassWithParameters($self->_string().$string);
}

sub length {
	my $self = shift;
	return length($self->_string());
}

sub isEqualTo {
	my $self = shift;
	return $self->isEqualToString(@_);
}

sub isEqualToString {
	my $self = shift;
	my $string = shift;
	return ($self->_string() eq $string);
}

sub isEqualToNumber {
	my $self = shift;
	my $number = shift;
	return ($self->_string() == $number);
}

sub componentsSeparatedByString {
	my $self = shift;
	my $separator = shift;
	my @components = split(/$separator/, $self->_string());
	return PF::Array->new(map {$self->_newInstanceOfSameClassWithParameters($_)} @components);
}

sub compareToString {
	my $self = shift;
	my $string = shift;
	my $reversed = shift;

	return ($self->_string() cmp $string) unless $reversed;
	return ($string cmp $self->_string());
}

sub compareToNumber {
	my $self = shift;
	my $number = shift;
	my $reversed = shift;

	return ($self->_string() <=> $number) unless $reversed;
	return ($number <=> $self->_string());
}

sub startsWith {
	my $self = shift;
	my $string = shift;
	return 1 if ($self->_string() =~ /^$string/);
	return 0;
}

sub endsWith {
	my $self = shift;
	my $string = shift;
	return 1 if ($self->_string() =~ /$string$/);
	return 0;
}

sub characterAtIndex {
	my $self = shift;
	my $index = shift;
	return '' unless ($index < $self->length());
	return substr($self->_string(), $index, 1);
}

sub intValue {
	my $self = shift;
	return int($self->_string());
}

sub substringWithRange {
	my $self = shift;
	my $start = shift;
	my $end = shift;

	if ($end < 0) {
		$end = $self->length() + 1 + $end;
	}

	if ($start < 0) {
		$start = $self->length() + 1 + $start;
	}
	my $substring = $self->_newInstanceOfSameClassWithParameters();
	return $substring unless ($start < $end);
	$substring->initWithString(substr($self->_string(), $start, ($end-$start)));
	return $substring;
}

sub substringToIndex {
	my $self = shift;
	my $index = shift;
	return $self->substringWithRange(0, $index);
}

sub substringFromIndex {
	my $self = shift;
	my $index = shift;
	return $self->substringWithRange($index, $self->length());
}

sub copyOfSelf {
	my $self = shift;
	return $self->_newInstanceOfSameClassWithParameters($self->_string());
}

sub _newInstanceOfSameClassWithParameters {
	my $self = shift;
	my $className = ref $self;
	return $className->new(@_);
}

1;
