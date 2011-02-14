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

package IF::Component::SwitchComponent;
use strict;
use base qw(IF::Component);

use IF::Log;

sub resetValues {
    my ($self) = @_;

    $self->SUPER::resetValues();
    # clean up the component since it'll get re-used over and over
    if (exists $self->{_subcomponents}->{SWITCH_COMPONENT}) {
        delete $self->{_subcomponents}->{SWITCH_COMPONENT};
    };
    $self->setSwitchComponentName();
}

# this switches out the current component and returns the content of the switched one
# but is quite a bit of a hack because it builds a "fake" binding (which allows us to
# do this run-time binding stuff) and passes it into "componentResponseForBinding()"

sub appendToResponse {
    my ($self, $response, $context) = @_;

    if ($self->_switchComponent()) {
        my $fakeBinding = {
            type => $self->_switchComponent()->componentNameRelativeToSiteClassifier(),
            _NAME => "SWITCH_COMPONENT",
        };

        IF::Log::debug("+++++++++++ ".$self->_switchComponent()->componentNameRelativeToSiteClassifier()." ++++++++");
        my $content = $self->componentResponseForBinding($fakeBinding);
        $response->appendContentString($content);
        # This somehow was not being called on iterations, so the
        # switch component would retain previous values (eeek).
        # This solves it... but not the mystery of why resetValues()
        # was not being called properly.
        $self->resetValues();
        return; # ?
    }
    return $self->SUPER::appendToResponse($response, $context);
}

# ISSUE: 2453
# Think it makes more sense to return undef if the switch component
# doesn't exist.  Otherwise the binding sync code gets confused.
sub _switchComponent {
    my ($self) = @_;
    unless ($self->{_subcomponents}->{SWITCH_COMPONENT}) {
        if ($self->switchComponentName()) {
            my $sc = $self->pageWithName($self->switchComponentName());

            if (IF::Log::assert($sc, "Run-time component instantiated")) {
                # Make the new component pretend to be this one in the hierarchy,
                # which should be sufficient to allow for binding synchronisation
                # in both directions during tvfr() and a2r().
                $sc->setPageContextNumberRoot($self->pageContextNumber());
                $sc->setParentBindingName($self->parentBindingName());
                $self->{_subcomponents}->{SWITCH_COMPONENT} = $sc;
            }
        }
    }
    return $self->{_subcomponents}->{SWITCH_COMPONENT};
}

sub componentName {
    my ($self) = @_;
    return $self->switchComponentName() || $self->SUPER::componentName();
}

sub switchComponentName {
    my $self = shift;
    return $self->{switchComponentName};
}

sub setSwitchComponentName {
    my ($self, $value) = @_;
    $self->{switchComponentName} = $value;
}

# override this to proxy the binding values from the parent to the grandchild...
sub pullValuesFromParent {
    my $self = shift;
    return unless ($self->parent() && $self->parent()->synchronizesBindingsWithChildren()
                                && $self->synchronizesBindingsWithParent());

    my $binding = $self->parent()->bindingForKey($self->parentBindingName());

    # we need to first evaluate the binding that specifies the class of the
    # switch component, and set the component name on this component, which is
    # enough so that when _switchComponent() is first invoked, it instantiates
    # the correct component.
    my $value = IF::Utility::evaluateExpressionInComponentContext($binding->{bindings}->{switchComponentName}, $self->parent(), $self->context());
    $self->setSwitchComponentName($value);
    if ($value) {
        IF::Log::debug("SwitchComponent: allowing grandparent ".
            $self->parent()." to push bind values to child ".$self->_switchComponent());
        if ($binding->{bindings}->{switchComponentBindings}) {
            my $switchBindings = IF::Utility::evaluateExpressionInComponentContext(
                    $binding->{bindings}->{switchComponentBindings}, $self->parent(), $self->context());
            $self->parent()->pushValuesToComponentUsingBindings($self->_switchComponent(), $switchBindings);
        } else {
            $self->parent()->pushValuesToComponent($self->_switchComponent());
        }
    }
}

sub pushValuesToParent {
    my $self = shift;
    return unless ($self->parent() && $self->parent()->synchronizesBindingsWithChildren()
                                && $self->synchronizesBindingsWithParent());

    # The switch component should already exist by now.  If not,
    # there's something wrong (but we can fail quietly)
    if ($self->_switchComponent()) {
        IF::Log::debug("SwitchComponent: allowing grandparent ".
            $self->parent()." to pull bind values from child ".$self->_switchComponent());
        $self->parent()->pullValuesFromComponent($self->_switchComponent());
    }
}

# We need these so a SwitchComponent can respond to a direct action.
sub actionMethodForAction {
    my ($self, $action) = @_;
    return unless $self->_switchComponent();
    return $self->_switchComponent()->actionMethodForAction($action);
}

sub invokeDirectActionNamed {
    my ($self, $directAction, $context) = @_;

    return unless $self->_switchComponent();
    return if ($self->_switchComponent() == $self);
    $self->_switchComponent()->setParent($self);
    my $rv = $self->_switchComponent()->invokeDirectActionNamed($directAction, $context);
    $self->_switchComponent()->setParent();
    return $rv;
}

sub hasValidFormValues {
    my ($self, $context) = @_;
    return unless $self->_switchComponent();
    return if ($self->_switchComponent() == $self);
    return $self->_switchComponent()->hasValidFormValues($context);
}

1;