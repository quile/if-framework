package IF::Default::Model;

use strict;
use base qw(
    IF::Model
);
use IF::Application;
# 
# sub entityNamespace {
#     my ($self) = @_;
#     return IF::Application->defaultApplication()->configurationValueForKey("DEFAULT_ENTITY_ROOT");
# }
    
sub entityRoot {    
    die "You must subclass entityRoot and specify the path to your entity directory";
}

# this populates the model entries for entities that are
# not mentioned in the model that was loaded from the .pmodel file
sub populateModel {
    my ($self) = @_;
    my $entityDir = $self->entityRoot() 
                || die "No entity root defined";

    IF::Log::debug("Seeking entities in $entityDir");
    my $entities = [];
    opendir(DIR, $entityDir) || die "Can't opendir $entityDir: $!";
    my @names = grep { /^[^.]/ && /\.pm$/ } readdir(DIR);
    closedir DIR;

    my $ecdClass = $self->entityClassDescriptionClassName();
    foreach my $name (@names) {
        $name =~ s/\.pm//g;
        IF::Log::debug("... $name ...");

        my $fqn = $self->{NAMESPACE}->{ENTITY}."::$name";
        IF::Log::debug(" => $fqn");
        eval "use $fqn;";
        if ($@) {
            IF::Log::error($@);
            next;
        }
        if (exists $self->{ENTITIES}->{$name}) {
            IF::Log::debug("Skipping $name, it already exists in the .pmodel");
            next;
        }

        unless ($fqn->isa("IF::Entity::Persistent")) {
            IF::Log::warning("Skipping $name because it's a transient entity");
            next;
        }
        
        unless ($fqn->can("Model")) {
            IF::Log::warning("$fqn is not enhanced with Model-Fu");
            next;
        }
        
        my @m = $fqn->Model();

        $self->{ENTITIES}->{$name} = $fqn->__modelEntryOfClassFromArray($ecdClass, @m);
    }
}

1;