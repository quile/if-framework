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

package IF::Component;

use strict;
use vars qw(
			$COMPONENT_CONTENT_MARKER
			$TAG_ATTRIBUTE_MARKER
			$REGION_TAG_MARKER
			$SYSTEM_BINDING_TYPES
			$TEMPLATE_IS_CACHED
			$BINDING_CACHE
			$TEMPLATE_MAP
			$DIRECT_ACTION_DISPATCH_TABLE
			);

use base qw(
    IF::Interface::KeyValueCoding
    IF::Interface::PageResourceHandling
);
#====================
use IF::ObjectContext;
use IF::Utility;
use IF::Array;
use IF::Response;
use IF::Request::Offline;
use IF::Context;
use IF::Template;
use IF::I18N;
#====================
use File::Basename;
use Time::Local;
use JSON;


# It would be way better if this data resided on the classes themselves
# rather than here, but perl doesn't have inheritable class data... ugh.
$IF::Component::DIRECT_ACTION_DISPATCH_TABLE = {};

# These are returned by "CONTENT" and "ATTRIBUTES" bindings
# and are handled by the including component
$COMPONENT_CONTENT_MARKER = '%_COMPONENT_CONTENT_%';
$TAG_ATTRIBUTE_MARKER     = '%_TAG_ATTRIBUTES_%';
$REGION_TAG_MARKER		  = '<REGION NAME="%s">';

# WARNING: This MUST be maintained or the bindings
# will not get correctly resolved.  If you add another
# system binding type, you need to add it in here too.
$SYSTEM_BINDING_TYPES = {
    LOCALIZED_STRING => 1,
	STRING => 1,
	BOOLEAN => 1,
	DATE => 1,
	COMPONENT => 1,
	CONTENT => 1,
	PREFIX => 1,
	ASSOCIATION => 1,
	LOOP => 1,
	CONSUMER => 1,
	NUMBER => 1,
	ATTRIBUTES => 1,
	REGION => 1,
	SUBCOMPONENT_REGION => 1,
};

$TEMPLATE_IS_CACHED = {};
$BINDING_CACHE = {};

sub _new {
    my ($className, $context) = @_;

    # Temporary: deprecating the passing-in of the context:

    if ($context) {
        IF::Log::error("Deprecated: context passed into component instantiation");
        IF::Log::stack(4);
        die "BANG!";
    }

	my $self = {
	#	_context => $context,
        _context => undef,
		_bindings => undef,
		_didLoadBindings => 0,
		_subcomponents => {},
		_parentBindingName => undef,
		_synchronizesBindingsWithParent => 1,
		_synchronizesBindingsWithChildren => 1,
		_pageContextNumber => 1,
		_hasRegions => 0,
		_regions => {},
		_regionCounters => {},
		_regionCache => {},
		_tagAttributes => {},
		_directActionDispatchTable => undef,
		_overrides => {},
	};
	return bless $self, $className;
}

sub new {
    my ($className, $context) = @_;
    my $self = $className->_new($context);
	#$self->loadBindings();
	$self->init();
	return $self;
}

# We need the context because the resolution of the bindings is
# different depending on the contextual information, such as
# site classifier or language.
#sub newFromBindingInContext {
sub newFromBinding {
    my ($className, $binding) = @_;
    my $self = $className->_new();
    $self->{_pageContextNumber} = $binding->{_defaultPageContextNumber};

    # i would prefer to have these happen after the construction phase, but oh well.
    #$self->loadBindings();
    $self->init();
    return $self;
}

sub init {
	my $self = shift;
	my $package = ref($self);

	# reset values of component
	$self->resetValues();

	# This check is hopelessly cheezy
	return if ($self->{_directActionDispatchTable});
	return if ($DIRECT_ACTION_DISPATCH_TABLE->{$package}->{_loaded});

	#IF::Log::debug("=============== trolling symbol table of $package for actions =============");
	my $methods = IF::Utility::methodsInPackage($package);
	foreach my $symbol (@$methods) {
		#IF::Log::debug("...$symbol...");
		next unless $symbol =~ /([A-Za-z0-9_]+)Action$/o;
		next if ($symbol eq "registerAction");
		next if ($symbol eq "defaultAction");
		next if ($symbol eq "actionMethodForAction");
		my $actionName = $1;

		# this check ensures that a preceding call to registerAction
		# won't be stepped on
		unless ($self->actionMethodForAction($actionName)) {
			IF::Log::debug("Registering unregistered action $actionName as $symbol on $package");
			$self->registerAction($actionName, $symbol);
		}
	}
	$DIRECT_ACTION_DISPATCH_TABLE->{$package}->{_loaded} = 1;
}

# the template name for this component.
# you could override this, conceivably.
sub templateName {
    my ($self) = @_;
    return $self->{_templateName} ||= __templateNameFromComponentName(
        $self->componentNameRelativeToSiteClassifier()
    );
}

# You can override this to map a template name to another
# template at render time.
sub mappedTemplateNameFromTemplateNameInContext {
    my ($self, $templateName, $context) = @_;
	return $templateName;
}

sub loadBindings {
	my $self = shift;

	my $componentName = $self->componentNameRelativeToSiteClassifier();

	$componentName =~ s/::/\//g; # TODO: need a convenience for this!
#	$self->{_bindings} = $self->context()->siteClassifier()->bindingsForPathInContext($componentName, $self->context());
	$self->{_bindings} = $self->_siteClassifier()->bindingsForPathInContext($componentName, $self->context());
	return unless (IF::Log::assert($self->{_bindings}, "Loaded bindings for $componentName"));

    $self->{_didLoadBindings} = 1;
    # we've loaded the bindings hash, so now we number the component
    # bindings in alpha order to generate the page context numbers

    my $c = 0;
	foreach my $bindingKey (sort keys %{$self->{_bindings}}) {
	    next if $bindingKey eq "inheritsFrom"; # TODO stash this literal in one place!
		my $binding = $self->bindingForKey($bindingKey);
		next unless (exists($binding->{type}));
		$binding->{_NAME} = $bindingKey;	# This is so that the binding
										# can identify itself
		next unless $binding;
		if ($self->bindingIsComponent($binding)) {
		    # number the binding, but do not inflate
		    # the component; it's an extremely expensive
		    # operation that we don't need to do yet.

            $self->{_bindings}->{$bindingKey}->{_index} = $c;
            $self->{_bindings}->{$bindingKey}->{_defaultPageContextNumber} = $self->pageContextNumber()."_$c";

            # if the binding has an "overrides" property, it will be used
            # to replace any subcomponents in the tree matching the name
            # set in this property.
            # eg.  overrides => "RIGHT_NAVIGATION_0",
            #
            if ($binding->{overrides}) {
                $self->{_overrides}->{$binding->{overrides}} = $binding;
            }
            $c++;
		}
	}
    # remove the 'inheritsFrom' designation from the bindings
    # dictionary if it's there so we don't need to check for it
    # in the future
    delete $self->{_bindings}->{inheritsFrom};
}

# Man, a state machine.  Weird.  This needs to be unwound into
# a real state machine as it's essentially a huge switch statement
# right now

