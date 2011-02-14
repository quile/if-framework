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

package IF::SiteClassifier;

use strict;
use base qw(
    IF::Entity::Persistent
    IF::Interface::Stash
);

use IF::ObjectContext;
use IF::Qualifier;
use IF::BindingDictionary;
use Storable qw(freeze thaw);


my $DEFAULT_SITE_CLASSIFIER;
my $SYSTEM_COMPONENT_NAMESPACE = "IF::Component";
my $BINDINGS_ROOT;
my $SYSTEM_BINDINGS_ROOT;
my $SITE_CLASSIFIER_MAP = {};
my $BINDING_CACHE       = {};
my $TEMPLATE_MAP        = {};
my $COMPONENT_MAP       = {};
my $COMPONENT_LOAD_ATTEMPTS = {};

# ----------- class methods ------------

sub siteClassifierWithName {
    my ($className, $name) = @_;
    my $sc = $SITE_CLASSIFIER_MAP->{name}->{$name};
    unless ($sc) {
        # try to pull the object from memcache if we don't have it
        # (won't have cached bindings etc... but saves a hit on the db)
        $sc = $className->stashedValueForKey('name-'.$name);
        unless ($sc) {
            my $objectContext = IF::ObjectContext->new();
            $sc = $objectContext->entitiesMatchingQualifier("SiteClassifier",
                                    IF::Qualifier->key("name = %@", $name))->[0];
            unless ($sc) {
                IF::Log::error("Failed to fetch a site classifier for $name");
                return undef;
            }
            $className->setStashedValueForKey($sc,'name-'.$name);
            $className->setStashedValueForKey($sc,'scname-'.$sc->componentClassName());
        }
        $SITE_CLASSIFIER_MAP->{name}->{$name} = $sc;
        $SITE_CLASSIFIER_MAP->{componentClassName}->{$sc->componentClassName()} = $sc;
    }
    return $sc;
}

sub siteClassifierWithComponentClassName {
    my ($className, $componentClassName) = @_;
    my $sc = $SITE_CLASSIFIER_MAP->{componentClassName}->{$componentClassName};
    unless ($sc) {
        $sc = $className->stashedValueForKey('scname-'.$componentClassName);
        unless ($sc) {
            my $objectContext = IF::ObjectContext->new();
            $sc = $objectContext->entitiesMatchingQualifier("SiteClassifier",
                                    IF::Qualifier->key("componentClassName = %@", $componentClassName))->[0];
            unless ($sc) {
                IF::Log::error("Failed to fetch a site classifier for compnent class name $componentClassName");
                return undef;
            }
            $className->setStashedValueForKey($sc,'name-'.$sc->name());
            $className->setStashedValueForKey($sc,'scname-'.$componentClassName);
        }
        $SITE_CLASSIFIER_MAP->{componentClassName}->{$componentClassName} = $sc;
        $SITE_CLASSIFIER_MAP->{name}->{$sc->name()} = $sc;
    }
    return $sc;
}

sub defaultSiteClassifierForApplication {
    my ($className, $application) = @_;
    unless ($DEFAULT_SITE_CLASSIFIER) {
        my $defaultSiteClassifierName = $application->configurationValueForKey("DEFAULT_SITE_CLASSIFIER_NAME");
        if (IF::Log::assert($defaultSiteClassifierName, "Default site classifier is defined in app config")) {
            $DEFAULT_SITE_CLASSIFIER = $className->siteClassifierWithName($defaultSiteClassifierName);
        }

        # if we still don't have one, return undef.  This will be caught by the context
        # which will bail.
        return undef unless $DEFAULT_SITE_CLASSIFIER;
    }
    return $DEFAULT_SITE_CLASSIFIER;
}

# -------------------- instance methods -------------------

sub parent {
    my $self = shift;
    return $self->faultEntityForRelationshipNamed("parent");
}

sub children {
    my $self = shift;
    return $self->faultEntitiesForRelationshipNamed("children");
}

