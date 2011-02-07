package IF::Component::Calendar::Month;

use strict;
use vars qw(@ISA);
use IF::Component;
@ISA = qw(IF::Component::Calendar);

sub weeks {
	my $self = shift;
	return $self->{_weeks} if $self->{_weeks};
	return [] unless $self->date();
	my $weeks = [];

	# find the starting date of the first week
	# that includes a day from this month
	my $day = $self->date()->startOfWeek();

	do {
		my $days = $self->daysForWeekStarting($day);
		unshift (@$weeks, { DAYS => $days });
		foreach my $dayInWeek (@$days) {
			push (@{$self->{_days}}, $dayInWeek);
		}
		$day = $day->dateBySubtractingDays(7);
	} while($day->endOfWeek()->month() == $self->date()->month());

	$day = $self->date()->startOfWeek()->dateByAddingDays(7);
	
	while ($day->month() == $self->date()->month()) {
		my $days = $self->daysForWeekStarting($day);
		push (@$weeks, { DAYS => $days });
		foreach my $dayInWeek (@$days) {
			push (@{$self->{_days}}, $dayInWeek);
		}
		$day = $day->dateByAddingDays(7);
	}

	$self->{_weeks} = $weeks;
	return $self->{_weeks};
}

sub days {
	my $self = shift;
	return $self->{_days} if $self->{_days};
	return [];
}

sub daysForWeekStarting {
	my $self = shift;
	my $startOfWeek = shift;
	my $days = [];
	my $day = $startOfWeek;
	for (my $i=0; $i<7; $i++) {
		if ($day->sqlDate() eq $self->date()->sqlDate()) {
			$day->setIsSelected(1);
		}
		push (@$days, $day);
		$day = $day->dateByAddingDays(1);
	}
	return $days;
}

sub appendToResponse {
	my $self = shift;
	my $response = shift;
	my $context = shift;
	$self->weeks() unless $self->{_weeks};
	return $self->SUPER::appendToResponse($response, $context);

}
1;