sub appendToResponse {
    my ($self, $response, $context) = @_;

    if ($context) {
        $self->{_context} = $context;
    }

    # add any page resources that the component is requesting:
    my $renderState = $response->renderState();
    $self->_setRenderState($renderState);
	$renderState->addPageResources($self->requiredPageResources());

	if ($context && $context->session()) {
		my $requestContext = $context->session()->requestContext();
		unless ($requestContext->callingComponent()) {
			$requestContext->setCallingComponent($self->componentName());
		}
	}

	# this is now guaranteed to exist if we got this far (checked in responseFromContext)
	my $template = $response->template();

	unless ($template) {
		# what to do here?
		delete $self->{_context};
		$self->_setRenderState();
		die "Couldn't find template for response";
	}

	my $pregeneratedContent = {};
	my $flowControl = {};
	my $loops = {};
	my $currentLoopDepth = 0;
	my $regionCache = {};
	my $loopContextVariables = {
		__ODD__ => 1,
		__EVEN__ => 2,
		__FIRST__ => 3,
		__LAST__ => 4,
	};

	my @legacyLoops = ();
	for (my $i=0; $i<$template->contentElementCount();) {
		my $contentElement = $template->contentElementAtIndex($i);
		if (exists($pregeneratedContent->{int($i)})) {
			$response->appendContentString($pregeneratedContent->{int($i)});
			delete $pregeneratedContent->{int($i)};
		}
		if (exists ($flowControl->{int($i)})) {
			if ($flowControl->{int($i)}->{command} eq "SKIP") {
				$i = $flowControl->{int($i)}->{index};
			}
			delete $flowControl->{int($i)};
			next;
		}
		if (ref $contentElement) {
			my $value;
			if ($contentElement->{BINDING_TYPE} eq "BINDING") {
				if ($contentElement->{IS_END_TAG}) {
					$i += 1;
					next;
				}
				if ($contentElement->{BINDING_NAME} =~ /^__LEGACY__(.*)$/) {
					my $varName = $1;
					# fish through current loops
					my $highestMatchedLoop = 0;
					foreach my $loopName (keys %$loops) {
						my $item = $self->valueForKey($loops->{$loopName}->{itemKey});
						if ($item && $highestMatchedLoop <= $loops->{$loopName}->{depth}) {
							if (UNIVERSAL::can($item, "valueForKey")) {
								$value = $item->valueForKey($varName);
							} elsif (IF::Dictionary::isHash($item)) {
								$value = $item->{$varName};
							}
							$highestMatchedLoop = $loops->{$loopName}->{depth};
						}
					}
					unless ($value) {
						$value = $response->param($varName);
					}
				} else {
					my $binding = $self->bindingForKey($contentElement->{BINDING_NAME}) ||
								   $contentElement->{BINDING};
					#IF::Log::debug("Fetching binding ".$contentElement->{BINDING_NAME});
					unless ($binding) {
						$i += 1;
						# TODO only enable this in development:
						# Commented out because it was messing things up in
						# javascript
						#$self->_appendErrorStringToResponse(
						#	"Binding $contentElement->{BINDING_NAME} not found", $response);
						next;
					}
					#IF::Log::debug("evaluating binding ".$binding->{_NAME});

					# HACK WARNING: TODO Fix this!
					# This grabs any attributes that were specified in the
					# template, and sets them on the binding that's being
					# used to generate the subcomponent.  That way, the
					# subcomponent can grab attributes directly
					# and access them if need be
					$binding->{__private}->{ATTRIBUTES} = $contentElement->{ATTRIBUTE_HASH};
					$value = $self->evaluateBinding($binding, $context);
					delete $binding->{__private}->{ATTRIBUTES};
					# add it to the list of components to flush on an
					# iteration, if it's inside a loop
					if ($binding->{type} eq "SUBCOMPONENT_REGION") {
						if ($currentLoopDepth > 0) {
							my $sortedLoops = [sort {$b->{depth} cmp $a->{depth}} values %$loops];
							my $highestLoop = $sortedLoops->[0];
							$highestLoop->{flushOnExit}->{$binding->{binding}} = 1;
							#IF::Log::debug("Adding $binding->{binding} to the flush queue");
						}
					}
					if ($self->bindingIsComponent($binding) || $binding->{type} eq "REGION" ||
						$binding->{type} eq "SUBCOMPONENT_REGION") {
						if ($contentElement->{END_TAG_INDEX}) {
							if ($value =~ /$COMPONENT_CONTENT_MARKER/) {
								my ($openTagReplacement, $closeTagReplacement) = split($COMPONENT_CONTENT_MARKER, $value);
								$value = $openTagReplacement;
								$pregeneratedContent->{int($contentElement->{END_TAG_INDEX})} = $closeTagReplacement;
							} else {
								$response->appendContentString($value);
								$i = $contentElement->{END_TAG_INDEX} + 1;
								next;
							}
						}

						# this is bent because it needs to be evaluated one level lower in
						# the component tree.  here, the including component evaluates the
						# attributes for the included component.
						my $tagAttributes = $contentElement->{ATTRIBUTES};
						# process it using craig's cleverness, but first set the parent up
						# so the hierarchy is preserved - this is a temporary hack
						my $c = $self->subcomponentForBindingNamed($binding->{_NAME});
						if (IF::Log::assert($c, "Subcomponent for binding $binding->{_NAME} exists")) {
							$c->setParent($self);
							$tagAttributes = $self->_evaluateKeyPathsInTagAttributesOnComponent($tagAttributes, $c);
							$c->setParent();
						}
						#IF::Log::debug("Tag attribute string is $tagAttributes for binding $binding->{NAME}");

						$value =~ s/$TAG_ATTRIBUTE_MARKER/$tagAttributes/g;
					}
				}
				$response->appendContentString($value);
				$i++;
				next;
			} elsif ($contentElement->{BINDING_TYPE} eq "BINDING_IF" ||
					 $contentElement->{BINDING_TYPE} eq "BINDING_UNLESS") {
				if ($contentElement->{IS_END_TAG}) {
					unless ($contentElement->{START_TAG_INDEX}) {
						IF::Log::error(IF::Template->errorForKey("NO_MATCHING_START_TAG_FOUND", $contentElement->{BINDING_NAME}, $i));
						$self->_appendErrorStringToResponse(
							IF::Template->errorForKey("NO_MATCHING_START_TAG_FOUND", $contentElement->{BINDING_NAME}, $i),
							$response);
					}
					$i += 1;
					next;
				} else {
					unless ($contentElement->{END_TAG_INDEX} || $contentElement->{ELSE_TAG_INDEX}) {
						IF::Log::error(IF::Template->errorForKey("NO_MATCHING_END_TAG_FOUND", $contentElement->{BINDING_NAME}, $i));
						$self->_appendErrorStringToResponse(
							IF::Template->errorForKey("NO_MATCHING_END_TAG_FOUND", $contentElement->{BINDING_NAME}, $i),
							$response);
						$i += 1;
						next;
					}
				}
				my $condition;
				if ($contentElement->{BINDING_NAME} =~ /^__LEGACY__(.*$)/) {
					my $varName = $1;
					#IF::Log::debug("Found legacy tag $varName");
					my $upperCaseVarName = uc($varName);
					my $highestMatchedLoop = 0;
					foreach my $loopName (keys %$loops) {
						if ($loopContextVariables->{$upperCaseVarName}) {
#IF::Log::debug("Legacy loop context variable $upperCaseVarName found");
							if ($upperCaseVarName eq "__ODD__" &&
								$loops->{$loopName}->{index} % 2 == 1 &&
								$highestMatchedLoop <= $loops->{$loopName}->{depth}) {
								$condition = 1;
								$highestMatchedLoop = $loops->{$loopName}->{depth};
							} elsif ($upperCaseVarName eq "__EVEN__" &&
								$loops->{$loopName}->{index} % 2 == 0 &&
								$highestMatchedLoop <= $loops->{$loopName}->{depth}) {
								$condition = 1;
								$highestMatchedLoop = $loops->{$loopName}->{depth};
							} elsif ($upperCaseVarName eq "__LAST__" &&
								$loops->{$loopName}->{index} == ($#{$loops->{$loopName}->{list}}+1) &&
								$highestMatchedLoop <= $loops->{$loopName}->{depth}) {
								$condition = 1;
								$highestMatchedLoop = $loops->{$loopName}->{depth};
							} elsif ($upperCaseVarName eq "__FIRST__" &&
								$loops->{$loopName}->{index} == 0 &&
								$highestMatchedLoop <= $loops->{$loopName}->{depth}) {
								$condition = 1;
								$highestMatchedLoop = $loops->{$loopName}->{depth};
							} else {
								$condition = 0;
							}
						} else {
							my $item = $self->valueForKey($loops->{$loopName}->{itemKey});
							if ($item && $highestMatchedLoop <= $loops->{$loopName}->{depth}) {
								if (UNIVERSAL::can($item, "valueForKey")) {
									$condition = $item->valueForKey($varName);
								} elsif (IF::Dictionary::isHash($item)) {
									$condition = $item->{$varName};
								}
								$highestMatchedLoop = $loops->{$loopName}->{depth};
							}
						}
					}
					unless ($condition) {
						$condition = $response->param($varName);
					}
				} else {
					my $binding = $self->bindingForKey($contentElement->{BINDING_NAME});
					unless ($binding) {
						$i++;
						next;
					}
					$condition = $self->evaluateBinding($binding, $context);
				}
				if (IF::Array::isArray($condition)) {
						$condition = scalar @$condition;
				}
				if ($contentElement->{BINDING_TYPE} eq "BINDING_UNLESS") {
					$condition = !$condition;
				}
				# decide what to include
				if ($condition) {
					$i++;
					if ($contentElement->{ELSE_TAG_INDEX}) {
						$flowControl->{int($contentElement->{ELSE_TAG_INDEX})} = {
							command => "SKIP",
							index => $contentElement->{END_TAG_INDEX},
						};
					}
					next;
				} else {
					if ($contentElement->{ELSE_TAG_INDEX}) {
						$i = $contentElement->{ELSE_TAG_INDEX} + 1;
					} else {
						$i = $contentElement->{END_TAG_INDEX};
					}
					next;
				}
			} elsif ($contentElement->{BINDING_TYPE} eq "BINDING_LOOP") {
				if ($contentElement->{IS_END_TAG}) {
					unless ($contentElement->{START_TAG_INDEX}) {
						IF::Log::error(IF::Template->errorForKey("NO_MATCHING_START_TAG_FOUND", $contentElement->{BINDING_NAME}, $i));
						$self->_appendErrorStringToResponse(
							IF::Template->errorForKey("NO_MATCHING_START_TAG_FOUND", $contentElement->{BINDING_NAME}, $i),
							$response);
						$i += 1;
						$renderState->decreaseLoopContextDepth();
					} else {
						$i = $contentElement->{START_TAG_INDEX};
						$renderState->incrementLoopContextNumber();
					}
					next;
				} else {
					unless ($contentElement->{END_TAG_INDEX}) {
						IF::Log::error(IF::Template->errorForKey("NO_MATCHING_END_TAG_FOUND", $contentElement->{BINDING_NAME}, $i));
						$self->_appendErrorStringToResponse(
							IF::Template->errorForKey("NO_MATCHING_END_TAG_FOUND", $contentElement->{BINDING_NAME}, $i),
							$response);
						$i += 1;
						next;
					}
				}
				my $loopName;
				if ($contentElement->{BINDING_NAME} =~ /^__LEGACY__(.*)$/) {
					my $loopLabel = $1;
					$loopName = $loopLabel."_".$i;
					#IF::Log::debug("processing loop $loopName");
					unless ($loops->{$loopName}) {
						my $list = [];
						if (scalar @legacyLoops == 0 && $currentLoopDepth == 0) {
							$list = $response->param($loopLabel);
						} else {
							my $highestMatchedLoop = 0;
							foreach my $key (keys %$loops) {
								my $item = $self->valueForKey($loops->{$key}->{itemKey});
								if ($item && $highestMatchedLoop <= $loops->{$key}->{depth}) {
									if (UNIVERSAL::can($item, "valueForKey")) {
										$list = $item->valueForKey($loopLabel);
									} elsif (IF::Dictionary::isHash($item)) {
										$list = $item->{$loopLabel};
									}
									$highestMatchedLoop = $loops->{$key}->{depth};
								}
							}
						}
						$loops->{$loopName} = {
							list => $list,
							index => 0,
							itemKey => "LOOP_".$loopName."_ITEM",
							indexKey => "LOOP_".$loopName."_INDEX",
							depth => $currentLoopDepth,
							isLegacy => 1,
							flushOnExit => {},
						};
						$currentLoopDepth++;
						$renderState->increaseLoopContextDepth();
						push (@legacyLoops, $loopName);
					}
				} else {
					my $binding = $self->bindingForKey($contentElement->{BINDING_NAME});
					unless ($binding) {
						if ($contentElement->{END_TAG_INDEX}) {
							$i = $contentElement->{END_TAG_INDEX} + 1;
						} else {
							$i += 1;
						}
						next;
					}
					$loopName = $contentElement->{BINDING_NAME};
					unless ($loops->{$loopName}) {
						$loops->{$loopName} = {
							list => $self->evaluateBinding($binding, $context),
							index => 0,
							itemKey => $binding->{item} || $binding->{ITEM},
							indexKey => $binding->{index} || $binding->{INDEX},
							depth => $currentLoopDepth,
							isLegacy => 0,
							flushOnExit => {},
						};
						$currentLoopDepth++;
						$renderState->increaseLoopContextDepth();
					}
				}

				# decide if we want to skip
				my $listSize = 0;
				if ($loops->{$loopName}->{list}) {
					$listSize = scalar @{$loops->{$loopName}->{list}};
				}
				my $loopIndex = $loops->{$loopName}->{index};
				if ($loopIndex >= $listSize || $listSize == 0 ||
					!$loops->{$loopName}->{list}) {
					if ($loops->{$loopName}->{isLegacy}) {
						pop (@legacyLoops);
					}

					# Flush any queued components
					foreach my $scn (keys %{$loops->{$loopName}->{flushOnExit}}) {
						#IF::Log::debug("Flushing $scn");
						my $sc = $self->subcomponentForBindingNamed($scn);
						next unless $sc;
						delete $self->{_regionCache}->{$scn};
						$sc->flushRegions();
					}

					delete $loops->{$loopName};
					$currentLoopDepth--;
					$renderState->decreaseLoopContextDepth();
					$i = $contentElement->{END_TAG_INDEX} + 1;
					next;
				}

				# we're not skipping so
				my $itemKey = $loops->{$loopName}->{itemKey};
				my $indexKey = $loops->{$loopName}->{indexKey};
				if ($itemKey) {
					$self->setValueForKey(undef, $itemKey); # clear it out?
					$self->setValueForKey($loops->{$loopName}->{list}->[$loopIndex], $itemKey);
					#IF::Log::dump($loops->{$loopName}->{list}->[$loopIndex]);
				}
				if ($indexKey) {
					$self->setValueForKey($loopIndex, $indexKey);
				}
				$loops->{$loopName}->{index} += 1;
				$i++;
				next;
			} elsif ($contentElement->{BINDING_TYPE} eq "KEY_PATH") {
        		$response->appendContentString($self->valueForKey($contentElement->{KEY_PATH}));
        	}
		} else {
			$response->appendContentString($contentElement);
		}
		$i++;
	}

	if ($context && $context->session()) {
		$context->session()->requestContext()->addRenderedComponent($self);
	}

	# experimental code to handle regions
	if ($self->hasRegions()) {
		$self->parseRegionsFromResponse($response);
	}

	# clean up the bindings cache and fix up the header
	if ($self->isRootComponent()) {
		$BINDING_CACHE = {};
		$self->addPageResourcesToResponseInContext($response, $context);
	}

	# Trying to allow components to reset their values
	$self->resetValues();
	$self->{_context} = undef;
	$self->_setRenderState();
	return;
}

sub resetValues {
	my ($self) = @_;
	# override this to reset your component between instances.
}

# TODO - this won't work correctly for asynchronous components
# that renumber themselves to start with a different page
# context number -kd
sub isRootComponent {
	my $self = shift;
	return ($self->pageContextNumber() eq '1');
}

sub rootComponent {
	my $self = shift;
	my $currentComponent = $self;
	while (1) {
		return $currentComponent if ($currentComponent->isRootComponent());
		$currentComponent = $currentComponent->parent();
		return $self unless $currentComponent;
	}
	return $self;
}

sub isFirstTimeRendered {
	my $self = shift;
	my $componentName = $self->componentName();
	return 0 if ($self->context()->session()->requestContext()->didRenderComponentWithName($componentName));
	return 1;
}

# generate a *text* name for the component that's unique
sub uniqueId {
	my $self = shift;
	# experimental
	return "c".$self->renderContextNumber();
	# $self->{_uniqueId} = $self->pageContextNumber();
	#  $self->{_uniqueId} =~ tr/\_[0-9]/Z[a-j]/;
	#
	#  if ($self->context()->loopContextDepth() > 0) {
	#      $self->{_uniqueId} .= "L" . $self->context()->loopContextNumber();
	#  }
	#  return $self->{_uniqueId};
}

sub renderContextNumber {
	my ($self, $renderState) = @_;
	my $pcn = $self->pageContextNumber();
	$renderState ||= $self->_renderState();
	if ($renderState && $renderState->loopContextDepth() > 0) {
		$pcn .= "L" . $renderState->loopContextNumber();
	}
	return $pcn;
}

# hmpf, this is necessary if we want the page to reinflate dynamically generated
# form components correctly. -kd
sub queryKeyNameForPageAndLoopContexts {
	my ($self) = @_;
	return $self->renderContextNumber();
}


sub bindings {
    my ($self) = @_;
    unless ($self->{_didLoadBindings}) {
        $self->loadBindings();
    }
    return $self->{_bindings};
}

sub bindingForKey {
    my ($self, $key) = @_;

	# automatically try the uppercase binding name if we can't find the one passed in.
	# It's a legacy thing; all the old binding names used to caps.
	my $b = $self->bindings()->{$key} || $self->bindings()->{uc($key)};
	# Allow overrides
	my $fullPathToBinding = $self->nestedBindingPath()."__".$key;
	my $ob = $self->overrideForPath($fullPathToBinding);
	if ($ob && $b) {
	    IF::Log::debug("OVERRIDE found for $key");
	    $ob->{_index} = $b->{_index};
	    $ob->{_defaultPageContextNumber} = $b->{_defaultPageContextNumber};
	    $ob->{_NAME} = $b->{_NAME};
	    IF::Log::dump($b);
	    $b = $ob; # then switch it into place for this pass.
	    IF::Log::dump($b);
	}

	# cheesy error message
	if (!$b) {
	    if ($self->allowsDirectAccess()) {
	        return {
	            type => "STRING",
	            value => "$key(\$context)",
	        };
	    }
	    #IF::Log::debug("Couldn't find binding with name $key");
	    my $error = IF::Template->errorForKey("BINDING_NOT_FOUND", $key);
	    return {
	        type => "STRING",
	        value => "\'$error\'",
	    }
	}
	return $b;
}

sub evaluateExpression {
	my ($self, $expression) = @_;
	my $context = $self->context();
	return eval $expression;
}

# The old version of this was a method that did a perl-ish
# "switch" statement (ie. incredibly inefficient) so
# I rewrote it as a dispatch table.  Much faster now.

my $_BINDING_DISPATCH_TABLE = {
    LOCALIZED_STRING => sub {
		my ($self, $binding, $context) = @_;
		my $key = $binding->{__private}->{ATTRIBUTES}->{$binding->{key}};
		return "" unless $key;
		return
		    _s( "", # why is this needed?  jesus.
		        $key,
		        $context->language(),
		        $context->application()->name(),
		    );
    },
	STRING => sub {
		my ($self, $binding, $context) = @_;
		my $value = IF::Utility::evaluateExpressionInComponentContext($binding->{value}, $self, $context);
		if ($binding->{maxLength}) {
		    my $maxLength = ($binding->{maxLength} =~ /^\d+$/)? $binding->{maxLength}
		                    : IF::Utility::evaluateExpressionInComponentContext($binding->{maxLength}, $self, $context);
			if ($maxLength && length($value) > $maxLength) {
				$value = substr($value, 0, ($maxLength - 3))."...";
			}
		}
		if ($binding->{escapeHTML}) {
			$value = IF::Utility::escapeHtml($value);
		}
		if ($binding->{outgoingTextToHTML} && $binding->{outgoingTextToHTML} eq "YES") {
			$value = IF::Utility::formattedHtmlFromText($value);
		}
		IF::Log::warning("eval error: $@ while trying to evaluate ".$binding->{_NAME}." (".$binding->{value}.")") if $@;
		if ($binding->{filter}) {
			my $filterName = $binding->{filter};
			my $filterExpression;
			if ($filterName =~ /::/) {
				$filterExpression = $filterName.'($value)';
			} else {
				$filterExpression = '$self->'.$filterName.'($value)';
			}
			my $filteredValue = eval $filterExpression;
			#IF::Log::debug($filterExpression);
			unless ($@) {
				#IF::Log::debug("Successfully filtered ".$binding->{NAME});
				$value = $filteredValue;
			} else {
				IF::Log::error("Failed to filter $binding->{NAME} because $@");
			}
		}
		return $value;
	},
	NUMBER => sub {
		my ($self, $binding, $context) = @_;
		my $format = IF::Utility::evaluateExpressionInComponentContext($binding->{format}, $self, $context) || "%d";
		my $value =  sprintf($format, IF::Utility::evaluateExpressionInComponentContext($binding->{value}, $self, $context));
		IF::Log::warning("eval error: $@ while trying to evaluate ".$binding->{_NAME}." (".$binding->{value}.")") if $@;
		return $value || "0";
	},
	DATE => sub {
		my ($self, $binding, $context) = @_;
		my $value = IF::Utility::dateStringForUnixTimeInContext(
									IF::Utility::evaluateExpressionInComponentContext($binding->{value}, $self, $context),
									$context);
		IF::Log::warning("eval error: $@ while trying to evaluate ".$binding->{_NAME}." (".$binding->{value}.")") if $@;
		return $value;
	},
	LOOP => sub {
		my ($self, $binding, $context) = @_;
		my $value = IF::Utility::evaluateExpressionInComponentContext($binding->{list}, $self, $context);
		unless (IF::Array::isArray($value)) {
			IF::Log::warning("Attempt to set LOOP with SCALAR $value, failing gracefully");
			if ($value != undef) {
				$value = [$value];
			} else {
				$value = [];
			}
		}
		IF::Log::warning("eval error: $@ while trying to evaluate ".$binding->{_NAME}." (".$binding->{value}.")") if $@;
		return $value;
	},
	BOOLEAN => sub {
		my ($self, $binding, $context) = @_;
		my $value = (IF::Utility::evaluateExpressionInComponentContext($binding->{value}, $self, $context))? 1:0;
		if ($binding->{negate}) {
			$value = !$value;
		}
		IF::Log::warning("eval error: $@ while trying to evaluate ".$binding->{_NAME}." (".$binding->{value}.")") if $@;
		return $value;
	},
	CONTENT => sub {
		return $COMPONENT_CONTENT_MARKER;
	},
	ATTRIBUTES => sub {
		return $TAG_ATTRIBUTE_MARKER;
	},
	CONSUMER => sub {
		my ($self, $binding, $context) = @_;
		my $value = $self->componentResponseForBindingNamed($binding->{_NAME});
		IF::Log::warning("error trying to evaluate binding ".$binding->{_NAME}) unless $value;
		chomp($value);
		return $value;
	},
	REGION => sub {
		my ($self, $binding, $context) = @_;
		# build start and end tags for the region, and return them with a component content
		# indicator in the middle:
		my $startTag = sprintf($REGION_TAG_MARKER, $binding->{name});
		my $endTag   = "</REGION>";
		$self->setHasRegions(1);
		return $startTag.$COMPONENT_CONTENT_MARKER.$endTag;
	},
	SUBCOMPONENT_REGION => sub {
		my ($self, $binding, $context) = @_;
		my $regionName = $binding->{name};
		my $bindingName = $binding->{binding};
		my $subcomponentBinding = $self->bindingForKey($bindingName);
		if ($subcomponentBinding) {
			unless ($self->{_regionCache}->{$bindingName}) {
				IF::Log::debug("Adding $bindingName to region cache");
 				$self->evaluateBinding($subcomponentBinding, $context);
				$self->{_regionCache}->{$bindingName} = $self->subcomponentForBindingNamed($bindingName);
			}
			return $self->{_regionCache}->{$bindingName}->nextRegionForKey($regionName);
		} else {
			IF::Log::error("Couldn't load binding named $bindingName when trying to render region $regionName");
			return "<b>Region $regionName not found for binding $bindingName</b>";
		}
	},
	COMPONENT => sub {
		my ($self, $binding, $context) = @_;
		IF::Log::page(">>> $binding->{type} : $binding->{_NAME} : ".$self->context());
		IF::Log::incrementPageStructureDepth();
		my $value = $self->componentResponseForBinding($binding);
		IF::Log::decrementPageStructureDepth();
		IF::Log::page("<<< $binding->{type} : $binding->{_NAME}");
		IF::Log::warning("error trying to evaluate binding ".$binding->{_NAME}." (".$binding->{value}.") - $@") unless $value;
		chomp($value);
		return $value;
	},
};

sub evaluateBinding {
	my ($self, $binding, $context) = @_;
	return unless $binding;
	my $bindingType = $self->bindingIsComponent($binding) ? "COMPONENT" : $binding->{type};
	my $dispatch = $_BINDING_DISPATCH_TABLE->{$bindingType};
	my $rv = $dispatch->($self, $binding, $context);
	return $rv;
}

sub componentResponseForBindingNamed {
    my ($self, $bindingKey, $renderState) = @_;
	my $binding = $self->bindingForKey($bindingKey);
	return $self->componentResponseForBinding($binding, $renderState);
}

# TODO remove most of this bloat... it's repeated and unnecessary.
sub componentResponseForBinding {
	my ($self, $binding) = @_;

    my $context = $self->context();
    my $renderState = $self->_renderState();
	my $bindingKey = $binding->{_NAME};
	my $bindingClass = $binding->{value} || $binding->{type};
	my $componentName = IF::Utility::evaluateExpressionInComponentContext($bindingClass, $self, $context, {'quiet' => 1}) || $bindingClass;
	my $templateName = __templateNameFromComponentName($componentName);
	my $response = IF::Response->new();
	$response->setRenderState($renderState);
    my $component = $self->subcomponentForBindingNamed($bindingKey);
	my $template;
	if ($component && $component->hasCompiledResponse()) {
		#$template = bestTemplateForNameAndContext($templateName, $context);
	} else {
        $template = $self->_siteClassifier()->bestTemplateForPathAndContext($templateName, $context);
	}
	$response->setTemplate($template);

	unless ($component) {
		$component = $self->pageWithName($componentName);

		unless ($component) {
			IF::Log::error("no component - $bindingKey");
			return undef;
		}
		$component->setParentBindingName($bindingKey);
		$renderState->incrementPageContextNumber();
		$component->setPageContextNumberRoot($renderState->pageContextNumber());

		# if it's a late-binding component name, it's not in $self->{_subcomponents}
		# so stash the component object that we just created in there.
		if ($binding->{type} eq "CONSUMER") {
			$self->{_subcomponents}->{$bindingKey} = $component;
		}
	}
	return IF::Log::error("no template - $templateName") unless $response;

	unless ($component->{_context}) {
	    $component->{_context} = $context;
	}
	$component->_setRenderState($renderState);
	$component->setTagAttributes($binding->{__private}->{ATTRIBUTES});
	$component->setParent($self);
	$component->pullValuesFromParent();
	$component->appendToResponse($response, $context);
	$component->setParent();

	# reset the tag attributes
	$component->setTagAttributes({});

	return $response->content();
}

sub pageWithNameAndAttributes {
	my $self = shift;
	my $componentName = shift;
	my $attributes = shift || {};

	my $component = $self->pageWithName($componentName);
	return undef unless $component;
	foreach my $key (keys %$attributes) {
		$component->setValueForKey(
			IF::Utility::evaluateExpressionInComponentContext($attributes->{$key},
				$self, $self->context(),
				),
			$key);
	}
	return $component;
}

sub pageInSiteWithName {
	my ($self, $siteClassifierPath, $componentName) = @_;

#	if ($siteClassifierPath eq $self->context()->siteClassifier()->componentClassName()) {
    if ($siteClassifierPath eq $self->_siteClassifier()->componentClassName()) {
		return $self->pageWithName($componentName);
	}
	my $siteClassifierClassName = $self->application()->siteClassifierClassName();
	my $siteClassifier = $siteClassifierClassName->siteClassifierWithComponentClassName($siteClassifierPath);
	$self->context()->setSiteClassifier($siteClassifier);
	return $self->pageWithName($componentName);
}

sub pageWithName {
	my ($self, $componentName) = @_;
#	return $self->context()->siteClassifier()->componentForNameAndContext($componentName, $self->context());
	my $c = $self->_siteClassifier()->componentForNameAndContext($componentName, $self->context());
	$c->{_context} = $self->context();
	return $c;
}

# theft! theft!
sub takeValuesFromRequest {
	my ($self, $context) = @_;

	# "request" and "context" are kind of wrapped up into one...
	if ($self->isRootComponent()) {
		return unless $context->session();
		return unless $context->lastRequestWasSpecified();
		my $lastRequestContext = $context->session()->requestContextForContextNumber($context->contextNumber());

		return unless IF::Log::assert(
			$lastRequestContext, "No last request.  Well, maybe a pixie caramel (NZ joke). ".$context->contextNumber());

		if ($lastRequestContext->didRenderComponentWithName($self->componentName())) {
			my $callingComponentPageContextNumber = $lastRequestContext->pageContextNumberForCallingComponentInContext($self->componentName(), $context);
			$context->setCallingComponentPageContextNumber($callingComponentPageContextNumber);
			#IF::Log::debug("Calling component context number was $callingComponentPageContextNumber");
		} else {
		    #IF::Log::dump($lastRequestContext);
			IF::Log::debug("Did not render ".$self->componentName()." in past request");
			return;
		}
	}

	# forward "takeValues" to subcomponents after trying to set
	# their bindings. don't try to optimise this lastRequestContext call
	# out because it needs to be here and also above.  think about it and you'll see why.
	my $lastRequestContext = $context->session()->requestContextForContextNumber($context->contextNumber());
	IF::Log::assert($lastRequestContext, "Last request context refetched correctly for context number ".$context->contextNumber());
	my $callingComponentPageContextNumber = $context->callingComponentPageContextNumber();
    foreach my $bindingKey (keys %{$self->bindings()}) {
        next unless exists $self->{_bindings}->{$bindingKey}->{_index}; # if it has an index, it's a component
        my $subcomponent = $self->subcomponentForBindingNamed($bindingKey);
		next unless (IF::Log::assert($subcomponent, "Subcomponent exists for $bindingKey"));
		my $oldPageContextNumber = $subcomponent->pageContextNumber();
		if ($callingComponentPageContextNumber) {
			# set pageContextNumber relative to the calling component
			my $newPageContextNumber = $oldPageContextNumber;
			$newPageContextNumber =~ s/^1/$callingComponentPageContextNumber/g;
			$subcomponent->setPageContextNumber($newPageContextNumber);
		}
		unless ($lastRequestContext && $lastRequestContext->didRenderComponentWithPageContextNumber($subcomponent->renderContextNumber())) {
			#IF::Log::debug("Skipping takeValues for component ".$subcomponent->componentName()." / ".$subcomponent->renderContextNumber());
			next;
		}
		$subcomponent->setParent($self);
		# kinda nasty but during binding sync, the context needs to be accessible to
		# the subcomponent *before* its tvfr is called
		$subcomponent->setContext($context);
		$subcomponent->pullValuesFromParent();
		$subcomponent->takeValuesFromRequest($context);
		$subcomponent->pushValuesToParent();
		$subcomponent->setParent();
		if ($callingComponentPageContextNumber) {
			$subcomponent->setPageContextNumber($oldPageContextNumber);
		}
		# This should reset the component into its initial state
		# so that if the same component is re-used (say, in a loop or dynamic form)
		# it doesn't have any stale values in it.
		$subcomponent->resetValues();
	}
}

sub pullValuesFromParent {
	my $self = shift;
	return unless ($self->parent() && $self->parent()->synchronizesBindingsWithChildren()
								&& $self->synchronizesBindingsWithParent());
	$self->parent()->pushValuesToComponent($self);
}

sub pushValuesToComponent {
	my $self = shift;
	my $component = shift;
	my $binding = $self->bindingForKey($component->parentBindingName());

	return $self->pushValuesToComponentUsingBindings($component, $binding->{bindings});
}

sub pushValuesToComponentUsingBindings {
	my $self = shift;
	my $component = shift;
	my $bindings = shift;

	# set the bindings
	foreach my $key (keys %$bindings) {
		my $value = IF::Utility::evaluateExpressionInComponentContext($bindings->{$key}, $self, $self->context());
		$component->setValueForKey($value, $key);
	}
}

sub pushValuesToParent {
	my $self = shift;
	return unless ($self->parent() && $self->parent()->synchronizesBindingsWithChildren()
								&& $self->synchronizesBindingsWithParent());
	$self->parent()->pullValuesFromComponent($self);
}

sub pullValuesFromComponent {
	my $self = shift;
	my $component = shift;
	my $binding = $self->bindingForKey($component->parentBindingName());

	# set the bindings
	foreach my $key (keys %{$binding->{bindings}}) {
		next unless $component->shouldAllowOutboundValueForBindingNamed($key);
		next unless IF::Utility::expressionIsKeyPath($binding->{bindings}->{$key});
		my $value = $component->valueForKeyPath($key);
		#IF::Log::debug("Pull: ".$self->componentNameRelativeToSiteClassifier()."  ($binding->{bindings}->{$key})"
		#	." <-- ".$component->componentNameRelativeToSiteClassifier()." ($key, $value)");
		$self->setValueForKeyPath($value, $binding->{bindings}->{$key});
	}
}

# this lazily inflates component instances from bindings
# only when they're requested for the first time.
sub subcomponentForBindingNamed {
    my ($self, $bindingName) = @_;
	return $self->{_subcomponents}->{$bindingName} if $self->{_subcomponents}->{$bindingName};

	# Allow overrides
	my $fullPathToBinding = $self->nestedBindingPath()."__".$bindingName;
	my $ob = $self->overrideForPath($fullPathToBinding);
	my $b = $self->bindingForKey($bindingName);
	if ($ob && $b) {
	    # set the override to look the same as the binding to the system
	    $ob->{_index} = $b->{_index};
	    $ob->{_defaultPageContextNumber} = $b->{_defaultPageContextNumber};
	    $ob->{_NAME} = $b->{_NAME};
	    IF::Log::dump($b);
	    $b = $ob; # then switch it into place for this pass.
	    IF::Log::dump($b);
	}

	#IF::Log::debug("Instantiating binding $bindingName with index ".$b->{_index}." dpc ".$b->{_defaultPageContextNumber});

	# instantiate it
#    my $subcomponent = $self->context()->siteClassifier()->componentForBindingInContext($b, $self->context());
    my $subcomponent = $self->_siteClassifier()->componentForBindingInContext($b, $self->context());

    if (IF::Log::assert($subcomponent, "Inflated component for binding $bindingName")) {
        # Tell the subcomponent which of its parent's bindings
        # created it...  this is used when the parent resolves
        # requests
        $subcomponent->setParentBindingName($bindingName);
        #IF::Log::debug("Context is ".$subcomponent->pageContextNumber()." id is ".$subcomponent->uniqueId());
        $self->{_subcomponents}->{$bindingName} = $subcomponent;
    }
    return $self->{_subcomponents}->{$bindingName};
}

sub invokeDirectActionNamed {
    my ($self, $directActionName, $context) = @_;

	return unless $directActionName;

    # expose the context to action handlers

    $self->{_context} = $context;

	# only invoke a method if it's predefined
	my $methodName;
	my $targetPageContextNumber;
	my $targetComponentDirectActionName;
	my $defaultDirectAction = $context->application()->configurationValueForKey("DEFAULT_DIRECT_ACTION");
	if ($directActionName eq $defaultDirectAction) {
		$methodName = $defaultDirectAction."Action";
	} else {
		if ($directActionName =~ /^[0-9\_]+\-[A-Za-z0-9_]+$/) {
			($targetPageContextNumber, $targetComponentDirectActionName) = split("-", $directActionName);
			#IF::Log::debug("$targetPageContextNumber - $targetComponentDirectActionName");
			if ($targetPageContextNumber == 1) {
				$methodName = $self->actionMethodForAction($targetComponentDirectActionName);
				#IF::Log::debug("Action method name is $methodName");
			}
			if (!$methodName && $targetComponentDirectActionName eq $defaultDirectAction) {
				$methodName = $defaultDirectAction."Action";
			}
		} else {
			$methodName = $self->actionMethodForAction($directActionName);
			IF::Log::warning("No method name found for $directActionName on ".ref($self)) unless $methodName;
		}
	}

	IF::Log::debug($self->pageContextNumber()." / $methodName / $targetComponentDirectActionName / $targetPageContextNumber");
	return unless ($methodName || $targetComponentDirectActionName);

	# check for action, and invoke it if present
    if ($targetPageContextNumber && $targetPageContextNumber ne "1") {
		# forward directAction to subcomponents:

		#foreach my $subcomponent (values %{$self->{_subcomponents}}) {
        foreach my $sk (keys %{$self->bindings()}) {
        	next unless exists $self->{_bindings}->{$sk}->{_index};
            my $subcomponent = $self->subcomponentForBindingNamed($sk);
			IF::Log::assert($subcomponent, "Subcomponent for key $sk exists");
			#IF::Log::debug($subcomponent->pageContextNumber());
			$subcomponent->setParent($self);
			my $returnValue;
			if ($subcomponent->pageContextNumber() eq $targetPageContextNumber) {
				$returnValue = $subcomponent->invokeDirectActionNamed($targetComponentDirectActionName, $context);
			} else {
				$returnValue = $subcomponent->invokeDirectActionNamed($directActionName, $context);
			}
			$subcomponent->setParent();

			return $returnValue if $returnValue;
		}
	} else {
		if ($self->can($methodName)) {
			# invoke method
			IF::Log::debug("Invoking method $methodName on ".ref($self)."\n");
			return $self->$methodName($context);
		} else {
			IF::Log::warning("Attempt to invoke method $methodName on ".ref($self)." failed\n");
		}
		IF::Log::debug("No method for action $directActionName found.\n");
	}
	return;
}

sub invokeMethodWithArguments {
	my $self = shift;
	my $methodName = shift;
	return unless UNIVERSAL::can($self, $methodName);
	return $self->$methodName(@_);
}

#--------------------------------------
# methods for handling regions
#--------------------------------------

sub hasRegions {
	my $self = shift;
	return $self->{_hasRegions};
}

sub setHasRegions {
	my ($self, $value) = @_;
	$self->{_hasRegions} = $value;
}

sub hasRegionsForKey {
	my ($self, $key) = @_;
	return 0 unless $self->hasRegions();
	return exists($self->regions()->{$key});
}

sub regions {
	my $self = shift;
	return $self->{_regions};
}

sub regionsForKey {
	my ($self, $key) = @_;
	IF::Log::debug("Req for regionsForKey($key)");
	return [] unless $self->hasRegionsForKey($key);
	#IF::Log::dump($self->{_regions}->{$key});
	return $self->{_regions}->{$key};
}

sub regionsOfSubcomponentForKey {
	my ($self, $subcomponentName, $key) = @_;
    my $subcomponent = $self->subcomponentForBindingNamed($subcomponentName);
	IF::Log::debug("Req for subc $subcomponentName for key $key");
	my $binding = $self->bindingForKey($subcomponentName);
	return unless (
		IF::Log::assert($subcomponent, "Found subcomponent named $subcomponentName") ||
		IF::Log::assert($binding && $binding->{type} eq "CONSUMER", "Binding is late-bindings consumer")
	);

    # TODO ungarble this... why does it re-fetch the binding and subcomponent
	unless ($self->{_regionCache}->{$subcomponentName}) {
		my $subcomponentBinding = $self->bindingForKey($subcomponentName);
		IF::Log::debug("Adding $subcomponentName to region cache");
 		$self->evaluateBinding($subcomponentBinding, $self->context());
        $self->{_regionCache}->{$subcomponentName} = $self->subcomponentForBindingNamed($subcomponentName);
	}
	return $self->{_regionCache}->{$subcomponentName}->regionsForKey($key);
}

sub setRegionsForKey {
	my ($self, $regions, $key) = @_;
	$self->{_regions}->{$key} = $regions;
}

sub nextRegionForKey {
	my ($self, $key) = @_;
	my $regionsForKey = $self->regionsForKey($key);
	if (scalar @$regionsForKey > $self->{_regionCounters}->{$key}) {
		my $value = $regionsForKey->[$self->{_regionCounters}->{$key}];
		$self->{_regionCounters}->{$key} += 1;
		return $value;
	}
	return undef; # we return undef if we've gone off the end...
}

sub flushRegions {
	my $self = shift;
	#IF::Log::debug("Flushing regions for ".$self->componentName());
	$self->{_regions} = {};
	$self->{_regionCounters} = {};
	$self->{_regionCache} = {};
}

sub parseRegionsFromResponse {
	my ($self, $response) = @_;
	IF::Log::debug("Regions found in component $self");
	my $content = $response->content();

	while ($content =~ /<REGION NAME="([^"]*)">(.*?)<\/REGION>/sg) {
		my $regionName = $1;
		my $region = $2;
		my $regions = $self->regionsForKey($regionName);
		push (@$regions, $region);
		$self->setRegionsForKey($regions, $regionName);
		#IF::Log::debug("Found region $regionName");
	}

	# strip regions and reset content
	$content =~ s/<\/?REGION[^>]*>/<!-- region -->/g;
	$response->setContent($content);
}

