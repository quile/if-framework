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

package IF::Dictionary;

use strict;
use URI::Escape;

use base qw(
    PF::Dictionary
    IF::Interface::KeyValueCoding
);

# static method

sub isHash {
    my $object = shift;
    return UNIVERSAL::isa($object, "HASH");
}

sub setValueForKey {
    my $self = shift;
    my $value = shift;
    my $key = shift;
    $self->setObjectForKey($value, $key);
}

sub initWithQueryString {
    my ($self, $queryString) = @_;

    my @kvPairs = split(/\&/, $queryString);
    foreach my $kvPair (@kvPairs) {
        my ($key, $value) = $kvPair =~ /^(.*)=(.*)$/;
        next unless ($key && $value);
        $key = URI::Escape::uri_unescape($key);
        $value = URI::Escape::uri_unescape($value);
        #IF::Log::debug("$key : $value");
        my $currentValue = $self->objectForKey($key);
        if ($currentValue) {
            $currentValue = IF::Array->arrayFromObject($currentValue);
            $currentValue->addObject($value);
        } else {
            $currentValue = $value;
        }
        $self->setObjectForKey($currentValue, $key);
    }
    #IF::Log::dump($self);
    return $self;
}

1;
