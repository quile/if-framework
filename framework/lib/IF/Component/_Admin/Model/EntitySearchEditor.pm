package IF::Component::_Admin::Model::EntitySearchEditor;

use strict;
use vars qw(@ISA);
use IF::Component::_Admin::Model::EntityFieldEditor;
use IF::Dictionary;
@ISA = qw(IF::Component::_Admin::Model::EntityFieldEditor);

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->_setDictionary(IF::Dictionary->new());
}

sub entity {
    my $self = shift;
    return $self->{entity};
}

sub setEntity {
    my $self = shift;
    $self->{entity} = shift;
}

sub _dictionary {
    my $self = shift;
    return $self->{_dictionary};
}

sub _setDictionary {
    my $self = shift;
    $self->{_dictionary} = shift;
}

sub attributes {
    my $self = shift;
    unless ($self->{_attributes}) {
        my $attributes = $self->entityClassDescription()->orderedAttributes();
        $self->{_attributes} = $attributes;
    }
    return $self->{_attributes};
}

sub anAttribute {
    my $self = shift;
    return $self->{anAttribute} || {};
}

sub setAnAttribute {
    my $self = shift;
    $self->{anAttribute} = shift;
}

sub entityClassName {
    my $self = shift;
    return $self->{_entityClassName};
}

sub setEntityClassName {
    my $self = shift;
    $self->{_entityClassName} = shift;
}

sub entityClassDescription {
    my $self = shift;
    return $self->model()->entityClassDescriptionForEntityNamed($self->entityClassName());
}

sub model {
    my $self = shift;
    return IF::Model->defaultModel();
}

1;