sub willBeDeleted {
    my $self = shift;

    # make sure all the children now point to the
    # parent of the site classifier that's being
    # deleted:
    foreach my $child (@{$self->children()}) {
        next unless $child;
        $child->setParentId($self->parentId());
        $child->save();
    }

    $self->deleteStashedValueForKey('name-'.$self->name());
    $self->deleteStashedValueForKey('scname-'.$self->componentClassName());

    $self->SUPER::willBeDeleted();
}

sub parentId {
    my $self = shift;
    return $self->storedValueForKey("parentId");
}

sub setParentId {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "parentId");
}

sub hasParent {
    my $self = shift;
    return ($self->parentId() != 0);
}

sub name {
    my $self = shift;
    return $self->storedValueForKey("name");
}

sub setName {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "name");
}

sub defaultBindFileName {
    my $self = shift;
    return "Default";
}

sub path {
    my $self = shift;
    return $self->componentClassName();
}

# Now that templates are not in a separate "Sites" directory,
# we need to classify only the perl class path:
sub componentPath {
    my $self = shift;
    return $self->componentClassName();
}

sub defaultLanguage {
    my $self = shift;
    return $self->storedValueForKey("defaultLanguage");
}

sub setDefaultLanguage {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "defaultLanguage");
}

sub componentClassName {
    my $self = shift;
    return $self->storedValueForKey("componentClassName");
}

sub setComponentClassName {
    my $self = shift;
    my $value = shift;
    $self->setStoredValueForKey($value, "componentClassName");
}

sub languages {
    my $self = shift;
    return [split(":", $self->storedValueForKey("languages"))];
}

sub setLanguages {
    my $self = shift;
    my $values = shift;
    unless (IF::Array::isArray($values)) {
        $values = [$values];
    }
    $self->setStoredValueForKey(join(":", @$values), "languages");
}

sub hasLanguage {
    my $self = shift;
    my $language = shift;
    unless ($self->{_languageMap}) {
        $self->{_languageMap} = {};
        foreach my $l (@{$self->languages()}) {
            $self->{_languageMap}->{$l} = 1;
        }
    }
    return exists $self->{_languageMap}->{$language};
}

sub listOfAncestors {
    my $self = shift;
    return [] unless $self->hasParent();
    return [$self->parent(), @{$self->parent()->listOfAncestors()}];
}

sub resolutionOrder {
    my $self = shift;
    return [$self, @{$self->listOfAncestors()}];
}

sub defaultBindings {
    my $self = shift;
    return $self->{_defaultBindings};
}

sub setDefaultBindings {
    my ($self, $value) = @_;
    $self->{_defaultBindings} = $value;
}

# site classifiers now become responsible for the resolution of the template/binding/class for a
# given name

sub relativeNameForComponentName {
    my ($self, $componentName) = @_;
    return $componentName if (pathIsSystemPath($componentName));
    my $componentClassName = $self->componentClassName();
    if ($componentName =~ /^$componentClassName\:\:(.+)$/) {
        return $1;
    }
    if ($self->hasParent()) {
        return $self->parent()->relativeNameForComponentName($componentName);
    }
    return $componentName;
}

