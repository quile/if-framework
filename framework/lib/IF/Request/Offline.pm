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

package IF::Request::Offline;

use strict;
use base qw(IF::Request);
use IF::Log;
use IF::Array;

sub AUTOLOAD {
    my $proto = shift;
    return unless ref $proto;
    our $AUTOLOAD;
    my $name = $AUTOLOAD;
    $name =~ s/^.*:://;
    if ($proto->can($name)) {
        return $proto->$name(@_);
    }
    IF::Log::warning("IF::Request:Offline does not implement $name");
    return;
}

sub DESTROY {
    my $self = shift;
}

sub new {
    my ($className) = @_;
    return bless {
        'headers_in' => {},
        'headers_out' => {},
        'param' => {},
    }, $className;
}

# originally in IF::FakeRequest

sub uri {
    my $self = shift;
    return $self->{_uri} if $self->{_uri};
    return "nowayjose";
}

sub setUri {
    my ($self, $value) = @_;
    $self->{_uri} = $value;
}

sub pnotes {
    my $self = shift;
    if (scalar @_ > 1) {
        my $key = shift;
        my $value = shift;
        $self->{_pnotes}->{$key} = $value;
    } else {
        return $self->{_pnotes}->{shift};
    }
}

sub dir_config {
    my $self = shift;
    return $self;
}

sub get {
    my $self = shift;
    my $key = shift;
    if ($key eq "Application") {
        return IF::Application->defaultApplicationName();
    }
}

sub headers_in {
    my ($self) = @_;
    return $self->{headers_in};
}

sub headers_out {
    my ($self) = @_;
    return $self->{headers_out};
}

sub param {
    my ($self, $key, $value) = @_;
    if ($key) {
        if ($value) {
            if (! defined $self->{param}->{$key}) {
                $self->{param}->{$key} = [];
            }
            $value = IF::Array->arrayFromObject($value);
            push @{$self->{param}->{$key}}, @$value;
        } else {
            my $v = $self->{param}->{$key};
            if (wantarray()) {
                return @$v if IF::Array::isArray($v);
                return $v;
            } else {
                return $v->[0] if IF::Array::isArray($v);
                return $v;
            }
        }
    } else {
        return keys %{$self->{param}} if wantarray();
    }
    return;
}

sub dropCookie {
    return undef;
}

1;
