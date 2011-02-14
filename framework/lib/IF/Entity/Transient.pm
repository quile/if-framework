package IF::Entity::Transient;

use strict;
use base qw(
    IF::Entity
);

sub initValuesWithArray {
    my ($self, $valueArray)  = @_;
    my $values = {@$valueArray};
    foreach my $key (keys %$values) {
        $self->setValueForKey($values->{$key}, $key);
    }
}

1;