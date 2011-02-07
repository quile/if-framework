package IF::Component::_Admin::Model::Navigation;

use strict;
use vars qw(@ISA);
use IF::Component::_Admin;
@ISA = qw(IF::Component::_Admin);

sub entity {
	my $self = shift;
	return $self->{entity};
}

sub setEntity {
	my $self = shift;
	$self->{entity} = shift;
}

sub entityClassDescription {
	my $self = shift;
	return $self->{entityClassDescription};
}

sub setEntityClassDescription {
	my $self = shift;
	$self->{entityClassDescription} = shift;
}

sub rootEntity {
	my $self = shift;
	return $self->{rootEntity};
}

sub setRootEntity {
	my $self = shift;
	$self->{rootEntity} = shift;
}

sub rootEntityClassName {
	my $self = shift;
	return unless $self->rootEntity();
	return $self->rootEntity()->entityClassDescription()->name();
}

sub entityClassName {
	my $self = shift;
	return $self->{entityClassName};
}

sub setEntityClassName {
	my $self = shift;
	$self->{entityClassName} = shift;
}

sub entityName {
	my $self = shift;
	return $self->nameForEntity($self->entity());
}

sub rootEntityName {
	my $self = shift;
	return $self->nameForEntity($self->rootEntity());
}

sub controller {
	my $self = shift;
	return $self->{controller};
}

sub setController {
	my $self = shift;
	$self->{controller} = shift;	
}

sub nameForEntity {
	my ($self, $entity) = @_;
	return "[unknown]" unless $entity;
	my $attributes = $entity->entityClassDescription()->orderedAttributes();
	return $entity->valueForKey($attributes->[0]->{ATTRIBUTE_NAME});
}

sub shouldShowNavigation {
	my $self = shift;
	return 1 unless $self->controller();
	return $self->controller()->shouldShowNavigationInContext($self->context());	
}

1;