my $SYSTEM_TEMPLATE_ROOT;
sub bestTemplateForPathAndContext {
    my ($self, $path, $context) = @_;

    my $languageToken;
    my $application;
    my $preferredLanguages;

    if ($context) {
        $application = $context->application();
        $languageToken = $context->preferredLanguagesForTransactionAsToken();
        $preferredLanguages = $context->preferredLanguagesForTransaction();
    } else {
        $application = IF::Application->defaultApplication();
        $languageToken = $application->configurationValueForKey("DEFAULT_LANGUAGE");
        $preferredLanguages = [$languageToken];
    }

    my $templateLookupKey = join("/", $languageToken, $self->name(), $path);
    $SYSTEM_TEMPLATE_ROOT ||= IF::Application->systemConfigurationValueForKey("SYSTEM_TEMPLATE_ROOT");

    if (my $cachedTemplatePath = $TEMPLATE_MAP->{$templateLookupKey} ) {
        #IF::Log::debug("Short-circuiting template search, returning cached template at $cachedTemplatePath");
        my $t = IF::Template::cachedTemplateForPath($cachedTemplatePath);
        return $t if $t;
        #IF::Log::debug("Didn't find cached template in the template cache, so just loading it directly");
        # SW: This should be rare, I've pushed the config lookup down here to avoid calling it in
        # the heavy traffic bit of this method above
        my $shouldCacheTemplates = IF::Application->systemConfigurationValueForKey("SHOULD_CACHE_TEMPLATES");
        $t = IF::Template->new(filename => $cachedTemplatePath,
                                cache => $shouldCacheTemplates,
                            );
        return $t if $t;
        #IF::Log::debug("Couldn't load it directly, so falling back to regular search paths");
    }

    my $checkedLanguages = {};
    my $template;
    my $templateRoot = $application->configurationValueForKey("TEMPLATE_ROOT");
    my $shouldCacheTemplates = IF::Application->systemConfigurationValueForKey("SHOULD_CACHE_TEMPLATES");

    # resolution path for templates is different than components or bindings
    # because we resolve by language first.  Therefore, we check for a template in
    # language X until we have exhausted all possibilities, then go to the
    # next language

    foreach my $language (@$preferredLanguages) {
        my $sc = $self;
        next if $checkedLanguages->{$language};
        $checkedLanguages->{$language} += 1;

        while (1) {
            my $scPath = $sc->path();

            my $scRoot = join("/", $templateRoot, $scPath, lc($language));
            IF::Log::debug("Looking for template $path in $scRoot ");

            #IF::Log::debug("Trying to load template $path for language $language in $scRoot");
            $template = IF::Template->new(filename => $path,
                                            path => [
                                                $scRoot,
                                            ],
                                            cache => $shouldCacheTemplates,
                                        );

            last if $template;
            if ($sc->hasParent()) {
                $sc = $sc->parent();
            } else {
                last;
            }
        }

        if ($template) {
            last;
        }
        #IF::Log::debug("Didn't find template for language $language");
    }

    # If we still haven't found it, try the system templates:
    if (!$template) {
        #IF::Log::debug("Trying to load $path from $SYSTEM_TEMPLATE_ROOT");
        $template = IF::Template->new(filename => $path,
                                        path => [
                                            $SYSTEM_TEMPLATE_ROOT."/IF",
                                            $templateRoot."/IF", # TODO UN-harcode this!
                                        ],
                                        cache => $shouldCacheTemplates,
                                    );
        if ($template) {
            IF::Log::debug("Found system template");
        }
    }

    if (!$template) {
         IF::Log::error("no template file found for $path");
    } else {
        if (IF::Application->systemConfigurationValueForKey("SHOULD_CACHE_TEMPLATE_PATHS")) {
            $TEMPLATE_MAP->{$templateLookupKey} = $template->fullPath();
        }
    }

    return $template;
}

