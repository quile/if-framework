package IF::Interface::FancyTakeValues;

use strict;

sub takeValuesFromRequest {
    my ($self, $context) = @_;
    
    # "request" and "context" are kind of wrapped up into one...
    # IF::Log::debug("takeValues on ".$self->componentName());
    if ($self->isRootComponent()) {
        return unless $context->session();
        my $lastRequestContext = $context->lastRequestContext();
        unless ($lastRequestContext) {
            IF::Log::debug("No last request.  Well, maybe a pixie caramel (NZ joke).");
            return;
        }
        if ($lastRequestContext->didRenderComponentWithName($self->componentName())) {
            my $callingComponentPageContextNumber = $lastRequestContext->pageContextNumberForCallingComponentInContext($self->componentName(), $context);
            $context->setCallingComponentPageContextNumber($callingComponentPageContextNumber);
            IF::Log::debug("Calling component context number was $callingComponentPageContextNumber");
        } else {
            IF::Log::debug("Did not render ".$self->componentName()." in past request");
            return;
        }
    }

    my $componentName = $self->componentNameRelativeToSiteClassifier();
    my $templateName = IF::Component::__templateNameFromComponentName($componentName);
    my $template = $context->siteClassifier()->bestTemplateForPathAndContext($templateName, $context);

    unless ($template) {
        # what to do here?
        die "Couldn't find template for response";
    } else {
        IF::Log::debug("TVFR: Using template $templateName, which we found successfully.");
    }

    my $flowControl = {};
    my $loops = {};
    my $currentLoopDepth = 0;

    my @legacyLoops = ();
    for (my $i=0; $i<$template->contentElementCount();) {
        my $contentElement = $template->contentElementAtIndex($i);
        #IF::Log::dump($contentElement);

        if (exists ($flowControl->{int($i)})) {
            if ($flowControl->{int($i)}->{command} eq "SKIP") {
                $i = $flowControl->{int($i)}->{index};
            }
            delete $flowControl->{int($i)};
            next;
        }
        if (ref $contentElement) {
            my $value;
            #IF::Log::debug("::: TVFR - reached ".$contentElement->{BINDING_NAME});
            if ($contentElement->{BINDING_TYPE} eq "BINDING") {
                if ($contentElement->{IS_END_TAG}) {
                    $i += 1;
                    next;
                }
                if ($contentElement->{BINDING_NAME} =~ /^__LEGACY__(.*)$/) {
                    # ignore?
                } else {
                    my $binding = $self->bindingForKey($contentElement->{BINDING_NAME}) ||
                                   $contentElement->{BINDING};
                    unless ($binding) {
                        $i += 1;
                        next;
                    }
                    
                    # HACK WARNING: TODO Fix this!
                    # This grabs any attributes that were specified in the
                    # template, and sets them on the binding that's being
                    # used to generate the subcomponent.  That way, the
                    # subcomponent can grab attributes directly
                    # and access them if need be
                    $binding->{__private}->{ATTRIBUTES} = $contentElement->{ATTRIBUTE_HASH};
                    
                    $value = $self->evaluateBindingDuringRequest($binding, $context, );
                    delete $binding->{__private}->{ATTRIBUTES};

                    if ($self->bindingIsComponent($binding) || $binding->{type} eq "REGION" ||
                        $binding->{type} eq "SUBCOMPONENT_REGION") {
                        # not sure what to do here yet?
                        #if ($contentElement->{END_TAG_INDEX}) {
                        #    $i = $contentElement->{END_TAG_INDEX} + 1;
                        #    next;
                        #}
                    }
                }
                $i++;
                next;
            } elsif ($contentElement->{BINDING_TYPE} eq "BINDING_IF" ||
                     $contentElement->{BINDING_TYPE} eq "BINDING_UNLESS") {
                if ($contentElement->{IS_END_TAG}) {
                    unless ($contentElement->{START_TAG_INDEX}) {
                        IF::Log::error(IF::Template->errorForKey("NO_MATCHING_START_TAG_FOUND", $contentElement->{BINDING_NAME}, $i));    
                    }
                    $i += 1;
                    next;
                } else {
                    unless ($contentElement->{END_TAG_INDEX} || $contentElement->{ELSE_TAG_INDEX}) {
                        IF::Log::error(IF::Template->errorForKey("NO_MATCHING_END_TAG_FOUND", $contentElement->{BINDING_NAME}, $i));            
                        $i += 1;
                        next;
                    }                    
                }
                my $condition;
                if ($contentElement->{BINDING_NAME} =~ /^__LEGACY__(.*$)/) {
                    my $varName = $1;
                    my $upperCaseVarName = uc($varName);
                    my $highestMatchedLoop = 0;
                    foreach my $loopName (keys %$loops) {
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
                        $i += 1;
                        $context->decreaseLoopContextDepth();
                    } else {
                        $i = $contentElement->{START_TAG_INDEX};
                        $context->incrementLoopContextNumber();
                    }
                    next;
                } else {
                    unless ($contentElement->{END_TAG_INDEX}) {
                        IF::Log::error(IF::Template->errorForKey("NO_MATCHING_END_TAG_FOUND", $contentElement->{BINDING_NAME}, $i));
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
                            $list = []; # TODO what should we do here?
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
                        $context->increaseLoopContextDepth();
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
                        $context->increaseLoopContextDepth();
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
                                    
                    delete $loops->{$loopName};
                    $currentLoopDepth--;
                    $context->decreaseLoopContextDepth();
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
            }
        }
        $i++;
    }
        
    return;
}

sub evaluateBindingDuringRequest {
    my ($self, $binding, $context) = @_;

    return unless $binding;
    my $bindingType = $self->bindingIsComponent($binding) ? "COMPONENT" : $binding->{type};
    return unless ($bindingType eq "COMPONENT");
    IF::Log::page(">>> TVFR $binding->{type} : $binding->{_NAME}");
    IF::Log::incrementPageStructureDepth();
    
    
    $self->takeValuesFromRequestForBinding($context, $binding);
    
        
    IF::Log::decrementPageStructureDepth();
    IF::Log::page("<<< TVFR $binding->{type} : $binding->{_NAME}");
}

sub takeValuesFromRequestForBinding {
    my ($self, $context, $binding) = @_;

    my $bindingKey = $binding->{_NAME};
    my $bindingClass = $binding->{value} || $binding->{type};
    my $componentName = IF::Utility::evaluateExpressionInComponentContext($bindingClass, $self, $context) || $bindingClass;
    my $templateName = IF::Component::__templateNameFromComponentName($componentName);

    my $component = $self->subcomponentForBindingNamed($bindingKey);
    my $template = $context->siteClassifier()->bestTemplateForPathAndContext($templateName, $context);
    
    return unless IF::Log::assert($template, "TVFR - has template from $templateName");
    return unless IF::Log::assert($component, "TVFR - has component from binding name $bindingKey");
    
    # set the attributes hash on the component, if it exists
    $component->setTagAttributes($binding->{__private}->{ATTRIBUTES});
    
    # the guts of the recursion
    $self->_tvfrOnComponent($context, $component);
    
    # reset the tag attributes
    $component->setTagAttributes({});
}

sub _tvfrOnComponent {
    my ($self, $context, $subcomponent) = @_;
    
#    my $callingComponentPageContextNumber = $context->callingComponentPageContextNumber();
#    my $oldPageContextNumber = $subcomponent->pageContextNumber();
#    if ($callingComponentPageContextNumber) {
#        # set pageContextNumber relative to the calling component
#        my $newPageContextNumber = $oldPageContextNumber;
#        $newPageContextNumber =~ s/^1/$callingComponentPageContextNumber/g;
#        IF::Log::debug("Setting component $oldPageContextNumber to $newPageContextNumber");
#        $subcomponent->setPageContextNumber($newPageContextNumber);
#    }

    my $lrc = $context->lastRequestContext();
    unless ($lrc) {
        IF::Log::debug("TVFR - no last request context for request");
        return;
    }
    unless ($lrc->didRenderComponentWithPageContextNumber($subcomponent->renderContextNumber())) {
        IF::Log::debug("TVFR - Skipping takeValues for component ".$subcomponent->componentName()." / ".$subcomponent->renderContextNumber());
        return;
    }
    
    $subcomponent->setParent($self);
    $subcomponent->pullValuesFromParent();
    
    # temporary goo to get it to work
    if (!$subcomponent->isa("IF::Interface::FancyTakeValues")) {
        # this logic is wrong:
        # my $cn = ref ($subcomponent);
        #         no strict 'refs';
        #         my $isa = \@{"${cn}::ISA"}; 
        #         unshift (@$isa, "IF::Interface::FancyTakeValues");
        #IF::Log::dump($isa);
        # instead we need to insert FancyTakeValues into the right
        # place in the inheritance tree, not just prepend it to this
        # component's ISA.  The reason is this:
        # Suppose you have component B that inherits from A, which inherits from IF::Component.
        # If we prepend FancyTakeValues to B, then A's tvfr will never be called, even though
        # it's the parent class of B.  So instead, we need to prepend FTV to IF::Component, in this case.
        my $isa;
        no strict 'refs';
        if ($subcomponent->isa("IF::Component")) {
            $isa = \@{"IF::Component::ISA"};
        #} elsif ($subcomponent->isa("IF::Component")) {
        #    $isa = \@{"IF::Component"};
        } else {
            IF::Log::warning("Component $self does not inherit from IF::Component; you might need to update FancyTakeValues");
            my $cn = ref ($subcomponent);
            $isa = \@{"${cn}::ISA"};
        }
        # shove this onto the main component class's ISA
        unshift (@$isa, "IF::Interface::FancyTakeValues");
        $subcomponent->takeValuesFromRequest($context);
        # now remove it
        shift (@$isa);
    } else {
        $subcomponent->takeValuesFromRequest($context);
    }
    $subcomponent->pushValuesToParent();
    $subcomponent->setParent();
    
#    if ($callingComponentPageContextNumber) {
#        $subcomponent->setPageContextNumber($oldPageContextNumber);
#    }
}

1;
