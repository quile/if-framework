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

package IF::Component::EmailField;

use strict;
use base qw(
    IF::Component::TextField
);

sub requiredPageResources {
    my ($self) = @_;
    return [
        IF::PageResource->javascript("/if-static/javascript/IF/EmailField.js"),
    ];
}

sub validEmailRequiredMessage {
    my ($self) = @_;
    return $self->{validEmailRequiredMessage} || $self->tagAttributeForKey("validEmailRequiredMessage") || "VALID_EMAIL_REQUIRED";
}

sub setValidEmailRequiredMessage {
    my ($self, $value) = @_;
    $self->{validEmailRequiredMessage} = $value;
}

1;