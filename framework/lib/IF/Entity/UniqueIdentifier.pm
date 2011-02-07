package IF::Entity::UniqueIdentifier;

use strict;
use base qw(
	IF::Dictionary
);
use overload '""' => 'stringValue';
		

sub new {
	my ($className) = @_;
	my $self = $className->SUPER::new();
	bless $self, $className;
}

sub newFromString {
	my ($className, $string) = @_;
	my $self = $className->new();
	my ($e, $p) = split(/\,/, $string, 2);
	$self->setEntityName($e);
	$self->setExternalId($p);
	return $self;
}

sub newFromEntity {
	my ($className, $entity) = @_;
	my $self = $className->new();
	$self->setEntityName($entity->entityClassDescription()->name());
	$self->setExternalId($entity->externalId());
	return $self;
}

sub entityName {
	my ($self) = @_;
	return $self->{entityName};
}

sub setEntityName {
	my ($self, $value) = @_;
	$self->{entityName} = $value;
	$self->{entity} = undef;
}

sub externalId {
	my ($self) = @_;
	return $self->{externalId};
}

sub setExternalId {
	my ($self, $value) = @_;
	$self->{externalId} = $value;
	$self->{entity} = undef;
}

sub stringValue {
	my ($self) = @_;
	return $self->entityName().",".$self->externalId();
}

sub entity {
	my ($self) = @_;
	return $self->{entity} ||= IF::ObjectContext->new()->entityWithUniqueIdentifier($self);
}

1;