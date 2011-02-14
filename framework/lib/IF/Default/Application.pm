package IF::Default::Application;

use strict;
use base qw(
    IF::Application
);
use IF::Model;
use IF::DB;
use IF::Log;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    
    # TODO:  This is a stop-gap solution until we make
    # the whole DB interface OO.
    IF::Log::debug("Setting DB information");
    IF::DB::setDatabaseInformation($self->configurationValueForKey("DB_LIST"),
                                   $self->configurationValueForKey("DB_CONFIG"),
                                   );
    IF::Log::debug("Attempting to load default model ".$self->configurationValueForKey("DEFAULT_MODEL"));
    
    no strict 'refs';
    my $modelClass = $self->defaultModelClassName();
    eval "use $modelClass;";
    if ($@) { IF::Log::error($@) }
    
    my $m = $modelClass->new($self->configurationValueForKey("DEFAULT_MODEL"));
    IF::Model->setDefaultModel($m);
    
    # Load up the application's modules and initialise them
    $self->loadModules();
    return $self;
}

sub defaultLanguage {
    my $self = shift;
    unless ($self->{defaultLanguage}) {
        $self->{defaultLanguage} = $self->configurationValueForKey("DEFAULT_LANGUAGE") ||
                            IF::Application->systemConfigurationValueForKey("DEFAULT_LANGUAGE");
    }
    return $self->{defaultLanguage};
}

sub defaultModule {
    my ($self) = @_;
    return $self->configurationValueForKey("DEFAULT_APPLICATION_MODULE")->instance();
}


sub cleanUpTransactionInContext {
    my ($self, $context) = @_;
    
    # perform your transaction cleanup here
    $self->SUPER::cleanUpTransactionInContext($context);
}

sub environmentIsProduction {
    my $self = shift;
    my $environment = $self->configurationValueForKey("ENVIRONMENT");
    return 1 if $environment =~ /^PROD/;
    return 1 if $environment =~ /^ADMIN/;
    return 0;
}

sub loadModules {
    my ($self) = @_;
    
    my $modules = $self->configurationValueForKey("APPLICATION_MODULES");
    return unless (IF::Log::assert(IF::Array->arrayHasElements($modules), "Found at least one application module to initialise"));
    
    foreach my $module (@$modules) {
        eval "use $module";
        if ($@) {
            #IF::Log::error("Module failed to load: $@");
            die "DIED Loading application module $module: $@";
        }
        my $m = $module->new();
        $self->registerModule($m);
    }
}

1;