sub setParentBindingName {
	my $self = shift;
	$self->{_parentBindingName} = shift;
}

sub parentBindingName {
	my $self = shift;
	return $self->{_parentBindingName};
}

# this returns the names of bindings in
# the nesting hierarchy.  eg. if a component
# whose binding name is EMAIL_ADDRESS is
# embedded inside another called BILLING_INFO_EDITOR
# the path returned will be
# BILLING_INFO_EDITOR__EMAIL_ADDRESS
sub nestedBindingPath {
	my ($self) = @_;
	my $bindings = [];
	my $current = $self;
	while ($current && $current->parentBindingName()) {
		# Issue: 1425 - Switch component's child has its parent binding
		# path set to the switch component's parent so this avoid a
		# duplicate path element in the nested binding path.
		unshift (@$bindings, $current->parentBindingName()) unless
			$current->isa("IF::Component::SwitchComponent");
		$current = $current->parent();
	}
	return join("__", @$bindings);
}

sub overrideForPath {
    my ($self, $path) = @_;
    foreach my $k (keys %{$self->{_overrides}}) {
        my $re = $k.'$';
        if ($path =~ $re) {
            return $self->{_overrides}->{$k};
        }
    }
    if ($self->parent()) {
        return $self->parent()->overrideForPath($path);
    }
    return undef;
}


