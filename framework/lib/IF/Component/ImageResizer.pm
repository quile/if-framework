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

package IF::Component::ImageResizer;

use strict;
use base qw(
    IF::Component
);
BEGIN {
    use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and
                            $ENV{MOD_PERL_API_VERSION} >= 2 );
    use constant MP1 => ( not exists $ENV{MOD_PERL_API_VERSION} and
                            $ENV{MOD_PERL} );

    if (MP2) {
        print STDERR "Mod perl version is $ENV{MOD_PERL_API_VERSION}\n";
        eval "use Apache2::SubRequest";
        print STDERR $@ if ($@);
    }
}


sub takeValuesFromRequest {
    my ($self, $context) = @_;

    # resize an image to a given width and height
    my $ip = $context->formValueForKey("path");
    if ($ip) {
        my $uip = $self->application()->configurationValueForKey("UPLOADED_IMAGE_PATH");
        $self->setImagePath("$uip/$ip");
    }
    $self->setHeight($context->formValueForKey("height"));
    $self->setWidth($context->formValueForKey("width"));
    $self->setAlwaysReturn($context->formValueForKey("alwaysReturn"));

    $self->SUPER::takeValuesFromRequest($context);
}

sub appendToResponse {
    my ($self, $response, $context) = @_;
    my $rv = $self->SUPER::appendToResponse($response, $context);
    # suck the path out of the output:
    my $output = $response->content();
    $output =~ m!<img src="([^"]+)"!;
    IF::Log::debug($output);
    if ($1) {
        my $img = $context->application()->configurationValueForKey("DOCUMENT_ROOT")
                 .$1;
        unless (-e $img) {
            # file doesn't exist so something went wrong with the resizing
            if ($self->alwaysReturn()) {
                return sub {
                    $context->setHeaderValueForKey('max=age=2592000', 'Cache-Control');
                    return $context->request()->internalRedirect("/images/blank.gif");
                }
            } else {
                $context->setResponseCode(404);
                $context->setHeaderValueForKey("404", "Status");
                $response->setContent();
                return $rv;
            }
        }
        IF::Log::debug("Resized image is at $1");
        my $redirect = $1;
        # redirect the image itself by returning a closure
        # that gets passed to Apache.
        return sub {
            IF::Log::debug("Internal redirect to $redirect");
            $context->setHeaderValueForKey('max=age=2592000', 'Cache-Control');
            return $context->request()->internalRedirect($redirect);
        }
    }
    return $rv
}

sub imagePath    { $_[0]->{imagePath} }
sub setImagePath { $_[0]->{imagePath} = $_[1] }
sub height    { $_[0]->{height} }
sub setHeight { $_[0]->{height} = $_[1] }
sub width     { $_[0]->{width} }
sub setWidth  { $_[0]->{width} = $_[1] }
sub alwaysReturn    { return $_[0]->{alwaysReturn}  }
sub setAlwaysReturn { $_[0]->{alwaysReturn} = $_[1] }


sub Bindings {
    return {
        IMAGE => {
            type => "Image",
            bindings => {
                src => q(imagePath),
                width => q(width),
                height => q(height),
                shouldResizeImage => q("1"),
                shouldResizeSynchronously => q("1"),
            },
        },
    }
}

1;
