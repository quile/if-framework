package IF::Date::Unix;

use strict;
use overload '""' => "stringValue",
	 '0+' => "numericValue",
	 '!=' => "ne",
	 '==' => "eq",
	 '>'  => "gt",
	 '<'  => "lt",
	 '>=' => "gte",
	 '<=' => "lte",
	 '-'  => "minus",
	 '+'  => "plus",
	 '<=>' => \&compare,
	 'cmp' => \&compare,
	 'eq' => 'eq',
	 'ne' => 'ne',
	 'nomethod' => \&wtf;
			
use base qw(
	IF::GregorianDate
);

sub _originFormat    { return $_[0]->{_originFormat} }
sub _setOriginFormat { $_[0]->{_originFormat} = $_[1] }

sub stringValue {
	my $self = shift;
	if ($self->_originFormat() eq "int") {
	    return $self->utc();
	} else {
	    return $self->sqlDateTime();
	}
}

sub numericValue {
	my ($self) = @_;
	return int($self->utc());
}

sub ne {
	my ($self, $other) = @_;
	return ($self->utc() != $other);	
}

sub eq {
	my ($self, $other) = @_;
	return ($self->utc() == $other);	
}

sub gt {
	my ($self, $other) = @_;
	return ($self->utc() > $other);	
}

sub lt {
	my ($self, $other) = @_;
	return ($self->utc() < $other);	
}

sub gte {
	my ($self, $other) = @_;
	return ($self->utc() >= $other);	
}

sub lte {
	my ($self, $other) = @_;
	return ($self->utc() <= $other);	
}

sub compare {
	my ($self, $other, $reversed) = @_;
	if ($reversed) {
		return ($other <=> $self->utc());	
	}
	return ($self->utc() <=> $other);	
}

sub minus {
	my ($self, $foo, $isReversed) = @_;

	if ($isReversed) {
		return ($foo - $self->utc());
	}
	return $self->utc() - $foo;
}

sub plus {
	my ($self, $foo) = @_;
	return $self->utc() + $foo;
}

sub wtf {
	my ($a, $b, $reversed, $op) = @_;
	IF::Log::debug($a, $b, $reversed, $op);
}

1;