# These "parent" methods are super dangerous
# because they can create cyclical references.
# USE WITH CARE because the perl garbage-collector
# is braindead and can't handle cycles.
sub parent {
	my $self = shift;
	return $self->{_parent};
}

sub setParent {
	my $self = shift;
	$self->{_parent} = shift;
}

# Override this if there are bindings you do not wish synchronized:
sub shouldAllowOutboundValueForBindingNamed {
	my ($self, $bindingName) = @_;
	return 1;
}

sub synchronizesBindingsWithParent {
	my $self = shift;
	return $self->{_synchronizesBindingsWithParent};
}

sub setSynchronizesBindingsWithParent {
	my $self = shift;
	$self->{_synchronizesBindingsWithParent};
}

sub synchronizesBindingsWithChildren {
	my $self = shift;
	return $self->{_synchronizesBindingsWithChildren};
}

sub setSynchronizesBindingsWithChildren {
	my $self = shift;
	$self->{_synchronizesBindingsWithChildren};
}

sub _loopIndices {
	my ($self) = @_;
	return $self->{_loopIndices};
}

sub _setLoopIndices {
	my ($self, $value) = @_;
	$self->{_loopIndices} = $value;
}

sub pageContextNumber {
	my $self = shift;
	return $self->{_pageContextNumber};
}

