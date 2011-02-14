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

package IF::RenderState;

use strict;
use base qw(
    IF::Interface::KeyValueCoding
    IF::Interface::StatusMessageHandling
);

sub new {
    my $className = shift;
    my $self = {
        _pageContext => [1],
        _loopContext => [],
        _renderedComponents => {},
    };
    return bless $self, $className;
}

# These are used in page generation
sub increasePageContextDepth {
    my $self = shift;
    push (@{$self->{_pageContext}}, 0);
}

sub decreasePageContextDepth {
    my $self = shift;
    pop (@{$self->{_pageContext}});
}

sub incrementPageContextNumber {
    my $self = shift;
    $self->{_pageContext}->[ $#{$self->{_pageContext}} ] += 1;
}

sub pageContextNumber {
    my $self = shift;
    return join("_", @{$self->{_pageContext}});
}

# these mirror the page context stuff but are used
# with a page context for keeping track of loops:
sub increaseLoopContextDepth {
    my ($self) = @_;
    push (@{$self->{_loopContext}}, 0);
}

sub decreaseLoopContextDepth {
    my ($self) = @_;
    pop (@{$self->{_loopContext}});
}

sub incrementLoopContextNumber {
    my ($self) = @_;
    $self->{_loopContext}->[ -1 ] += 1;
}

sub loopContextNumber {
    my ($self) = @_;
    return join("_", @{$self->{_loopContext}});
}

sub loopContextDepth {
    my ($self) = @_;
    return scalar @{$self->{_loopContext}};
}

# ----------- these help components manage page resources ---------

sub pageResources {
    my ($self) = @_;
    return $self->_orderedPageResources();
}

# this holds the resources in the order they are added.  It's not
# particularly accurate because components get included/rendered
# in an order that's not the same as the order they appear on
# the page, BUT it means that all the resources a given component
# requests WILL BE in the order that it requests them.

sub _orderedPageResources {
    my ($self) = @_;
    return $self->{_orderedPageResources} || [];
}

sub addPageResource {
    my ($self, $resource) = @_;
    $self->{pageResources} ||= {};
    $self->{_orderedPageResources} ||= [];
    # Only add it to the list if it's not already there.
    my $location = $resource->location();
    unless ($self->{pageResources}->{$location}) {
        IF::Log::debug("Requesting resource $location");
        push (@{$self->{_orderedPageResources}}, $resource);
    }
    $self->{pageResources}->{$location} = $resource;
}

sub addPageResources {
    my ($self, $resources) = @_;
    $resources = IF::Array->arrayFromObject($resources);
    foreach my $r (@$resources) {
        $self->addPageResource($r);
    }
}

sub removePageResource {
    my ($self, $resource) = @_;
    $self->{pageResources} ||= {};
    delete $self->{pageResources}->{$resource->location()};
}

1;