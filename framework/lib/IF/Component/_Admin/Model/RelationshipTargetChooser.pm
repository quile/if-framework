package IF::Component::_Admin::Model::RelationshipTargetChooser;

use strict;
use base q(IF::Component::_Admin);

sub list {
    my ($self) = @_;
    unless ($self->{list}) {
        return unless IF::Log::assert($self->sourceEntity() && $self->targetRelationshipName(), "Have entity and relationship");
#        my $targetEntities = $self->sourceEntity()->faultEntitiesForRelationshipNamed($self->targetRelationshipName());
        # TODO - stash this
        my $targetEntities = IF::ObjectContext->new()->allEntities($self->relationship()->targetEntityClassDescription()->name());
        $self->{list} = [ map { {
                'DISPLAY_STRING' => $_->asString(),
                'VALUE' => $_->id()
        }; } @$targetEntities ];
    }
    return $self->{list};
}

#  bites me in the ass every time 
sub shouldAllowOutboundValueForBindingNamed {
    my ($self, $bindingName) = @_;
    IF::Log::debug("RelationshipTargetChooser: parent is checking whether it can sync back for binding $bindingName");
    return not $bindingName =~ /sourceEntity|switchComponentName/;
}

sub sourceEntity {
    my ($self) = @_;
    return $self->{sourceEntity};
}

sub setSourceEntity {
    my ($self, $value) = @_;
    $self->{sourceEntity} = $value;
}

sub targetRelationshipName {
    my ($self) = @_;
    return unless $self->relationship();
    return $self->relationship->name();
}

sub relationship {
    my ($self) = @_;
    return $self->{relationship};
}

sub setRelationship {
    my ($self, $value) = @_;
    $self->{relationship} = $value;
}

sub value {
    my ($self) = @_;
    return $self->{value};
}

sub setValue {
    my ($self,$value) = @_;
    $self->{value} = $value;
}

sub argument {
    my ($self) = @_;
    return $self->{argument};
}

sub setArgument {
    my ($self,$argument) = @_;
    $self->{argument} = $argument;
}

sub name {
    my ($self) = @_;
    return $self->{name};
}

sub setName {
    my ($self,$name) = @_;
    $self->{name} = $name;
}

1;