sub setPageContextNumber {
	my $self = shift;
	$self->{_pageContextNumber} = shift;
}

sub setPageContextNumberRoot {
	my ($self, $root) = @_;
	#IF::Log::debug("Setting ".$self->{_pageContextNumber}." to $root");
	$self->{_pageContextNumber} = $root;

	# renumber the subcomponents
    # TODO - can't we do this with the _index that's already in the binding?
	my $subcomponentCounter = 0;
    foreach my $bindingKey (sort keys %{$self->bindings()}) {
        next unless exists $self->{_bindings}->{$bindingKey}->{_index};
        my $subcomponent = $self->subcomponentForBindingNamed($bindingKey);
        if (IF::Log::assert($subcomponent, "Retrieved subcomponent $bindingKey during renumbering")) {
		    $subcomponent->setPageContextNumberRoot($self->pageContextNumber()."_".$subcomponentCounter);
		}
		$subcomponentCounter++;
	}
}

sub context {
	return $_[0]->{_context};
}

sub setContext {
    my ($self, $context) = @_;
    $self->{_context} = $context;
	foreach my $bindingName (sort keys %{$self->{_subcomponents}}) {
		my $subcomponent = $self->{_subcomponents}->{$bindingName};
		IF::Log::debug($subcomponent);
		unless (UNIVERSAL::isa($subcomponent, "IF::Component")) {
		    IF::Log::dump($self->{_subcomponents});
		}
		$subcomponent->setContext($context);
	}
}