sub bindingsForPathInContext {
    my ($self, $path, $context, $inheritanceContext) = @_;

    $inheritanceContext ||= IF::Dictionary->new();

    # we need to strip off the site classifier prefix from the path
    # if it was included
    my $scPrefix = $self->path();
    # ISSUE: 2326....Could not have a SiteClassifier with the same name as a Component
    # since it was requiring 0 or more /....this makes the / required.
    $path =~ s!^$scPrefix/!!;

    my $hashKey = join("/", $scPrefix, $path);

    # for bindings, we search until we find one, and then follow the inheritsFrom
    # tree

    if ($BINDING_CACHE->{$hashKey}) {
        #IF::Log::debug("Returning cached bindings for $hashKey");
        return $BINDING_CACHE->{$hashKey};
    }

    my $application = $context? $context->application() : IF::Application->defaultApplication();

    # now we start checking from this site classifier and continue up the
    # site classifier tree until we find one
    my $bindingsRoot = $application->configurationValueForKey("BINDINGS_ROOT");

    $SYSTEM_BINDINGS_ROOT ||= IF::Application->systemConfigurationValueForKey("FRAMEWORK_ROOT")."/lib";

    IF::Log::debug($bindingsRoot.":".$self->path().":".$path);

    my $bindFile = $bindingsRoot.'/'.$self->path().'/'.$path.'.bind';
    my $bindings = $self->_bindingGroupForFullPathInContext($bindFile, $context, $inheritanceContext);

    unless (scalar @$bindings) {
        if ($self->hasParent()) {
            $bindings = [$self->parent()->bindingsForPathInContext($path, $context, $inheritanceContext)];
        }
    }

    if (@$bindings == 0) {
        # Check the system bindings since we haven't located anything yet
        #my $systemBindFile = $bindingsRoot.'/IF/'.$path.'.bind';
        my $systemBindFile = $SYSTEM_BINDINGS_ROOT."/IF/Component/$path.bind";
        #IF::Log::debug("Loading system bind file $systemBindFile if possible");
        my $systemBindingGroup = $self->_bindingGroupForFullPathInContext($systemBindFile, $context, $inheritanceContext);
        if (scalar @$systemBindingGroup) {
            $bindings = $systemBindingGroup;
            #IF::Log::debug("Successfully loaded system binding group $systemBindFile");
        }
    }

    my $bindingsHash = {};
    #IF::Log::dump($bindings);
    if (scalar @$bindings == 0) {
        IF::Log::warning("Couldn't load bindings for $path");
        return {};
    }
    foreach my $binding (reverse @$bindings) {
        $bindingsHash = {%$bindingsHash, %$binding};
    }

    # add them to the bindings cache and return them
    if (IF::Application->systemConfigurationValueForKey("SHOULD_CACHE_BINDINGS")) {
        #IF::Log::debug(" ==> stashing bindings for $path in cache <== ");
        #IF::Log::dump($bindings);
        $BINDING_CACHE->{$hashKey} = $bindingsHash;
    }
    return $bindingsHash;
}

sub _bindingGroupForFullPathInContext {
    my ($self, $fullPath, $context, $inheritanceContext) = @_;

    $inheritanceContext ||= IF::Dictionary->new();

    # This should stop it from exploding.
    if ($inheritanceContext->{$fullPath}) {
        IF::Log::warning("Averting possible infinite recursion in binding resolution of $fullPath");
        return [];
    }

    my $bindings = [];
    my $b;

    my $application = $context? $context->application() : IF::Application->defaultApplication();

    # HACK!  This is to allow a component to store its bindings within the .pm
    # file:
    $BINDINGS_ROOT ||= $application->configurationValueForKey("BINDINGS_ROOT");
    $SYSTEM_BINDINGS_ROOT ||= IF::Application->systemConfigurationValueForKey("FRAMEWORK_ROOT")."/lib";

    my $p = $self->path();
    my $c = $fullPath;
    $c =~ s/\.bind$//g;
    $c =~ s/^$BINDINGS_ROOT\///g;
    $c =~ s/^$SYSTEM_BINDINGS_ROOT\///g;
    $c =~ s/^$p\///g;
    $c =~ s/\//::/g;
    # $c should be the component name?

    $c = $self->_bestComponentNameForNameInContext($c, $context);
    eval {
        if ($c && UNIVERSAL::can($c, "Bindings")) {
            my $bd = $c->Bindings();
            if ($bd) {
                IF::Log::debug("Found Bindings() method in $c");
                $b = IF::BindingDictionary->new()->initWithDictionary($bd);
            }
        }
    };
    if ($@) {
        IF::Log::error($@);
    }


    #IF::Log::debug("Trying to load bindings at $fullPath");
    unless ($b) {
        eval {
            $b = IF::BindingDictionary->new()->initWithContentsOfFileAtPath($fullPath);
            $inheritanceContext->{$fullPath}++;
        };
        if ($@) {
            IF::Log::error($@);
        }
    }
    if ($b) {
        push (@$bindings, $b);

        #IF::Log::debug("^^^^^^^^^^^^ Checking for inheritance");
        if ($b->{inheritsFrom}) {
            my $ancestor = $b->{inheritsFrom};
            IF::Log::debug("^^^^^^^^^^^^^^ inherits from $ancestor");
            if ($self->pathIsSystemPath($ancestor)) {
                $ancestor =~ s/$SYSTEM_COMPONENT_NAMESPACE\:\://;
            }
            $ancestor =~ s/::/\//g;

            # TODO bulletproof this... it would be possible and EASY to send this
            # into an infinite spin by having a loop in inheritance (binding A depends on
            # other bindings files that somehow depend on A)

            push (@$bindings, $self->bindingsForPathInContext($ancestor, $context, $inheritanceContext));
        } else {

            # If there's no specific parent, we're at the root of the user-specified
            # inheritance tree, so we will suck in the default binding if it exists
            # making sure we don't get stuck in a resolution loop for the default binding
            # file too...
            my $defaultBinding = $application->configurationValueForKey("DEFAULT_BINDING_FILE");
            if ($defaultBinding && $fullPath !~ /\/$defaultBinding\.bind/) {
                IF::Log::debug("Sucking in default bindings $defaultBinding");
                push (@$bindings, $self->bindingsForPathInContext($defaultBinding, $context, $inheritanceContext));
            }
        }
    }
    return $bindings;
}

