package IF::Component::_Admin::Model::EntityRelationshipOrderingEditor;

use strict;
use base qw(
	IF::Component::_Admin::Model::EntityPage
);

sub requiredPageResources {
    my ($self) = @_;
    return [
        IF::PageResource->javascript("/javascript/jquery/ui.core.js"),
        IF::PageResource->javascript("/javascript/jquery/ui.sortable.js"),
    ];
}

sub _setup {
	my ($self,$context) = @_;
	my $entities = [];
	my $relationshipName = $self->relationshipName();
	return unless $relationshipName;
	$entities = $self->rootEntity()->$relationshipName();
	return unless scalar @$entities;
	$self->setEntities($entities);
	$self->setEntityClassDescription($entities->[0]->entityClassDescription());

}

sub defaultAction {
	my ($self,$context) = @_;
	$self->_setup($context);
	return;
}

sub saveOrderingAction {
	my ($self,$context) = @_;
	IF::Log::debug("save ordering action");
	$self->_setup($context);
	my $nextPage = $self->pageWithName("ReusableComponent::ArbitraryContent");
	my $orderedIds = $context->formValuesForKey("element[]");
	unless (scalar @$orderedIds) {
		$nextPage->setValue("failed: no ordering ids found: $orderedIds");
		return $nextPage;
	}
	unless (scalar @{$self->entities()}) {
		$nextPage->setValue("failed: no entities retrieved for ordering");
		return $nextPage;
	}
	my %entityIdPosition;
	for (my $i=0; $i<scalar @$orderedIds; $i++) {
		$entityIdPosition{$orderedIds->[$i]} = $i;
	}
	foreach my $entity (@{$self->entities()}) {
		my $newPosition = $entityIdPosition{$entity->id()};
		if ($newPosition != $entity->position()) {
			$entity->setPosition($newPosition);
			$entity->save();
		}
	}

	$nextPage->setValue("success");
	return $nextPage;
}

sub entities {
	my $self = shift;
	return $self->{entities};
}

sub setEntities {
	my $self = shift;
	$self->{entities} = shift;
}

1;

