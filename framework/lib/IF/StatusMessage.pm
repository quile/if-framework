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

package IF::StatusMessage;

use strict;

########################################################################
# Class

sub newInfoMessage {
    my ($className, $message) = @_;
    return $className->_newMessage("INFO", $message);
}

sub newWarningMessage {
    my ($className, $message) = @_;
    return $className->_newMessage("WARNING", $message);
}

sub newErrorMessage {
    my ($className, $message) = @_;
    return $className->_newMessage("ERROR", $message);
}

sub newConfirmationMessage {
    my ($className, $message) = @_;
    return $className->_newMessage("CONFIRMATION", $message);
}

sub _newMessage {
    my ($className, $type, $text) = @_;
    my $self = { }; # $className->new();
    bless($self, $className);
    $self->setType($type);
    $self->setText($text);
    return $self;
}

########################################################################
# Instance

sub cssClass {
    my ($self) = @_;
    return "status-messages-error"  if $self->type() eq "ERROR";
    return "status-messages-warning" if $self->type() eq "WARNING";
    return "status-messages-confirmation" if $self->type() eq "CONFIRMATION";
    return "status-messages-info";
}

############################################

sub type {
    my $self = shift;
    return $self->{type};
}

sub setType {
    my ($self, $value) = @_;
    $self->{type} = $value;
}

sub typeIsError {
    my ($self) = @_;
    return $self->type() eq 'ERROR';
}

sub typeIsWarning {
    my ($self) = @_;
    return $self->type() eq 'WARNING';
}

sub typeIsInfo {
    my ($self) = @_;
    return $self->type() eq 'INFO';
}

sub typeIsConfirmation {
    my ($self) = @_;
    return $self->type() eq 'CONFIRMATION';
}

sub text {
    my $self = shift;
    return $self->{text};
}

sub setText {
    my ($self, $value) = @_;
    $self->{text} = $value;
}

1;
