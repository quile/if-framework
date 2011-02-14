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

package IF::Component::PrivilegeEditor;
use strict;
use vars qw(@ISA);
use IF::Component;
@ISA = qw(IF::Component);

sub takeValuesFromRequest {
    my ($self, $context) = @_;
    $self->SUPER::takeValuesFromRequest($context);
    if ($self->objectHasPrivilege()) {
        IF::Log::debug("Granting privilege ".$self->privilege()." to ".$self->object());
        $self->object()->grantPrivilegeTo($self->privilege());
    } else {
        IF::Log::debug("Revoking privilege ".$self->privilege()." from ".$self->object());
        $self->object()->revokePrivilegeTo($self->privilege());
    }
}

sub appendToResponse {
    my ($self, $response, $context) = @_;
    if ($self->object()->hasPrivilegeTo($self->privilege())) {
        IF::Log::debug("Object has privilege ".$self->privilege());
        $self->setObjectHasPrivilege("1");
    } else {
        $self->setObjectHasPrivilege("0");
    }
    return $self->SUPER::appendToResponse($response, $context);
}

sub name {
    my $self = shift;
    return $self->{name} || $self->queryKeyNameForPageAndLoopContexts();
}

sub setName {
    my $self = shift;
    $self->{name} = shift;
}

sub object {
    my $self = shift;
    return $self->{object};
}

sub setObject {
    my $self = shift;
    $self->{object} = shift;
}

sub privilege {
    my $self = shift;
    return $self->{privilege};
}

sub setPrivilege {
    my $self = shift;
    $self->{privilege} = shift;
}

sub objectHasPrivilege {
    my $self = shift;
    return $self->{objectHasPrivilege};
}

sub setObjectHasPrivilege {
    my $self = shift;
    $self->{objectHasPrivilege} = shift;
}

1;