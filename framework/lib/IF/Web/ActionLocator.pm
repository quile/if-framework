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

package IF::Web::ActionLocator;

use strict;
use base qw(
    IF::Interface::KeyValueCoding
);

use IF::Utility;

sub new {
    my ($className) = @_;
    return bless {}, $className;
}

sub newFromString {
    my ($className, $string) = @_;

    my ($urlRoot, $site, $lang, $component, $action) =
                ($string =~ m#^/(\w+)/(\w+)/([\w-]+)/(.+)/([\w\d\.-]+)#);
    return undef unless $action;
    my $self = $className->new();
    $self->setDirectAction($action);
    $self->setTargetComponentName($component);
    $self->setLanguage($lang);
    $self->setSiteClassifierName($site);
    $self->setUrlRoot($urlRoot);
    return $self;
}

sub urlRoot {
    my ($self) = @_;
    return $self->{urlRoot};
}

sub setUrlRoot {
    my ($self, $value) = @_;
    $self->{urlRoot} = $value;
}

sub directAction {
    my ($self) = @_;
    return $self->{directAction};
}

sub setDirectAction {
    my ($self, $value) = @_;
    $self->{directAction} = $value;
}

sub targetComponentName {
    my ($self) = @_;
    return $self->{targetComponentName};
}

sub setTargetComponentName {
    my ($self, $value) = @_;
    $self->{targetComponentName} = $value;
}

sub siteClassifierName {
    my ($self) = @_;
    return $self->{siteClassifierName};
}

sub setSiteClassifierName {
    my ($self, $value) = @_;
    $self->{siteClassifierName} = $value;
}

sub language {
    my ($self) = @_;
    return $self->{language};
}

sub setLanguage {
    my ($self, $value) = @_;
    $self->{language} = $value;
}

sub queryDictionary {
    my ($self) = @_;
    return $self->{queryDictionary};
}

sub setQueryDictionary {
    my ($self, $value) = @_;
    $self->{queryDictionary} = $value;
}

sub asAction {
    my ($self) = @_;

    return join("/",
        $self->urlRoot(),
        $self->siteClassifierName(),
        $self->language(),
        $self->targetComponentName(),
        $self->directAction()
    );
}

1;
