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

package IF::Component::SubmitButton;

use strict;
use base qw(
    IF::Component
    IF::Interface::FormComponent
);

sub requiredPageResources {
    my ($self) = @_;
    return [
        IF::PageResource->javascript("/if-static/javascript/IF/SubmitButton.js"),
    ];
}

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->setShouldValidateForm(1);
}

sub name {
    my $self = shift;
    my $name = $self->{NAME};
    IF::Log::debug ("Name is $name");
    return $name if $name;
    if ($self->directAction()) {
        IF::Log::debug("We have a direct action, so returning _ACTION:".$self->targetComponent()."/".$self->directAction());
        return "_ACTION:".$self->targetComponent()."/".$self->directAction();
    }
    return $self->queryKeyNameForPageAndLoopContexts();
}

sub _deprecated_uniqueId {
    my $self = shift;
    my $uniqueNumber = $self->pageContextNumber();
    $uniqueNumber =~ tr/[0-9]/[A-Z]/;
    $uniqueNumber =~ s/\./_/g;
    return $uniqueNumber;
}

sub value {
    my $self = shift;
    return $self->{VALUE};
}

sub setValue {
    my $self = shift;
    $self->{VALUE} = shift;
}

sub setDirectAction {
    my $self = shift;
    $self->{DIRECT_ACTION} = shift;
}

sub directAction {
    my $self = shift;
    return $self->{DIRECT_ACTION};
}

sub targetComponent {
    my $self = shift;
    return $self->{TARGET_COMPONENT};
}

sub setTargetComponent {
    my $self = shift;
    $self->{TARGET_COMPONENT} = shift;
}

sub _alternateValue {
    my ($self) = @_;
    return $self->alternateValue()
        || $self->tagAttributeForKey("alternateValue")
        || "...";  # TODO: hmm - at least localize
}

sub alternateValue    { return $_[0]->{alternateValue}  }
sub setAlternateValue { $_[0]->{alternateValue} = $_[1] }

sub canOnlyBeClickedOnce {
    my ($self) = @_;
    return $self->{canOnlyBeClickedOnce};
}

sub setCanOnlyBeClickedOnce {
    my ($self, $value) = @_;
    $self->{canOnlyBeClickedOnce} = $value;
}

sub shouldValidateForm {
    my ($self) = @_;
    return $self->{shouldValidateForm} || $self->tagAttributeForKey("shouldValidateForm");
}

sub setShouldValidateForm {
    my ($self, $value) = @_;
    $self->{shouldValidateForm} = $value;
}

1;
