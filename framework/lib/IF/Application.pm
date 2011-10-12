# Copyright (c) 2010 - Action Without Borders
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

package IF::Application;

use strict;
use IF::Log;
use IF::Dictionary;

#==============================

sub _new {
    my $className = shift;
    my $namespace = shift;
    my $self = bless { namespace => $namespace, _modules => {}, }, $className;
    if ($className ne "IF::Application") {
        # load config
        IF::Log::debug("Loading configuration for application $namespace");
        my $config = $self->configuration();
        IF::Log::debug("Initialising $className");
        $self->init();

        if ($self->environmentIsProduction() && $ENV{'MOD_PERL'}) {
            IF::Log::info("Unhooking log message handlers");
            *IF::Log::debug = sub {};
            *IF::Log::info  = sub {};
            *IF::Log::database  = sub {};
            *IF::Log::page  = sub {};
            *IF::Log::stack  = sub {};
            *IF::Log::code  = sub {};
        }
    }
    return $self;
}

sub init {
    my $self = shift;
    $self->initialiseI18N();
}

sub contextClassName {
    return "IF::Context";
}

sub sessionClassName {
    IF::Log::error("You MUST subclass IF::Session and override 'sessionClassName' in your application");
    return undef;
}

sub requestContextClassName {
    IF::Log::error("You MUST subclass IF::RequestContext and override 'requestContextClassName' in your application");
    return undef;
}

sub siteClassifierClassName {
    IF::Log::error("You MUST subclass IF::SiteClassifier and override 'siteClassifierClassName' in your application");
    return undef;
}

sub siteClassifierNamespace {
    IF::Log::error("You MUST subclass IF::SiteClassifier and override 'siteClassifierNamespace' in your application");
    return undef;
}

# This is kind of arbitrary; override it in your app to determine whether or not the app
# is running in "production".
my $_environmentIsProduction;
sub environmentIsProduction {
    my ($self) = @_;
    return ($self->configurationValueForKey("ENVIRONMENT") eq "PROD");
}

# cache the app instances
my $_applications = {};
my $_defaultApplicationName;

sub applicationInstanceWithName {
    my $className = shift;
    my $applicationNameForPath = shift;
    unless ($_applications->{$applicationNameForPath}) {
        # this faults in the framework configuration if it hasn't
        # been loaded yet
        unless ($applicationNameForPath eq "IF") {
            $className->applicationInstanceWithName("IF");
            if (!$_defaultApplicationName) {
                $_defaultApplicationName = $applicationNameForPath;
            }
        }
        my $application;
        eval {
            my $applicationClassName = $applicationNameForPath."::Application";
            $application = $applicationClassName->_new($applicationNameForPath);
        };
        print STDERR $@ if ($@);
        return unless $application;
        $_applications->{$applicationNameForPath} = $application;
        IF::Log::debug("Loaded application configuration for ".$applicationNameForPath);
        IF::Log::dump($application->configuration());
    }
    return $_applications->{$applicationNameForPath};
}

# This doesn't apply any ordering to what's returned.
sub allApplications {
    my $className = shift;
    return [values %{$_applications}];
}

# some shortcuts
sub systemConfiguration {
    my $className = shift;
    return $className->applicationInstanceWithName("IF")->configuration();
}

sub systemConfigurationValueForKey {
    my $className = shift;
    my $key = shift;
    return $className->systemConfiguration()->valueForKey($key);
}

sub configurationValueForKeyInApplication {
    my $className = shift;
    my $key = shift;
    my $applicationNameForPath = shift;
    my $application = $className->applicationInstanceWithName($applicationNameForPath);
    unless ($application) {
        IF::Log::error("Couldn't locate application instance named $applicationNameForPath");
        return;
    }
    return $application->configurationValueForKey($key);
}

# These are primarily designed to support offline apps that
# load the framework outside of apache, and some legacy code
sub defaultApplication {
    my $className = shift;
    return $className->applicationInstanceWithName($_defaultApplicationName);
}

sub defaultApplicationName {
    my $className = shift;
    return $_defaultApplicationName;
}

#instance methods

# The app's name is its namespace.
sub name {
    my ($self) = @_;
    return $self->{namespace};
}

sub namespace {
    my $self = shift;
    return $self->{namespace};
}

sub setNamespace {
    my $self = shift;
    $self->{namespace} = shift;
}

