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

package IF::Component::Form;
use strict;
use base 'IF::Component::Hyperlink';

sub requiredPageResources {
    my ($self) = @_;
    return [
        IF::PageResource->javascript("/if-static/javascript/jquery/jquery-1.2.6.js"),
        IF::PageResource->javascript("/if-static/javascript/jquery/plugins/jquery.if.js"),
        IF::PageResource->javascript("/if-static/javascript/IF/Component.js"),
        IF::PageResource->javascript("/if-static/javascript/IF/FormComponent.js"),
        IF::PageResource->javascript("/if-static/javascript/IF/Form.js"),
        IF::PageResource->javascript("/if-static/javascript/IF/Validator.js"),
    ];
}

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->setMethod("POST");
}

sub method {
    my $self = shift;
    return $self->{method};
}

sub setMethod {
    my ($self, $value) = @_;
    $self->{method} = $value;
}

sub shouldEnableClientSideScripting {
    my $self = shift;
    return $self->{shouldEnableClientSideScripting};
}

sub setShouldEnableClientSideScripting {
    my $self = shift;
    $self->{shouldEnableClientSideScripting} = shift;
}

sub encType {
    my $self = shift;
    return $self->{encType};
}

sub setEncType {
    my ($self, $value) = @_;
    $self->{encType} = $value;
}

sub formName {
    my $self = shift;
    return $self->name() || $self->queryKeyNameForPageAndLoopContexts();
}

sub name {
    my $self = shift;
    return $self->{name};
}

sub setName {
    my ($self, $value) = @_;
    $self->{name} = $value;
}

sub canOnlyBeSubmittedOnce {
    my ($self) = @_;
    return $self->{canOnlyBeSubmittedOnce};
}

sub setCanOnlyBeSubmittedOnce {
    my ($self, $value) = @_;
    $self->{canOnlyBeSubmittedOnce} = $value;
}

sub appendToResponse {
    my ($self, $response, $context) = @_;

    # every form needs to emit the context number so the responding
    # process knows if it has been called in order.
    $self->{queryDictionaryAdditions}->addObject(
                { NAME => "context-number",
                  VALUE => $self->context()->session()->contextNumber(),
                });
    return $self->SUPER::appendToResponse($response, $context);
}

# these are just synonyms to help you in bindings files:

sub setEnctype {
    my ($self, $value) = @_;
    $self->setEncType($value);
}

sub setIsMultipart {
    my ($self, $value) = @_;
    if ($value) {
        $self->setEncType("multipart/form-data");
    } else {
        $self->setEncType();
    }
}

sub setIsMultiPart {
    my ($self, $value) = @_;
    $self->setIsMultipart($value);
}

sub validationErrorMessagesArray {
    my ($self) = @_;
    my $h = $self->validationErrorMessages();
    return [map {'key' => $_, 'value' => $h->{$_} }, keys %$h];
}

sub validationErrorMessages {
    my ($self) = @_;
    return $self->{validationErrorMessages} || {};
}

sub setValidationErrorMessages {
    my ($self, $value) = @_;
    $self->{validationErrorMessages} = $value;
}

1;
