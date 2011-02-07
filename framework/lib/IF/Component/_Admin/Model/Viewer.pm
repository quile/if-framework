package IF::Component::_Admin::Model::Viewer;

use strict;
use vars qw(@ISA);
use IF::Component::_Admin;
@ISA = qw(IF::Component::_Admin::Model::EntityPage);

sub init {
	my $self = shift;
	$self->SUPER::init(@_);
	$self->registerAction("manage", "manageAction");
}

sub manageAction {
	my ($self, $context) = @_;
	return unless $self->anEntityClassDescription();
	return $self->controller()->nextPageForManageAction($context);
}

sub entityClassDescriptions {
	my $self = shift;
	return $self->{_entityClassDescriptions} if $self->{_entityClassDescriptions};
	my $model = $self->model();
	my $entityClassKeys = $model->allEntityClassKeys();
	my $entityClasses = [];
	foreach my $key (sort @$entityClassKeys) {
		push (@$entityClasses, $model->entityClassDescriptionForEntityNamed($key));
	}
	$self->{_entityClassDescriptions} = $entityClasses;
	return $self->{_entityClassDescriptions};
}

sub entityClassDescriptionForEntityNamed {
	my $self = shift;
	my $name = shift;
	return $self->model()->entityClassDescriptionForEntityNamed($name);
}

sub anEntityClassDescription {
	my $self = shift;
	return $self->{anEntityClassDescription};
}

sub setAnEntityClassDescription {
	my $self = shift;
	$self->{anEntityClassDescription} = shift;
}

sub entityClassDescription {
	my $self = shift;
	return $self->anEntityClassDescription();	
}

1;