sub configurationValueForKey {
    my $self = shift;
    my $key = shift;
    # configuration() will definitely return at least an empty dictionary
    if ($self->hasConfigurationValueForKey($key)) {
        return $self->configuration()->valueForKey($key);
    }
    return IF::Application->systemConfigurationValueForKey($key);
}

sub hasConfigurationValueForKey {
    my $self = shift;
    my $key = shift;
    my $configuration = $self->configuration();
    return $configuration->hasObjectForKey($key);
}

sub configuration {
    my $self = shift;
    unless ($self->{configuration}) {
        my $configurationClassName = configurationClassForNamespace($self->namespace());
        my $importDirective = "use $configurationClassName;";
        IF::Log::debug($importDirective);
        eval "$importDirective";
        my $configuration = eval '$'.$configurationClassName.'::CONFIGURATION';
        IF::Log::warning($@) if $@;
        unless ($configuration) {
            $self->{configuration} = IF::Dictionary->new();
        } else {
            $self->{configuration} = IF::Dictionary->new($configuration);
        }
    }
    return $self->{configuration};
}

sub configurationClassForNamespace {
    my $namespace = shift;
    return $namespace."::Config";
}

sub errorPageForErrorInContext {
    my $self = shift;
    my $error = shift;
    my $context = shift;

    return "<b>$error</b>"; # YUK!
}

sub redirectPageForUrlInContext {
    my $self = shift;
    my $url = shift;
    my $context = shift;

    return "<b>$url</b>"; # YUK!
}

# This is used in error reporting and redirection.  The reason
# we do this is because if the system yacks and throws an error,
# the page that reports it needs to be able to load the error
# template *without* using the rendering framework, which
# could have caused the yacking in the first place.
sub _returnTemplateContent {
    my ($fullPathToTemplate) = @_;
    IF::Log::debug("Trying to load $fullPathToTemplate");
    if (open (TEMPLATE, $fullPathToTemplate)) {
        my $templateFile = join("", <TEMPLATE>);
        close (TEMPLATE);
        return $templateFile;
    }
    return;
}

sub safelyLoadTemplateWithNameInContext {
    my ($self, $template, $context) = @_;
    return unless $template;
    my $templateRoot = $self->configurationValueForKey("TEMPLATE_ROOT");
    my $language = $context? $context->language() : $self->configurationValueForKey("DEFAULT_LANGUAGE");

    my $siteClassifier = "";
    if ($context && $context->siteClassifier()) {
        my $sc = $context->siteClassifier();
        while ($sc) {
            $siteClassifier = "/".$sc->path();
            my $fullPathToTemplate = join("/", $templateRoot.$siteClassifier, $language, $template);
            my $content = _returnTemplateContent($fullPathToTemplate);
            return $content if $content;
            $sc = $sc->parent();
        }
    } else {
        my $fullPathToTemplate = join("/", $templateRoot, $language, $template);
        return _returnTemplateContent($fullPathToTemplate);
    }
    return "";
}

sub cleanUpTransactionInContext {
    my ($self, $context) = @_;
    # subclass this to perform cleanup after a transaction.
}

# make sure the path is below the project root and does not
# contain any ..'s:

sub pathIsSafe {
    my ($self, $path) = @_;
    return 0 if ($path =~ /\.\./);
    my $projectRoot = $self->configurationValueForKey("APP_ROOT");
    return 1 if ($path =~ /^$projectRoot/);
    return 0;
}