# this is used internally by methods trying to derive
# the current site classifier object; if it's not found,
# we return the default
sub _siteClassifier {
    my ($self) = @_;
    if ($self->context() && $self->context()->siteClassifier()) {
        return $self->context()->siteClassifier();
    }
    return IF::Application->defaultApplication()->defaultSiteClassifier();
}

sub session {
	my ($self) = @_;
	return undef unless $self->context();
	return $self->context()->session();
}

sub objectContext {
	my $self = shift;
	return $self->{_defaultObjectContext} if $self->{_defaultObjectContext};
	$self->{_defaultObjectContext} = IF::ObjectContext->new();
	return $self->{_defaultObjectContext};
}

sub application {
	my $self = shift;
	return $self->context()->application() if $self->context();
	return IF::Application->defaultApplication();
}

sub registerAction {
	my ($self, $actionName, $actionMethod) = @_;
	my $package = ref($self);
	$DIRECT_ACTION_DISPATCH_TABLE->{$package}->{$actionName} = $actionMethod;
	unless ($self->{_directActionDispatchTable}) {
	    $self->{_directActionDispatchTable} = {};
	}
	$self->{_directActionDispatchTable}->{$actionName} = $actionMethod;
}

sub actionMethodForAction {
	my ($self, $actionName) = @_;
	my $package = ref($self);
    return $self->{_directActionDispatchTable}->{$actionName}
        || $DIRECT_ACTION_DISPATCH_TABLE->{$package}->{$actionName};
}

