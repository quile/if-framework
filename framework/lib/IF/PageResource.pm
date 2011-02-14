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

package IF::PageResource;

# --------------------------------------
# This just encapsulates all the info
# about a page resource together.  This
# shallow implementation just uses
# IF::Dictionary as a parent class.
# --------------------------------------

use strict;
use base qw(
    IF::Dictionary
);

our $DEFAULT_JQUERY_VERSION = "1.2.6";

# +++++ class methods +++++

sub stylesheet {
    my ($className, $location, $domId) = @_;
    my $value = $className->new();
    $value->setLocation($location);
    $value->setDomId($domId);
    $value->setMimeType("text/css");
    $value->setType("stylesheet");
    return $value;
}

sub javascript {
    my ($className, $location) = @_;
    my $value = $className->new();
    $value->setLocation($location);

    if (IF::Application->defaultApplication()->environmentIsProduction()) {
    #if (1) {
        if ($location =~ m!/IF/!) {
            $value->setLocation("/if-static/javascript/if.js");
        } elsif ($location =~ m!jquery.(\d\.\d\.\d).?js!) {
            my $version = $1 || $DEFAULT_JQUERY_VERSION;
            $value->setLocation("http://ajax.googleapis.com/ajax/libs/jquery/$version/jquery.min.js");
        }
    }

    $value->setMimeType("text/javascript");
    $value->setType("javascript");
    return $value;
}

sub alternateStylesheetNamed {
    my ($className, $location, $name) = @_;
    my $value = $className->new();
    $value->setLocation($location, "location");
    $value->setObjectForKey($name, "title");
    $value->setMimeType("text/css", "mimeType");
    $value->setType("alternate stylesheet", "type");
    return $value;
}

# --------- instance methods -----------
# Note that this object is a dictionary
# so it can store arbitrary instance
# data... these are just conveniences.
# --------------------------------------

sub location {
    my $self = shift;
    return $self->objectForKey("location");
}

sub setLocation {
    my ($self, $value) = @_;
    $self->setObjectForKey($value, "location");
}

sub mimeType {
    my $self = shift;
    return $self->objectForKey("mimeType");
}

sub setMimeType {
    my ($self, $value) = @_;
    $self->setObjectForKey($value, "mimeType");
}

sub type {
    my $self = shift;
    return $self->objectForKey("type");
}

sub setType {
    my ($self, $value) = @_;
    $self->setObjectForKey($value, "type");
}

sub domId {
    my ($self) = @_;
    return $self->{domId};
}

sub setDomId {
    my ($self, $value) = @_;
    $self->{domId} = $value;
}

sub firstRequester {
    my $self = shift;
    return $self->{firstRequester};
}

sub setFirstRequester {
    my ($self, $value) = @_;
    $self->{firstRequester} = $value;
}

# ------- this generates the tag to pull this resource in -------

sub tag {
    my ($self) = @_;
    my $libVersion = IF::Application->systemConfigurationValueForKey("BUILD_VERSION");

    if ($self->type() eq "javascript") {
        return '<script type="'.$self->mimeType().'" src="'.$self->location().'?v='. $libVersion.'"></script>';
    } elsif ($self->type() eq "stylesheet" || $self->type() eq "alternate stylesheet") {
        my $media = $self->objectForKey("media") || "screen, print";
        my $link = '<link rel="'.$self->type().'" type="'.$self->mimeType().'" href="'.$self->location().'?v='. $libVersion .'" media="'.$media.'" title="'.$self->objectForKey("title").'"';
        $link .= ' id="' . $self->domId() . '" ' if $self->domId();
        $link .= ' />';
        return $link;
    }
    return "<!-- unknown resource type: ".$self->type()." location: ".$self->location()." -->";
}

1;