# site classifier goo... disentangling SiteClassifiers
# from the context
# If you add a SiteClassifier instance class, you will
# need to restart your server, because this class caches the
# resolutions of mappings so it doesn't needlessly run the
# expensive require() operation on every request.
my $SITE_CLASSIFIER_CLASS_FOR_NAME = {};
sub siteClassifierWithName {
    my ($self, $name) = @_;
    my $namespace = $self->siteClassifierNamespace();
    my $className = $self->siteClassifierClassName();
    return undef unless IF::Log::assert($className, "Site classifier classname implemented");

    # This loads it from the DB. Note that it's loaded as
    # a plain entity, then blessed into the right instance class.
    my $sc = $className->siteClassifierWithName($name);
    if ($sc) {
        if ($namespace) {
            my $instanceClassName = $namespace."::".$sc->componentClassName();
            unless ($SITE_CLASSIFIER_CLASS_FOR_NAME->{$name}) {
                my $fn = $instanceClassName;
                $fn =~ s!::!/!g;
                $fn .= ".pm";
                eval {
                    local $SIG{__DIE__} = 'DEFAULT';
                    require $fn;
                };
                if ($@) {
                    #IF::Log::warning("Site classifier instance class $instanceClassName not implemented");
                    $SITE_CLASSIFIER_CLASS_FOR_NAME->{$name} = $className;
                } else {
                    $SITE_CLASSIFIER_CLASS_FOR_NAME->{$name} = $instanceClassName;
                }
            }
            unless ($@) {
                IF::Log::debug("Site classifier being blessed into class $SITE_CLASSIFIER_CLASS_FOR_NAME->{$name}");
                bless $sc, $SITE_CLASSIFIER_CLASS_FOR_NAME->{$name};
            }
        }
    } else {
        $sc = $className->defaultSiteClassifierForApplication($self->application());
        unless ($sc) {
            IF::Log::error("Found neither Site Classifier: $name".
            "  or a default classifier.  PROBABLE MIS-CONFIGURATION or DATABASE PROBLEMS");
            return;
        }
    }
    return $sc;
}

sub defaultSiteClassifier {
    my ($self) = @_;
    unless ($self->{defaultSC}) {
        $self->{defaultSC} = return $self->siteClassifierClassName()->defaultSiteClassifierForApplication($self->application());
    }
    return $self->{defaultSC};
}


# This will allow an application to interact with its modules

# You need to override this in your application
sub defaultModule {
    my ($self) = @_;
    IF::Log::error("defaultModule method has not been overridden");
    return undef;
}

sub modules {
    my ($self) = @_;
    return [values %{$self->{_modules}}];
}

sub moduleWithName {
    my ($self, $name) = @_;
    return $self->{_modules}->{$name};
}

sub registerModule {
    my ($self, $module) = @_;
    IF::Log::debug(" `--> registering module ".$module->name());
    $self->{_modules}->{$module->name()} = $module;
}

sub moduleInContextForComponentNamed {
    my ($self, $context, $componentName) = @_;
    foreach my $module (@{$self->modules()}) {
        return $module if ($module->isOwnerInContextOfComponentNamed($context, $componentName));
    }
    IF::Log::debug("Returning default module for $componentName");
    return $self->defaultModule();
}

sub serverName {
    my $self = shift;
    return $self->configurationValueForKey('SERVER_NAME');
}

sub initialiseI18N {
    my ($self) = @_;
    IF::Log::info("Loading I18N modules");
    my $i18nDirectory = $self->configurationValueForKey("APP_ROOT")."/".$self->{namespace}."/I18N"; # TODO make this configurable
    opendir DIR, $i18nDirectory or return IF::Log::info("... No I18N found at $i18nDirectory");
    my @files = grep /\.pm$/, readdir(DIR);
    closedir(DIR);
    foreach my $file (@files) {
        IF::Log::debug(" --> found language module $file");
        $file =~ s/\.pm$//g;
        eval "use ".$self->{namespace}."::I18N::".$file;
        die ($@) if $@;
    }
}

# override this if you want to change the key
sub sessionIdKey {
    my ($self) = @_;
    return $self->{_sessionIdKey} ||= lc($self->name())."-sid";
}

# grab an instance of the mailer here.  You can use it to send mail, but you need to be sure that you
# have all the right bits set in your application's configuration.
sub mailer {
    my ($self) = @_;
    # defer loading of the mailer until now to make it easier for all the classes to load and initialise first.
    eval "use IF::Mailer;";
    return $self->{_mailer} ||= IF::Mailer->new()->initWithApplication($self);
}

# by default all addresses are UNSAFE.  you need to implement this in your
# application subclass so you can send email to people other than the
# site administrator.
sub emailAddressIsSafe {
    my ($self, $address) = @_;
    return 1 if ($address eq $self->configurationValueForKey("SITE_ADMINISTRATOR"));
    return 0;
}

# TODO - rename this and group the mail-specific methods somehow.
# This needs help; we need to have some config directives with things like
# returned-mail address format, and the different types?
sub createBounceAddress {
    my $self = shift;
    my $to = shift;
    my $from = shift;
    my $type = shift;
    my $bounceaddr;

    $type = 'if' unless $type;
    $to =~ s/\@/\=/;
#    $bounceaddr = $type.'+'.$to.'@returnedmail.foo.com';
    $bounceaddr = $type.'+'.$to;

    return $bounceaddr;
}

1;