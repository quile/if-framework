package IF::Entity::Fixture;

use strict;
use base qw(
    IF::Entity::Persistent
);

# for now just override these to do nothing
sub save {
    my ($self) = @_;
    # nop
}

sub _deleteSelf {
    my ($self) = @_; 
    # nop
}

sub _table {
    my ($self) = @_;
    return undef;
}

1;