sub componentForBindingInContext {
    my ($self, $binding, $context) = @_;

    # Allow the user to specify components as either
    # type => COMPONENT value => bindingClass
    #      or
    # type => bindingClass
    my $bindingClass = $binding->{value} || $binding->{type};
    # Locate the component and the template
    my $componentName = IF::Utility::evaluateExpressionInComponentContext($bindingClass, $self, $context, {'quiet' => 1}) || $bindingClass;

    #IF::Log::debug(" ******** ". $binding->{_NAME} .": $bindingClass, $self, $componentName *********");
    return undef unless IF::Log::assert($componentName, "Component path exists for binding $binding->{_NAME}");

    # we need full classname of component here.
    my $fullComponentClassName = $self->_bestComponentNameForNameInContext($componentName, $context);
    if ($fullComponentClassName) {
        #return $fullComponentClassName->newFromBindingInContext($binding, $context);
        return $fullComponentClassName->newFromBinding($binding);
    }
    return undef;
}

sub componentForNameAndContext {
    my ($self, $componentName, $context) = @_;

    my $component;
    IF::Log::debug(" ++++!!!!++++ $componentName");

#    my $hashKey = join("/", $context->siteClassifier()->name(), $componentName);
    my $hashKey = join("/", $self->name(), $componentName);

    # check the memcache for inflated component
    # if ($self->shouldUseStashedComponents()) {
    #       my $cachedComponent = $self->_stashedComponentForKey($hashKey);
    #       if ($cachedComponent) {
    #           IF::Log::debug("+++ using stashed component");
    #           # TODO it's a shame I have to do this; the context
    #           # should be decoupled.
    #           $cachedComponent->setContext($context);
    #           #$cachedComponent->init(); # this is necessary to set up direct actions etc. - it shouldn't be :(
    #           return $cachedComponent;
    #       }
    # }

    # if we have found this before, we can return an
    # instance of the mapped class
    if ($COMPONENT_MAP->{$hashKey}) {
        my $componentPath = $COMPONENT_MAP->{$hashKey};
        eval {
            #$component = $componentPath->new($context);
            $component = $componentPath->new();
        };
        if ($component) {
            #IF::Log::debug("Returning component from cached path $componentPath for $componentName");
            return $component;
        }
    }

    $component = $self->bestComponentForNameInContext($componentName, $context);

    if ($component) {
        my $componentPath = ref($component);
        #IF::Log::debug("Bingo, found $componentName at $componentPath");
        $COMPONENT_MAP->{$hashKey} = $componentPath;

        # issue 11: stash inflated component
        # if ($self->shouldUseStashedComponents()) {
        #     $self->_setStashedComponentForKey($component, $hashKey);
        # }
    }

    return $component;
}

