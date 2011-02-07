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

package IF::Component::Image;
use strict;
use IF::Component;
use IF::Utility::Image;
use POSIX ();
use base qw(IF::Component);

my $DOCUMENT_ROOT;

sub init {
	my $self = shift;
	$DOCUMENT_ROOT = $self->application()->configurationValueForKey("DOCUMENT_ROOT") unless $DOCUMENT_ROOT;
	return $self->SUPER::init(@_);
}

sub width {
	my $self = shift;
	return $self->{width};
}

sub setWidth {
	my ($self, $value) = @_;
	$self->{width} = $value;
}

sub height {
	my $self = shift;
	return $self->{height};
}

sub setHeight {
	my ($self, $value) = @_;
	$self->{height} = $value;
}

sub src {
	my $self = shift;
	return $self->{src};
}

sub setSrc {
	my ($self, $value) = @_;
	$self->{src} = $value;
}

sub application {
	my $self = shift;
	return $self->{application} || IF::Application->defaultApplication();
}

sub setApplication {
	my ($self, $application) = @_;
	$self->{application} = $application;
}

sub shouldResizeImage {
	my $self = shift;
	return $self->{shouldResizeImage};
}

sub setShouldResizeImage {
	my ($self, $value) = @_;
	$self->{shouldResizeImage} = $value;
}

sub shouldBeProportional {
	my ($self) = @_;
	return $self->{shouldBeProportional};
}

sub setShouldBeProportional {
	my ($self, $value) = @_;
	$self->{shouldBeProportional} = $value;
}


sub shouldResizeSynchronously    { $_[0]->{shouldResizeSynchronously} }
sub setShouldResizeSynchronously { $_[0]->{shouldResizeSynchronously} = $_[1] }

sub generateSourceUrl {
	my ($self) = @_;

	if ($self->shouldResizeImage()) {
		my $fullPathToSrc = $DOCUMENT_ROOT.$self->src();
		# don't go off trying to resize an image that doesn't exist
		my $srcImage = IF::File::Image->new()->initWithFullPath($fullPathToSrc);
		return unless $srcImage->exists();

		# check for existing image of the correct size
		# and if it exists, reset the image path to point to the resized
		# one.  NOTE NOTE NOTE: this only works if the resized one is in
		# the same folder as the original and is named .../original-wXhY.foo

		if ($self->shouldBeProportional()) {
			my $sizes = $self->proportionalFit($srcImage, $self->width(), $self->height());
			if ($sizes) {
				$self->setWidth($sizes->{WIDTH});
				$self->setHeight($sizes->{HEIGHT});
			}
 		}
		my $imageUrl = $self->_getImagePathForImageResizedToWidthHeight($srcImage, $self->width(), $self->height());
		$self->setSrc($imageUrl);
	}
}

sub appendToResponse {
	my ($self, $response, $context) = @_;
	# Since we are doing the resize possibly in a loop we need to make sure that
	# we remove the calculated binding specific for the picture in each loop.
	my $hadWidth = $self->width() ? 1 : 0;
	my $hadHeight = $self->height() ? 1 : 0;
	$self->generateSourceUrl();
	my $page = $self->SUPER::appendToResponse($response, $context);
	# Reset to the default if it was calculated.
	unless ($hadWidth) {
		$self->setWidth();
	}
	unless ($hadHeight) {
		$self->setHeight();
	}
	return $page;
}

