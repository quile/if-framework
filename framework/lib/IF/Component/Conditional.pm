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

package IF::Component::Conditional;

use strict;
use vars qw(@ISA);
use IF::Component;

@ISA = qw(IF::Component);

sub condition {
    my $self = shift;
    return  $self->{condition};
}

sub setCondition {
    my $self = shift;
    $self->{condition} = shift;
}

sub evaluatedCondition {
    my $self = shift;
    # we need to evaluate this condition in the context of the parent
    unless ($self->parent()) {
        IF::Log::error("Can't evaluate conditional in parent component context");
        return 0;
    }
    my $value = IF::Utility::evaluateExpressionInComponentContext($self->condition(), $self->parent(), $self->context());
    $value = !$value if $self->isNegated();
    IF::Log::debug("Conditional evaluated to $value");
    return $value;
}

sub isNegated {
    my $self = shift;
    return $self->{isNegated};
}

sub setIsNegated {
    my $self = shift;
    $self->{isNegated} = shift;
}

1;
