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

package IF::BindingDictionary;

use strict;
use base qw(IF::Dictionary);
use IF::Log;

sub initWithContentsOfFileAtPath {
    my ($self, $fullPath) = @_;
    my $b;
    if (open(B, $fullPath)) {
        my $unparsedBinding = join("", <B>);
        close (B);
        $b = eval $unparsedBinding;
        #F::Log::debug("~~~~~~~~~~~~~~~ Loaded bindings at $fullPath");
        unless ($b) {
            IF::Log::warning("Binding file $fullPath seems empty or may have a parse error in it: $@");
        }
        return $self->initWithDictionary($b);
    } else {
        #IF::Log::warning("Couldn't open binding file at $fullPath");
        return undef;
    }

}

# these macros are to allow us to tidy up the bindings files
# and not have to repeat all the verbose perl syntax stuff.

sub String {
    my ($keyPath) = @_;
    return {
        type => "STRING",
        value => $keyPath,
    };
}

sub StringWithFilter {
    my ($keyPath, $filter) = @_;
    return {
        type => "STRING",
        value => $keyPath,
        filter => $filter,
    };
}

sub Boolean {
    my ($keyPath) = @_;
    return {
        type => "BOOLEAN",
        value => $keyPath,
    };
}

sub TextField {
    my ($keyPath) = @_;
    return SimpleComponentOfTypeForKeyPath("TextField", $keyPath);
}

sub HiddenField {
    my ($keyPath) = @_;
    return SimpleComponentOfTypeForKeyPath("HiddenField", $keyPath);
}

sub Text {
    my ($keyPath) = @_;
    return SimpleComponentOfTypeForKeyPath("Text", $keyPath);
}

sub Password {
    my ($keyPath) = @_;
    return SimpleComponentOfTypeForKeyPath("Password", $keyPath);
}

sub SimpleComponentOfTypeForKeyPath {
    my ($type, $keyPath) = @_;
    return {
        type => $type,
        bindings => {
            value => $keyPath,
        },
    };
}

sub Form {
    return {
        type => "Form",
    };
}

sub FormWithAction {
    my ($action) = @_;
    return {
        type => "Form",
        bindings => {
            directAction => $action,
        }
    };
}

1;