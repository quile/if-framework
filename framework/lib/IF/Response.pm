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

package IF::Response;

use strict;
use IF::RenderState;

sub new {
    my $className = shift;
    my $self = bless {
                    _params => {},
                    _contentList => [""],
                    _renderState => IF::RenderState->new(),
                    }, $className;
    $self->setContent("");
    return $self;
}

sub setTemplate {
    my $self = shift;
    $self->{_template} = shift;
}

sub template {
    my $self = shift;
    return $self->{_template};
}

# This shit is for compatibility with crappy old
# templates
sub param {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    if ($value) {
        $self->{_params}->{$key} = $value;
        return;
    }
    if ($key) {
        return $self->{_params}->{$key};
    }
    return $self->template()->namedBindings();
}

sub params {
    my $self = shift;
    return $self->{_params};
}

sub setParams {
    my $self = shift;
    my $params = shift;
    $self->{_params} = $params;
}

sub query {
    my $self = shift;
    return keys %{$self->params()};
}

sub appendContentString {
    push @{$_[0]->{_contentList}}, $_[1];
}

sub setContent {
    $_[0]->{_contentList} = [$_[1]];
}

sub content {
    my $self = shift;
    return join('', @{$self->{_contentList}});
}

sub renderState    { return $_[0]->{_renderState} }
sub setRenderState { $_[0]->{_renderState} = $_[1] }

# we'll use these to flush content out as it's generated
sub setContentIsBuffered {
    my $self = shift;
    $self->{_contentIsBuffered} = shift;
}

sub contentIsBuffered {
    my $self = shift;
    return $self->{_contentIsBuffered};
}

# how dumb is it that this wasn't on the response?
sub contentType    { return $_[0]->{contentType} }
sub setContentType { $_[0]->{contentType} = $_[1] }

1;

1;
