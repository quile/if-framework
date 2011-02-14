package IF::Entity::Modelled;

use strict;

# Dealing with the Chicken-Egg problem
sub import {
    my ($c) = @_;
    my $modelClass = $c;
    #print STDERR $c."\n";
    $modelClass =~ /(.*)::(.*)$/;
    $modelClass = $1."::Model::_".$2;
    no strict 'refs';
    my $i = \@{$c."::ISA"};
    if ($i && scalar @$i > 0 && $i->[0] eq $modelClass) {
        IF::Log::debug("Not pushing model class onto ISA because it's already there");
        return;
    }
    # add model class to the mix
    eval "use $modelClass;";
    
    unless ($@) {
        unshift @$i, $modelClass;
    } else {
        eval "use IF::Entity::Persistent;";
        unshift @$i, "IF::Entity::Persistent";
    }
    #print STDERR join(":", @$i)."\n";
}

1;