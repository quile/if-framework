package IF::Component::_Admin::Model::RecentlyViewedEntities;

use strict;
use vars qw(@ISA);
use IF::Component::_Admin;
@ISA = qw(IF::Component::_Admin);

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->registerAction("clearMenu", "clearMenuAction");
}

sub clearMenuAction {
    my ($self, $context) = @_;
    $context->session()->setSessionValueForKey([], "recentlyViewedEntities");
    return;
}

sub recentlyViewedEntities {
    my $self = shift;
    my $recentlyViewedEntities = $self->context()->session()->sessionValueForKey("recentlyViewedEntities");
    return [] unless $recentlyViewedEntities;
    return $recentlyViewedEntities;
}

sub anEntity {
    my $self = shift;
    return $self->{anEntity};
}

sub setAnEntity {
    my $self = shift;
    $self->{anEntity} = shift;
}

1;