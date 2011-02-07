package IF::Component::_Admin::Model::EntityPage;

use strict;
use base qw(IF::Component::_Admin);

sub inflateShit {
	my ($self, $context) = @_;
	$self->setEntityClassDescription(
		 $self->model()->entityClassDescriptionForEntityNamed($context->formValueForKey("entity-class-name"))
									 );
	if ($context->formValueForKey("entity-id")) {
		$self->setEntity($self->objectContext()->entityWithPrimaryKey($self->entityClassDescription()->name(),
				$context->formValueForKey("entity-id")));
	}
	if ($context->formValueForKey("root-entity-id")) {
		$self->setRootEntityClassDescription(
			$self->model()->entityClassDescriptionForEntityNamed($context->formValueForKey("root-entity-class-name"))
										 );
		$self->setRootEntity($self->objectContext()->entityWithPrimaryKey($self->rootEntityClassDescription()->name(),
																	  $context->formValueForKey("root-entity-id")));
		IF::Log::debug("EntityPage: set root entity to: ".$self->rootEntity());
	}
	if (my $relName = $context->formValueForKey("relationship-name")) {
		$self->setRelationshipName($relName);
	}
	if ($context->formValueForKey("controller-class")) {
		$self->setControllerClass($context->formValueForKey("controller-class"));
	}
	if ($context->formValueForKey("return-target-component")) {
		$self->setReturnTargetComponent($context->formValueForKey("return-target-component"));
	}
	$self->setShitHasBeenInflated(1);
}

sub takeValuesFromRequest {
	my ($self, $context) = @_;
	
	$self->inflateShit($context) unless $self->shitHasBeenInflated();
	$self->SUPER::takeValuesFromRequest($context);
}

sub invokeDirectActionNamed {
	my ($self, $directActionName, $context) = @_;
	
	# pushes values into the controller
	if ($self->controller()) {
		foreach my $key qw(entity entityClassDescription rootEntity rootEntityClassDescription) {
			next unless ($self->valueForKey($key));
			next if ($self->controller()->valueForKey($key));
			$self->controller()->setValueForKey($self->valueForKey($key), $key);	
		}
	}
	return $self->SUPER::invokeDirectActionNamed($directActionName, $context);
}

sub controller {
	my $self = shift;
	unless ($self->{_controller}) {
		$self->{_controller} = $self->pageWithName($self->controllerClass());
		IF::Log::debug("Instantiated controller of type ".$self->controllerClass());
	}
	return $self->{_controller};
}

sub setController {
	my ($self,$value) = @_;
	$self->{_controller} = $value;
	return unless $value;
	$self->setControllerClass($value->controllerClass());	
}

sub controllerClass {
	my $self = shift;
	return $self->{controllerClass} || IF::Component::_Admin::Model::EditController::controllerClass();	
}

sub setControllerClass {
	my $self = shift;
	$self->{controllerClass} = shift;
}

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

sub rootEntityClassDescription {
	my $self = shift;
	return $self->{rootEntityClassDescription};
}

sub setRootEntityClassDescription {
	my $self = shift;
	$self->{rootEntityClassDescription} = shift;
}

sub relationshipName {
	my ($self) = @_;
	return $self->{relationshipName};
}

sub setRelationshipName {
	my ($self, $value) = @_;
	$self->{relationshipName} = $value;
}

sub model {
	my $self = shift;
	return IF::Model->defaultModel();
}

sub returnTargetComponent {
	my ($self) = @_;
	return $self->{returnTargetComponent};
}

sub setReturnTargetComponent {
	my ($self, $value) = @_;
	$self->{returnTargetComponent} = $value;
}

sub shitHasBeenInflated {
	my ($self) = @_;
	return $self->{shitHasBeenInflated};
}

sub setShitHasBeenInflated {
	my ($self, $value) = @_;
	$self->{shitHasBeenInflated} = $value;
}

1;