# issue 11
# sub _setStashedComponentForKey {
#     my ($self, $component, $key) = @_;
#
#     # blank out the context - TODO remove this _context altogether
#     my $_c = $component->context();
#     $component->setContext();
#
#     # stash it for 2 mins - arbitrary
#     # IF::Log::debug("Storing $component with these subcomponents:");
#     #     foreach my $key (%{$component->{_subcomponents}}) {
#     #         IF::Log::debug("$key : ".ref($component->{_subcomponents}->{$key}));
#     #     }
#     #     IF::Log::debug("... and with these registered methods:");
#     #     IF::Log::dump($component->{_directActionDispatchTable});
#
#     $self->setInMemoryCachedComponentForKey($component, $key);
#     #$self->setStashedValueForKeyWithTimeout($component, $key, 120);
#
#     # put the context back
#     $component->setContext($_c);
# }
#
# sub _stashedComponentForKey {
#     my ($self, $key) = @_;
#     #return $self->stashedValueForKey($key);
#     return $self->inMemoryCachedComponentForKey($key);
# }
#
# sub setInMemoryCachedComponentForKey {
#     my ($self, $component, $key) = @_;
#     $self->{_inMemoryComponentCache} ||= {};
#     my $f = freeze $component;
#     $self->{_inMemoryComponentCache}->{$key} = $f;
#     IF::Log::debug("Freezing component and storing in in-memory cache");
# }
#
# sub inMemoryCachedComponentForKey {
#     my ($self, $key) = @_;
#     my $f = $self->{_inMemoryComponentCache}->{$key};
#     if ($f) {
#         IF::Log::debug("Thawing copy of frozen component");
#         return thaw $f; # creates a deep copy
#     }
#     return undef;
# }
#
# sub shouldUseStashedComponents {
#     my ($self) = @_;
#     return $self->{_shouldUseStashedComponents} ||= IF::Application->systemConfigurationValueForKey("SHOULD_STASH_COMPONENTS");
# }

sub _bestComponentNameForNameInContext {
    my ($self, $componentName, $context) = @_;

    my $application = $context? $context->application() : IF::Application->defaultApplication();
    my $componentNamespaces = $application->configurationValueForKey("COMPONENT_SEARCH_PATH");
    my $bestComponentPath;

    foreach my $ns (@$componentNamespaces) {
        my $componentPath = $ns."::";
        #IF::Log::debug("checking $ns");
        if (!$self->pathIsSystemPath($ns) && $self->componentPath()) {
            $componentPath .= $self->componentPath()."::";
        }
        $componentPath .= $componentName;

        # unless ($COMPONENT_LOAD_ATTEMPTS->{$componentPath}) {
        #          $COMPONENT_LOAD_ATTEMPTS->{$componentPath} = 1;
        #          IF::Log::debug("Going to try $componentPath because we haven't yet");
        #          my $load = eval "use $componentPath;";
        #             if ($load) {
        #                 IF::Log::debug("Successfully loaded module $componentPath");
        #             }
        #      }
        if (UNIVERSAL::can($componentPath, "new")) {
            $bestComponentPath = $componentPath;
        } else {
            #IF::Log::debug("Couldn't instantiate $componentPath");
            if ($self->hasParent()) {
                #IF::Log::debug("Didn't find it in site classifier ".$self->name()." so checking parent");
                $bestComponentPath = $self->parent()->_bestComponentNameForNameInContext($componentName, $context);
            }
        }
        last if $bestComponentPath;
    }
    # return undef by design if no workable path is found
    return $bestComponentPath;
}

sub bestComponentForNameInContext {
    my ($self, $componentName, $context) = @_;
    my $resolvedComponentName = $self->_bestComponentNameForNameInContext($componentName, $context);
    if ($resolvedComponentName) {
        return $resolvedComponentName->new();
        #return $resolvedComponentName->new($context);
    } else {
        return undef;
    }
}

sub preferredLanguagesForTemplateResolutionInContext {
    return [];
}

# The default implementation of this just delegates the
# URL generation to the IF::Utility method.  However,
# a site classifier should be able to override generation
# of its URLs, which it can do by overriding this method
sub urlInContextForDirectActionOnComponentWithQueryDictionary {
    my ($self, $context, $directActionName, $componentName, $qd) = @_;
    return IF::Utility::urlInContextForDirectActionOnComponentWithQueryDictionary(
        $context, $directActionName, $componentName, $qd
    );
}

# yikes
sub pathIsSystemPath {
    my ($self, $path) = @_;
    return unless $path;
    return ($path =~ /^IF::Component/);
}

1;