sub performParentActionInContext {
	my $self = shift;
	my $actionName = shift;
	my $context = shift;

	unless ($self->parent()) {
		IF::Log::warning("Attempt to perform parent action failed - parent is null");
		return undef;
	}
	return $self->parent()->invokeDirectActionNamed($actionName, $context);
}

sub bindingIsComponent {
	my ($self, $binding) = @_;
    return 0 unless ref($binding);
    return 1 if (exists($binding->{_index}));
    return $binding->{_IS_COMPONENT} ||= _bindingIsComponent($binding);
}

sub _bindingIsComponent {
    my ($binding) = @_;
	return 1 if ($binding->{type} eq "COMPONENT");
	return 0 if ($SYSTEM_BINDING_TYPES->{$binding->{type}});
	return 1;
}

sub _appendErrorStringToResponse {
	my ($self, $error, $response) = @_;
	$response->appendContentString("<span style='border: 2px solid red; padding: 3px; font-weight: bold; font-family: Verdana,Arial,Helvetica;'>".$error."</span>");
}

sub hasCompiledResponse {
	my $self = shift;
	return 0;
}

# Override this if you need to use a different mechanism than
# http 30x to redirect (facebook!), action must call this
# rather than returning the URL directly. Undecided if this
# should actually be further up, further down ... hmmm
sub redirectToUrl {
	my ($self, $url) = @_;
	return $url;
}

