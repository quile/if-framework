package IF::Component::_Admin::Model::PageWrapper;
use base qw(IF::Component::_Admin);

sub shouldShowWrapper {
    my $self = shift;
    return 1 unless $self->controller();
    return $self->controller()->shouldShowWrapper();    
}

sub controller {
    my $self = shift;
    return $self->{controller};    
}

sub setController {
    my $self = shift;
    $self->{controller} = shift;
}

1;