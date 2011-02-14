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

package IF::Component::ObjectAsJSON;

# TODO replace most of this with methods from JSON.pm
use strict;
use base qw(
    IF::Component
);

sub object {
    my ($self) = @_;
    return $self->{object};
}

sub setObject {
    my ($self, $value) = @_;
    $self->{object} = $value;
}

sub factory {
    my ($self) = @_;
    return $self->{factory} || $self->object()->entityClassDescription()->name();
}

sub setFactory {
    my ($self, $value) = @_;
    $self->{factory} = $value;
}

sub keys {
    my ($self) = @_;
    return $self->{keys} || $self->object()->entityClassDescription()->attributes();
}

sub setKeys {
    my ($self, $value) = @_;
    $self->{keys} = $value;
}

# the js parser doesn't like newlines in strings,
# and we need to be careful with quotes
sub escape {
    my ($self, $string) = @_;
    $string =~ s/'/\\'/go;
    $string =~ s/\n/\\n/go;
    $string =~ s/\r/\\r/go;
    return $self->filterString($string);
}

sub stripDots {
    my ($self, $string) = @_;
    $string =~ s/\./_/go;
    return $string;
}

sub filterString {
    my $self = shift;
    my $string = shift;
    # replace structural xml chars with their entitiy representation
    $string =~ s/([&<>\n\t])/replace($1)/ge;
    # replace control chars except tab (0x09) new line (0x0A)
    #  and cr (0x0D)
    $string =~ s/[\x00-\x08\x0B\x0C\x0E-\x1F]/ /ge;
    return $string;
}

sub replace {
    my $thing = shift;
    return '&#'.ord($thing).';';
}

sub valueForKeyOnObjectInContext {
    my ($self, $aKey, $object, $context) = @_;
    if (UNIVERSAL::can($object, $aKey)) {
        return $object->$aKey($context);
    }
    return $object->valueForKey($aKey);
}

1;