sub _getImagePathForImageResizedToWidthHeight {
	my ($self, $srcImage, $width, $height) = @_;
	my $resizedImageFilename = $self->_resizedImageFilenameForImage($srcImage, $width, $height);
	my $resizedImageFullPath = $srcImage->path()."/".$resizedImageFilename;
	my $fullPathToSrc;

	if (-f $resizedImageFullPath) {
		$fullPathToSrc = $resizedImageFullPath;
	} else {
		IF::Log::debug("Resizing image to $resizedImageFullPath");
		# resize the image and set the component's image to the new one
		unless ($srcImage->hasBeenResizedTo($width, $height)) {
			my $resizedImage = IF::Utility::Image->resizedImageAtPathWithWidthAndHeightFromImage(
									$resizedImageFullPath,
									$width,
									$height,
									$srcImage,
									$self->shouldResizeSynchronously(),
								);
			if ($resizedImage) {
				$fullPathToSrc = $resizedImage->fullPath();
			}
			# I think that what is happening is that sometimes the nconvert fails
			# so this will only mark as generated if the file exists.
			# NOTE:  This maybe problemmatic if nconvert kicks off a whole bunch of
			# times.
			if (-f $fullPathToSrc) {
				$srcImage->setHasBeenResizedTo($width, $height);
			}

		}
	}
	my $imageUrl = $fullPathToSrc;
	$imageUrl =~ s/$DOCUMENT_ROOT//;
	# this is a bit lame, but the consequences of rendering an
	# img tag with an empty source are correspondingly dire
	unless ($imageUrl) {
		# Adding some debugging gunk as this gets really hard to figure out
		# once spread across the servers
		my $debugSrcImagePath = $srcImage->path();
		my $debugResizedImagePath = $resizedImageFullPath;
		$debugSrcImagePath =~ s/$DOCUMENT_ROOT//;
		$debugResizedImagePath =~ s/$DOCUMENT_ROOT//;
		$imageUrl = '/images/blank.gif?' .
			join("&amp;",
					"resizingError=1",
					"resizedImagePath=$debugResizedImagePath",
					"width=$width",
					"height=$height",
					"srcImage-path=" . $debugSrcImagePath,
					"srcImage-hasBeenResizedTo=" . $srcImage->hasBeenResizedTo($width, $height),
				);
	}
	return $imageUrl;
}

sub _resizedImageFilenameForImage {
	my ($self, $image, $width, $height) = @_;
	my $sizeString = "";
	if ($width) {
		$sizeString .= "w".$width;
	}
	if ($height) {
		$sizeString .= "h".$height;
	}
	if ($sizeString eq "") {
		return $image->fileName();
	}
	my $extension = $image->extension();
	my $filename = $image->fileName();
	$filename =~ s/$extension/-$sizeString$extension/;
	return $filename;
}

# for legacy reasons this is sometimes called with two
# constraints and sometimes with one.
# -With a single constraint, the image is scaled so that
# the dimension along the given constraint is equal in size
# to the value of the constraint.
# -With two constraints, we first have to decide whether the
#  height or width constraint is the one that when passed to
#  to the single constraint algorithm, will size the image so
#  that width and height are strictly <= to the size of the
#  rectangle described by the constraints.
sub proportionalFit {
	my ($self, $image, $desiredWidth, $desiredHeight) = @_;

	if ($desiredWidth && $desiredHeight) {
		return $self->proportionalFit2($image, $desiredWidth, $desiredHeight);
	} else {
		return $self->proportionalFit1($image, $desiredWidth, $desiredHeight);
	}
}

sub proportionalFit1 {
	my ($self, $image, $desiredWidth, $desiredHeight) = @_;

	my $imageInfo = $image->imageInfo();
	my $actualWidth = $imageInfo->valueForKey('width');
	my $actualHeight = $imageInfo->valueForKey('height');

	unless (IF::Log::assert(($desiredWidth xor $desiredHeight),
		"proportionalFit1 needs exactly one of desired height or desired width")) {
		return { 'WIDTH' => $actualWidth, 'HEIGHT' => $actualHeight };
	}

	unless (IF::Log::assert(($actualWidth && $actualHeight),
		"Got image dimensions")) {
		return;
	}

	my $RWH = $actualWidth / $actualHeight;

	if ($desiredWidth) {
		return { 	'WIDTH' => $desiredWidth,
					'HEIGHT' => POSIX::floor($desiredWidth / $RWH)
				};
	} else {
		return { 	'WIDTH' => POSIX::floor($desiredHeight * $RWH),
					'HEIGHT' => $desiredHeight
				};
	}
}

# proportional fit with 2 constraints:
#  looks at the ratio of W/H for the max size
#  and the actual size and determines which
#  constraint is active.
sub proportionalFit2 {
	my ($self, $image, $maxWidth, $maxHeight) = @_;

	my $imageInfo = $image->imageInfo();
	my $actualWidth = $imageInfo->valueForKey('width');
	my $actualHeight = $imageInfo->valueForKey('height');

	unless (IF::Log::assert(($actualWidth && $actualHeight),
		"Got image dimensions")) {
		return;
	}

	my $RWH_actual = $actualWidth / $actualHeight;
	my $RWH_max = $maxWidth / $maxHeight;

	if ($RWH_actual < $RWH_max) {
		# actual image is taller and narrower than target space,
		# height constraint is active
		return $self->proportionalFit1($image, undef, $maxHeight);
	} else {
		# actual image is shorter and fatter than target space,
		# width constraint is active
		return $self->proportionalFit1($image, $maxWidth, undef);
	}
}

1;
