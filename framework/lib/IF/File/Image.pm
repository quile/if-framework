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

package IF::File::Image;

use strict;
use base qw(IF::File IF::Interface::Stash);
use IF::Utility::Image ();

sub imageInfo {
	my ($self) = @_;

	my $info = $self->stashedValueForKey($self->fullPath());
	unless ($info) {
		$info = IF::Utility::Image->infoForImage($self);
		$self->setStashedValueForKey($info, $self->fullPath());
	}
	return $info;
}

sub hasBeenResizedTo {
	my ($self, $width, $height) = @_;
	return $self->stashedValueForKey(join('.',$self->fullPath(),$width,$height));
}

sub setHasBeenResizedTo {
	my ($self, $width, $height) = @_;
	return $self->setStashedValueForKey('1', join('.',$self->fullPath(),$width,$height));
}

sub saveAsNumberedUploadToSubdirectoryOfLocationKey {
	my ($self, $subdirectory, $key) = @_;

	my $uploadDirectory = $self->application()->configurationValueForKey($key);

	# TODO: system should do this sort of sanity just once, on startup ..
	# TODO: this sanity check should be extended to ensure folder actually exists
	unless (IF::Log::assert($uploadDirectory, "Upload directory is ok")) {
		return;
	}

    my $upload = $self->SUPER::saveAsNumberedUploadToSubdirectoryOfLocationKey($subdirectory, $key);
    my $fullpath = $self->fullPath();
    # TODO make the location of 'file' a config value
    my $o = `/usr/bin/file -b $fullpath`;
    IF::Log::debug("SAVED IMAGE TYPE : $o");
    return $upload;
}

1;