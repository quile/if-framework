package IF::Component::_Admin::Model::EntityDeletionConfirmation;

use strict;
use base qw(IF::Component::_Admin::Model::EntityPage);

sub itemsScheduledForDeletion {
	my $self = shift;
	return [] unless $self->entity();
	my $entities = $self->entity()->entitiesForDeletionByRules();
	unshift @$entities, $self->entity();
	return $entities;
}

sub anItem {
	my $self = shift;
	return $self->{anItem};
}

sub setAnItem {
	my $self = shift;
	$self->{anItem} = shift;
}

sub itemName {
	my $self = shift;
	my $attributes = $self->anItem()->entityClassDescription()->orderedAttributes();
	my $name = $self->anItem()->valueForKey($attributes->[0]->{ATTRIBUTE_NAME});
	return $name || $self->anItem()->id();
}

1;

