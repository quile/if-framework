package IF::Component::_Admin::Editor::YesNo;

use strict;
use base qw(
    IF::Component
);

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->setAllowsNoSelection();
}

sub name    { return $_[0]->{name}  }
sub setName { $_[0]->{name} = $_[1] }
sub value    { return $_[0]->{value}  }
sub setValue { $_[0]->{value} = $_[1] }
sub isNegated    { return $_[0]->{isNegated}  }
sub setIsNegated { $_[0]->{isNegated} = $_[1] }
sub allowsNoSelection    { return $_[0]->{allowsNoSelection}  }
sub setAllowsNoSelection { $_[0]->{allowsNoSelection} = $_[1] }


sub negatedValue {
    my $self = shift;
    return 0 if $self->{value};
    return 1;
}

sub setNegatedValue {
    my $self = shift;
    $self->{value} = !int(shift);
}


sub Bindings {
    return {
        YES_NO_POPUP => {
            type => "PopUpMenu",
            bindings => {
                list => q([
                    { KEY => "1", VALUE => "Yes", },
                    { KEY => "0", VALUE => "No", },
                ]),
                displayString => q("VALUE"),
                value => q("KEY"),
                selection => q(value),
                allowsNoSelection => q(allowsNoSelection),
                name => q(name),
            },
        },
        IS_NEGATED => {
            type => "BOOLEAN",
            value => q(isNegated),
        },
        NO_YES_POPUP => {
            type => "PopUpMenu",
            bindings => {
                list => q(
                    { KEY => "1", VALUE => "Yes", },
                    { KEY => "0", VALUE => "No", },
                ),                
                displayString => q("VALUE"),
                value => q("KEY"),
                selection => q(negatedValue),
                allowsNoSelection => q(allowsNoSelection),
                name => q(name),
            },
        },
    };
}
1;
