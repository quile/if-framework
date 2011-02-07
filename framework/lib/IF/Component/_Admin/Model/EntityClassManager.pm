package IF::Component::_Admin::Model::EntityClassManager;

use strict;
use base qw(IF::Component::_Admin::Model::EntityPage);

sub takeValuesFromRequest {
	my $self = shift;
	my $context = shift;
	$self->setEntityClassDescription(
				$self->model()->entityClassDescriptionForEntityNamed(
							$context->formValueForKey("entity-class-name")
																	 )
									 );
	$self->SUPER::takeValuesFromRequest($context);
}

sub relationship {
	my $self = shift;
	return $self->entityClassDescription()->relationshipWithName($self->{aRelationshipName});
}

1;

