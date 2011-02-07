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

package IF::Component::Tree;

use strict;
use vars qw(@ISA);
use IF::Component;

@ISA = qw(IF::Component);

sub newColumn {
	my $self = shift;
	if ($self->{SMART_COLUMNS}) {
		return ($self->newColumnMarkers()->[$self->{anIndex}]);
	}
	return ($self->{ROWS} &&
		($self->{anIndex}+1) % $self->{ROWS} == 0 &&
		scalar @{$self->{BROWSE_VALUES}} % $self->{ROWS} > 3);
}


sub newColumnMarkers {
	my $self = shift;
	return $self->{_newColumnMarkers} if $self->{_newColumnMarkers};

	my $columnLength = int((scalar @{$self->{BROWSE_VALUES}} / $self->{SMART_COLUMNS}));
	my $remainder = (scalar @{$self->{BROWSE_VALUES}}-($columnLength*$self->{SMART_COLUMNS}));

	my $newColumnsAt = {};
	my $currentStartIndex = 0;
	for (my $column=1; $column<	$self->{SMART_COLUMNS}; $column++) {
		my $newColumnIndex = $currentStartIndex + $columnLength + ($remainder-- > 0? 1:0);
		$newColumnsAt->{$newColumnIndex} = 1;
		$currentStartIndex = $newColumnIndex;
	}

	$self->{_newColumnMarkers} = [];
	for (my $i=0; $i<scalar @{$self->{BROWSE_VALUES}}; $i++) {
		if ($newColumnsAt->{$i+1}) {
			push (@{$self->{_newColumnMarkers}}, 1);
		} else {
			push (@{$self->{_newColumnMarkers}}, 0);
		}
	}
	#IF::Log::dump($self->{_newColumnMarkers});
	return $self->{_newColumnMarkers};
}

sub smartColumns {
	my $self = shift;
	return $self->{SMART_COLUMNS};
}

sub setSmartColumns {
	my ($self, $value) = @_;
	$self->{SMART_COLUMNS} = $value;
}

sub browseValues {
	my $self = shift;
	return $self->{BROWSE_VALUES};
}

sub setBrowseValues {
	my ($self, $value) = @_;
	$self->{BROWSE_VALUES} = $value;
}

sub showNumbers {
	my $self = shift;
	return $self->{SHOW_NUMBERS};
}

sub setShowNumbers {
	my ($self, $value) = @_;
	$self->{SHOW_NUMBERS} = $value;
}

sub columnSpace {
	my $self = shift;
	return $self->{COLUMN_SPACE};
}

sub setColumnSpace {
	my ($self, $value) = @_;
	$self->{COLUMN_SPACE} = $value;
}
1;
