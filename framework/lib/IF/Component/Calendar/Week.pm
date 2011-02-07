package IF::Component::Calendar::Week;

use strict;
use vars qw(@ISA);
use IF::Component
@ISA = qw(IF::Component::Calendar);

sub days {
	my $self = shift;
	return $self->{_days} if $self->{_days};
	return [] unless $self->date();
	my $days = [];
	my $day = $self->date()->startOfWeek();
	for (my $i=0; $i<7; $i++) {
		if ($day->sqlDate() eq $self->date()->sqlDate()) {
			$day->setIsSelected(1);
		}
		push (@$days, $day);
		$day = $day->dateByAddingDays(1);
	}
	$self->{_days} = $days;
	return $self->{_days};
}

sub eventsForDay {
	my $self = shift;
	my $day = shift;
	
	return [];
}

1;