sub isNastyOldBrowser {
	my ($self) = @_;
	return $self->isUnsupportedBrowser(); # :)
}

sub isUnsupportedBrowser {
	my $self = shift;
	my $userAgent = $self->context()->userAgent();
	IF::Log::debug("User agent is $userAgent");
	return 1 if $self->isMacIE($userAgent); # god yes
	$userAgent =~ /^([^\/]+)\/([0-9\.]+)/;
	my $majorCompatibility = $1;
	my $majorVersion = $2;
	$userAgent =~ /MSIE ([0-9\.]+)/;
	my $ieVersion = $1;
	if ($majorCompatibility eq "Mozilla" && $majorVersion < 5) {
		return 1 if $ieVersion < 5;
		return 0;
	}
    # Opera just graduated from "not-sucking" school.
    #return 1 if ($majorCompatibility eq "Opera");
	return 1 if ($majorVersion < 5);
	return 1 if ($userAgent =~ /Gecko\/2003/);
	return 0;
}

sub isMacIE {
	my $self = shift;
	my $userAgent = shift;
	if ($userAgent =~ /Mac/) {
		return 1 if ($userAgent =~ /MSIE/);
	}
	return 0;
}

#-------------------------------------------------------------
# These are private helper functions that I'm gathering up
# and will get rid of as many as possible.
#-------------------------------------------------------------
sub __templateNameFromComponentName {
	my $componentName = shift;
	$componentName =~ s/::/\//g;
	return $componentName.".html";
}

sub __templateNameFromContext {
	my $context = shift;
	my $templateName = __templateNameFromComponentName($context->targetComponentName());
    IF::Log::info("template name is $templateName");
	return $templateName;
}

sub __responseFromContext {
	my $context = shift;

	my $templateName = __templateNameFromContext($context);
	my $response = IF::Response->new();
	my $template = $context->siteClassifier()->bestTemplateForPathAndContext($templateName, $context);
	return $response unless $template;
	$response->setTemplate($template);
	return $response;
}

sub componentName {
	my $self = shift;

	unless ($self->{_componentName}) {
	    my $className = ref $self;
		$className =~ s/.+::Component:://go;
		$self->{_componentName} = $className;
	}
	return $self->{_componentName};
}

sub componentNameRelativeToSiteClassifier {
	my $self = shift;
	unless ($self->{_componentNameRelativeToSiteClassifier}) {
		#my $sc = $self->context()->siteClassifier();
		my $sc = $self->_siteClassifier();
		my $componentName = $sc->relativeNameForComponentName($self->componentName());
		$self->{_componentNameRelativeToSiteClassifier} = $componentName;
	}
	return $self->{_componentNameRelativeToSiteClassifier};
}

sub componentNameSpace {
	my $self = shift;
	my $className = ref $self;
	$className =~ m/(.+)::Component/;
	return $1;
}

sub parentClasses {
	my $className = shift;
	return [ eval '@'.$className.'::ISA' ];
}

sub isSystemComponent {
	my $className = shift;
	return ($className =~ /^IF::Component::/);
}

sub hasValuesForFieldsInContext {
	my $self = shift;
	my $fields = shift;
	my $context = shift;

	foreach my $field (@$fields) {
		if ($context->formValueForKey($field) eq "") {
			return 0;
		}
	}
	return 1;
}

# override this!
sub hasValidFormValues {
	my $self = shift;
	my $context = shift;

	return 1;
}

sub _renderState    { return $_[0]->{_renderState} }
sub _setRenderState { $_[0]->{_renderState} = $_[1] }

# If you override this and return true, then bindings of the form
# <binding:foo_bar /> will try to access key "foo_bar" on the
# component if no specific binding for that key is found.
sub allowsDirectAccess {
    my ($self) = @_;
    return 0;
}

sub tagAttributes {
	my $self = shift;
	return $self->{_tagAttributes};
}

sub setTagAttributes {
	my ($self, $value) = @_;
	$self->{_tagAttributes} = $value;
}

sub tagAttributeForKey {
	my ($self, $key) = @_;
	my $tagAttribute = $self->{_tagAttributes}->{$key};
	return $self->_evaluateKeyPathsInTagAttributesOnComponent(
		$tagAttribute, $self
	);
}

sub _evaluateKeyPathsInTagAttributesOnComponent {
	my ($self, $tagAttribute, $component) = @_;
	return "" unless ($tagAttribute && $component);
	my $count = 0;
	while ($tagAttribute =~ /\$\{([^}]+)\}/g) {
		my $keyValuePath = $1;
		my $value = $component->valueForKeyPath($keyValuePath) || $component->valueForKeyPath('parent.' . $keyValuePath);
		#IF::Log::debug("tagAttributeForKey - Found keyValuePath of $keyValuePath and that returned $value");
		#IF::Log::debug("parent is ".$component->parent());
		#\Q and \E makes the regex ignore the inbetween values if they have regex special items which we probably will for the dots (.).
		$tagAttribute =~ s/\$\{\Q$keyValuePath\E\}/$value/g;
		#Avoiding the infinite loop...just in case
		last if $count++ > 100;
	}
	return $tagAttribute;
}



# New conveniences; these are designed to help clean up the whole
# life-cycle of components from instantiation through to rendering

# Class method:
sub instanceForRequest {
    my ($className, $request) = @_;
    my $context = IF::Context->contextForRequest($request);
	my $targetComponentName = $context->targetComponentName();
	return undef unless $targetComponentName;
	my $siteClassifier      = $context->siteClassifier();
	return undef unless $siteClassifier;
	my $component = $siteClassifier->componentForNameAndContext($targetComponentName, $context);
	return $component;
}

# This helper just makes a default response and sets the template with
# the appropriate goop
sub response {
    my ($self) = @_;

    # make a response object, set it up and return it
	my $templateName = $self->templateName();
	#my $template = $self->context()->siteClassifier()->bestTemplateForPathAndContext($templateName, $self->context());
	my $template = $self->_siteClassifier()->bestTemplateForPathAndContext($templateName, $self->context());
	#IF::Log::dump($template);
	my $response = IF::Response->new();
	$response->setTemplate($template);
	return $response;
}

sub render {
    my ($self) = @_;
    return $self->renderWithParameters();
}

# This bypasses the generation of a response object for the consumer
# and just renders it into the response object and returns the
# rendered text.
sub renderWithParameters {
    my $self = shift;
    my $parameters = {
        @_,
    };
    my $context = $parameters->{context} || $self->context();
    unless ($context) {
        # build a new request object
        my $request = IF::Request::Offline->new();
        # build a URI representing the component with sensible defaults
        my $cn = $self->componentNameRelativeToSiteClassifier();
        $cn =~ s/::/\//g;
        my $uri = join("/",
                $self->application()->configurationValueForKey("URL_ROOT"),
                $parameters->{siteClassifierName} || $self->_siteClassifier()->name(),
                $parameters->{language} || $self->application()->configurationValueForKey("DEFAULT_LANGUAGE"),
                $cn,
                $self->application()->configurationValueForKey("DEFAULT_DIRECT_ACTION"),
        );
        $request->setUri($uri);
        $request->setApplicationName($self->application()->name());
        $context = IF::Context->contextForRequest($request);
    }
    $self->{_context} = $context;
    my $response = $parameters->{response} || $self->response();
    $self->appendToResponse($response, $context);
    return $response->content();
}

# To return a JSON'ed object instead of a response
sub json {
    my ($self, $object, $keys, $wrapper) = @_;

    my $response = IF::Response->new();
    my $t = IF::Utility::jsonFromObjectAndKeys($object, $keys);
    if ($wrapper) {
        $t = $wrapper."($t);";
    }
    $response->appendContentString($t);
    $response->setContentType("text/javascript");
    return $response;
}

# I18N
use IF::I18N;
sub _s {
    my ($self, @args) = @_;
    return IF::I18N::_s(@args);
}

1;
